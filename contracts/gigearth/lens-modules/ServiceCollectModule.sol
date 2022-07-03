// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ICollectModule} from '../../interfaces/ICollectModule.sol';
import {Errors} from '../../libraries/Errors.sol';
import {FeeModuleBase} from '../../core/modules/FeeModuleBase.sol';
import {ModuleBase} from '../../core/modules/ModuleBase.sol';
import {FollowValidationModuleBase} from '../../core/modules/FollowValidationModuleBase.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {DataTypes} from '../../libraries/DataTypes.sol';
import "hardhat/console.sol";

/**
 * @notice A struct containing the necessary data to execute collect actions on a publication.
 *
 * @param amount The collecting cost associated with this publication.
 * @param currency The currency associated with this publication.
 * @param recipient The recipient address associated with this publication.
 * @param referralFee The referral fee associated with this publication.
 * @param followerOnly Whether only followers should be able to collect.
 */
struct PaymentProcessingData {
    uint256 amount;
    address currency;
    address recipient;
    uint16 referralFee;
    uint256 serviceId;
    uint256[] packages;
}

interface INetworkManager {
    function getProtocolFee() external view returns(uint);
}

/**
 * @title ServiceCollectModule
 * author Elijah Hampton
 *
 * @notice This is a lens protocol collect module for purchasing LensTalent services and designating
 */
