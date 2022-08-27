// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IReferenceModule} from '../../interfaces/IReferenceModule.sol';
import {ModuleBase} from '../../core/modules/ModuleBase.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface INetworkManager {
    function isFamiliarWithService(address employer, uint256 serviceId) external returns (bool);
}

struct ReferenceData {
    uint256 serviceID;
    address creator;
}

/**
 * @title ServiceReferenceModule
 * @author Lens Protocol
 *
 * @notice A simple reference module that validates that comments or mirrors originate from a profile owned
 * by a follower.
 */
contract ServiceReferenceModule is IReferenceModule, ModuleBase {
    INetworkManager _lensTalentNetworkManager;
    mapping(uint256 => mapping(uint256 => ReferenceData)) internal _dataByPublicationByProfile;

    constructor(address hub, address lensTalentNetworkManager) ModuleBase(hub) {
        require(lensTalentNetworkManager != address(0), 'invalid params');
        _lensTalentNetworkManager = INetworkManager(lensTalentNetworkManager);
    }

    /**
     * Initializes the reference module.
     */
    function initializeReferenceModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external override returns (bytes memory) {
        (uint256 serviceId, address creator) = abi.decode(data, (uint256, address));

        _dataByPublicationByProfile[profileId][pubId] = ReferenceData({
            serviceID: serviceId,
            creator: creator
        });

        return new bytes(0);
    }

    /**
     * Processes a new comment.
     * @dev Checks to see if the commenter has collected (purchased) the service.
     */
    function processComment(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed,
        bytes calldata data
    ) external override {
        //get comment creator address
        address commentCreator = IERC721(HUB).ownerOf(profileId);
        require(commentCreator != address(0), "address doesn't have lens handle");

        //verify relationship validity
        assert(
            _lensTalentNetworkManager.isFamiliarWithService(
                commentCreator,
                _dataByPublicationByProfile[profileIdPointed][pubIdPointed].serviceID
            )
        );
    }

    /**
     * @notice Mirroring is not supported. Mirroring will be introduced upon the
     * implementaion of referrals.
     */
    function processMirror(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed,
        bytes calldata data
    ) external view override {
        revert('Mirroring not supported');
    }
}
