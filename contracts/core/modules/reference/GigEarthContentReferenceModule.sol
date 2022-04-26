pragma solidity 0.8.10;

import {IReferenceModule} from '../../../interfaces/IReferenceModule.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidationModuleBase} from '../FollowValidationModuleBase.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {FeeModuleBase} from '../FeeModuleBase.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';


interface IGigEarth {
    function getServiceData(uint256 _relationshipID)
        external
        returns (Service memory);
}

contract GigEarthContentReferenceModule is
    IReferenceModule,
    FollowValidationModuleBase,
    FeeModuleBase
{
    using SafeERC20 for IERC20;

    struct ServiceMetadata {
        address owner;
        bool referralsPaused;
        uint256 referralShare;
        uint256 serviceId;
        bool exist;
    }

    mapping(address => uint256[]) public addressToCompleteReferenceList;
    mapping(string => ServiceMetadata) public publicationIdToServiceMetadata;
    mapping(uint256 => ServiceMetadata) public serviceIdToServiceMetadata;

    IGigEarth immutable governor;

    function _checkProfessionalRelationshipValidity() {}

    constructor(
        address _hub,
        address moduleGlobals,
        address _governor
    ) FeeModuleBase(moduleGlobals) ModuleBase(_hub) {
        governor = IGigEarth(_governor);
    }

    error InvalidRelationshipState();
    error DuplicateServiceRegistration();
    error UnMirrorableContent();
    error InsufficientFee();

    /// @inheritdoc IReferenceModule
    function initializeReferenceModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external override onlyHub returns (bytes memory) {
        (address currencyIn, address ownerIn, bool referralsPausedIn, bool referralShareIn, uint256 serviceIdIn) = abi.decode( data, (address, bool, uint256, uint256) );

        require(serviceIdToServiceMetadata[serviceIdIn].exist == false, "duplicate service registration");

        if (!_currencyWhitelisted(currency) || fee < BPS_MAX) {
            revert Errors.InitParamsInvalid();
        }

        ServiceMetadata memory serviceMetadata = ServiceMetadata({
            owner: ownerIn,
            currency: currencyIn,
            referralsPaused: referralsPausedIn,
            referralShare: referralShareIn,
            serviceId: serviceIdIn,
            exist: true
        });

        serviceIdToServiceMetadata[serviceIdIn] = serviceMetadata;
        publicationIdToServiceMetadata[pubId] = serviceMetadata;
        return data;
    }

    /// @inheritdoc IReferenceModule
    function processComment(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed
    ) external override {
        //TODO
    }

    /// @inheritdoc IReferenceModule
    function processMirror(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed
    ) external override {
        //check that the publication is mirrorable
        if (pubIdToRelationshipPublicationInfo[pubIdPointed].mirroringAllowed == false) {
            revert UnMirrorableContent();
        }

        //add reference user's complete reference list
        profileIdToCompleteReferenceList[profileId].push(pubIdPointed);
    }

    function getCompleteReferenceListByProfileId(string profileId) external view {}

    function getCompleteReferenceListByAddress(address referencer) external view {}
}