contract ServiceCollectModule is FeeModuleBase, ModuleBase, ICollectModule {
    using SafeERC20 for IERC20;

    INetworkManager _lensTalentNetworkManager;

    mapping(uint256 => mapping(uint256 => PaymentProcessingData))
        internal _dataByPublicationByProfile;

    mapping(address => mapping(address => bool)) _ownerToClientToRelationshipConfirmation;

    modifier onlyNetworkManager {
        require(msg.sender == address(_lensTalentNetworkManager), "only network manager");
        _;
    }

    constructor(address hub, address moduleGlobals, address lensTalentNetworkManager) FeeModuleBase(moduleGlobals) ModuleBase(hub) {
        require(lensTalentNetworkManager != address(0), "invalid params");
        _lensTalentNetworkManager = INetworkManager(lensTalentNetworkManager);
    }

    /**
     * @notice This collect module levies a fee on collects and supports referrals. Thus, we need to decode data.
     *
     * @param profileId The token ID of the profile of the publisher, passed by the hub.
     * @param pubId The publication ID of the newly created publication, passed by the hub.
     * @param data The arbitrary data parameter, decoded into:
     *      uint256 amount: The currency total amount to levy.
     *      address currency: The currency address, must be internally whitelisted.
     *      address recipient: The custom recipient address to direct earnings to.
     *      uint16 referralFee: The referral fee to set.
     *
     * @return bytes An abi encoded bytes parameter, which is the same as the passed data parameter.
     */
    function initializePublicationCollectModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external override onlyHub returns (bytes memory) {
        (
            uint256[] memory amount,
            address currency,
            address recipient,
            uint16 referralFee,
            uint256 serviceId
        ) = abi.decode(data, (uint256[], address, address, uint16, uint256));
        if (
            !_currencyWhitelisted(currency) ||
            recipient == address(0) ||
            referralFee > BPS_MAX ||
            amount[0] == 0 ||
            amount[1] == 0 ||
            amount[2] == 0
        ) revert Errors.InitParamsInvalid();

        _dataByPublicationByProfile[profileId][pubId].packages = amount;
        _dataByPublicationByProfile[profileId][pubId].amount = amount[0];
        _dataByPublicationByProfile[profileId][pubId].currency = currency;
        _dataByPublicationByProfile[profileId][pubId].recipient = recipient;
        _dataByPublicationByProfile[profileId][pubId].referralFee = referralFee;
        _dataByPublicationByProfile[profileId][pubId].serviceId = serviceId;
        return data;
    }

    /**
     * @dev Processes a collect by:
     *  1. Ensuring the collector is a follower
     *  2. Charging a fee
     */
    function processCollect(
        uint256 referrerProfileId,
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external virtual override onlyHub {
        if (referrerProfileId == profileId) {
            _processCollect(collector, profileId, pubId, data);
        } else {
            _processCollectWithReferral(referrerProfileId, collector, profileId, pubId, data);
        }
    }

    /**
     * @notice Returns the payment processing data for a given publication, or an empty struct if that publication was not
     * initialized with this module.
     *
     * @param profileId The token ID of the profile mapped to the publication to query.
     * @param pubId The publication ID of the publication to query.
     *
     * @return PaymentProcessingData The PaymentProcessingData struct mapped to that publication.
     */
    function getPaymentProcessingData(uint256 profileId, uint256 pubId)
        external
        view
        returns (PaymentProcessingData memory)
    {
        return _dataByPublicationByProfile[profileId][pubId];
    }

    function _processCollect(
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) internal {
        uint256 amount = _dataByPublicationByProfile[profileId][pubId].amount;
        address currency = _dataByPublicationByProfile[profileId][pubId].currency;

        (address decodedCurrency, uint256 decodedAmount, uint8 decodedPackage) = abi.decode(data, (address, uint256, uint8));

        _validateDataIsExpected(data, currency, amount);

        uint256 fee = _dataByPublicationByProfile[profileId][pubId].packages[decodedPackage];

        IERC20(currency).safeTransferFrom(collector, address(this), fee);
    }

    function releaseCollectedFunds(uint256 profileId, uint256 pubId, uint8 package) external onlyNetworkManager {
        uint256 amount = _dataByPublicationByProfile[profileId][pubId].packages[package];
        address currency = _dataByPublicationByProfile[profileId][pubId].currency;
        address recipient = _dataByPublicationByProfile[profileId][pubId].recipient;
        uint256 treasuryAmount = (amount * _lensTalentNetworkManager.getProtocolFee()) / BPS_MAX;
        uint256 adjustedAmount = amount - treasuryAmount;

        IERC20(currency).transfer(recipient, adjustedAmount);
        if (treasuryAmount > 0) {
            IERC20(currency).transfer(address(_lensTalentNetworkManager), treasuryAmount);
        }

        //TODO: Proof owner to client relationship
        // _ownerToClientToRelationshipConfirmation[]
    }

    function emergencyReleaseDisputedFunds(uint256 profileId, uint256 pubId, address recipient, uint8 package) external onlyNetworkManager {
        uint256 amount = _dataByPublicationByProfile[profileId][pubId].packages[package];
        address currency = _dataByPublicationByProfile[profileId][pubId].currency;
        address recipient = _dataByPublicationByProfile[profileId][pubId].recipient;
        uint256 treasuryAmount = (amount * _lensTalentNetworkManager.getProtocolFee()) / BPS_MAX;
        uint256 adjustedAmount = amount - treasuryAmount;

        IERC20(currency).safeTransferFrom(address(this), recipient, adjustedAmount);
        if (treasuryAmount > 0) {
            IERC20(currency).safeTransferFrom(address(this), address(_lensTalentNetworkManager), treasuryAmount);
        }
    }

        function getServiceCo(uint256 profileId, uint256 pubId, address recipient, uint8 package) external onlyNetworkManager {
        }

    function _processCollectWithReferral(
        uint256 referrerProfileId,
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) internal {
        uint256 amount = _dataByPublicationByProfile[profileId][pubId].amount;
        address currency = _dataByPublicationByProfile[profileId][pubId].currency;
        _validateDataIsExpected(data, currency, amount);

        uint256 referralFee = _dataByPublicationByProfile[profileId][pubId].referralFee;
        uint256 treasuryAmount;

        // Avoids stack too deep
        {
            treasuryAmount = (amount * _lensTalentNetworkManager.getProtocolFee()) / BPS_MAX;
        }

        uint256 adjustedAmount = amount - treasuryAmount;

        if (referralFee != 0) {
            // The reason we levy the referral fee on the adjusted amount is so that referral fees
            // don't bypass the treasury fee, in essence referrals pay their fair share to the treasury.
            uint256 referralAmount = (adjustedAmount * referralFee) / BPS_MAX;
            adjustedAmount = adjustedAmount - referralAmount;

            address referralRecipient = IERC721(HUB).ownerOf(referrerProfileId);

            IERC20(currency).safeTransferFrom(collector, referralRecipient, referralAmount);
        }
        address recipient = _dataByPublicationByProfile[profileId][pubId].recipient;

        IERC20(currency).safeTransferFrom(collector, recipient, adjustedAmount);
        if (treasuryAmount > 0)
            IERC20(currency).safeTransferFrom(collector, address(_lensTalentNetworkManager), treasuryAmount);
    }
}
