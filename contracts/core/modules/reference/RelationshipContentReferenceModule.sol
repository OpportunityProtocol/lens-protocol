pragma solidity 0.8.10;

import {IReferenceModule} from '../../../interfaces/IReferenceModule.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidationModuleBase} from '../FollowValidationModuleBase.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {FeeModuleBase} from '../FeeModuleBase.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**
 * Questions:
 * - Linking libraries
 * - Copyrights and web3 - Giving rights away to work per smart contract ( See processMirror() )
 */

interface IGigEarth {
    function getRelationshipData(uint256 _relationshipID)
        external
        returns (RelationshipLibrary.Relationship memory);
}


library RelationshipLibrary {
      struct Relationship {
        address valuePtr;
        uint256 id;
        address escrow;
        uint256 marketPtr;
        address employer;
        address worker;
        string taskMetadataPtr;
        ContractStatus contractStatus;
        ContractOwnership contractOwnership;
        ContractPayoutType contractPayoutType;
        uint256 wad;
        uint256 acceptanceTimestamp;
        uint256 resolutionTimestamp;
    }

    enum ContractOwnership {
        Unclaimed,
        Pending,
        Claimed
    }

    enum ContractStatus {
        AwaitingWorker,
        AwaitingWorkerApproval,
        AwaitingResolution,
        Resolved,
        PendingDispute,
        Disputed
    }

    enum ContractPayoutType {
        Flat,
        Milestone
    }
}

contract RelationshipContentReferenceModule is
    IReferenceModule,
    FollowValidationModuleBase,
    FeeModuleBase
{
    using SafeERC20 for IERC20;

    IGigEarth immutable governor;

    constructor(
        address _hub,
        address moduleGlobals,
        address _governor
    ) FeeModuleBase(moduleGlobals) ModuleBase(_hub) {
        governor = IGigEarth(_governor);
    }

    struct PublicationMetadata {
        address employer;
        address worker;
        bool mirroringAllowed;
        address currency;
        uint256 fee;
        uint256[] mirrors;
        uint256 relationshipId;
        bool reviewSubmited;
    }

    mapping(uint256 => uint256) public relationshipIdToPublicationId;
    mapping(uint256 => PublicationMetadata) pubIdToRelationshipPublicationInfo;

    error InvalidRelationshipState();
    error DuplicateRelationshipPost();
    error UnMirrorableContent();
    error InsufficientFee();

    /// @inheritdoc IReferenceModule
    function initializeReferenceModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external override onlyHub returns (bytes memory) {
        (uint256 relationshipId, address currency, uint256 fee) = abi.decode( data, (uint256, address, uint256) );

        if (!_currencyWhitelisted(currency) || fee < BPS_MAX) {
            revert ();//Errors.InitParamsInvalid();
        }


        PublicationMetadata memory publicationMetadata = PublicationMetadata({
            employer: address(0),
            worker: address(0),
            mirroringAllowed: false,
            fee: fee,
            currency: currency,
            mirrors: new uint256[](0),
            relationshipId: relationshipId,
            reviewSubmited: false
        });

        if (relationshipId != 0) {
            RelationshipLibrary.Relationship memory relationship = governor.getRelationshipData(
                relationshipId
            );

            //check if relationship is resolved
            if (relationship.contractStatus != RelationshipLibrary.ContractStatus.Resolved) {
                revert InvalidRelationshipState();
            }

            //check to make sure this publication doesn't belong to a relationship
            if (relationshipIdToPublicationId[relationship.id] != 0) {
                revert DuplicateRelationshipPost();
            }

            publicationMetadata.relationshipId = relationship.id;
            publicationMetadata.employer = relationship.employer;
            publicationMetadata.worker = relationship.worker;
            relationshipIdToPublicationId[relationship.id] = pubId; //after setting this we won't need to reassign this ever again once the relationship is resolved
        } else {
            publicationMetadata.employer = tx.origin; //GigEarth will not make post content outside of resolved relationships so we can assume the poster is the worker (content creator)
        }

        pubIdToRelationshipPublicationInfo[pubId] = publicationMetadata;
        return data;
    }

    /// @inheritdoc IReferenceModule
    function processComment(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed
    ) external override {
         address employerAsReviewer = IERC721(HUB).ownerOf(profileId);

        //check employer follows the worker (have done work together before)
        _checkFollowValidity(profileIdPointed, employerAsReviewer);
        //make sure no review has been submitted for this post
        require(pubIdToRelationshipPublicationInfo[pubIdPointed].reviewSubmited == false);
       
       
        //check to make sure this came from a relationship where the employer is the one making the review
        require(employerAsReviewer == pubIdToRelationshipPublicationInfo[pubIdPointed].employer);
    }

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

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

        uint256 fee = pubIdToRelationshipPublicationInfo[pubIdPointed].fee;
        address currency = pubIdToRelationshipPublicationInfo[pubIdPointed].currency;
         //_validateDataIsExpected(data, currency, fee);

        (address treasury, uint16 treasuryFee) = _treasuryData();
        address recipient = pubIdToRelationshipPublicationInfo[pubIdPointed].worker;
        uint256 treasuryAmount = (fee * treasuryFee) / BPS_MAX;
        uint256 adjustedAmount = fee - treasuryAmount;

        IERC20(currency).safeTransferFrom(IERC721(HUB).ownerOf(profileId), recipient, adjustedAmount);
        IERC20(currency).safeTransferFrom(IERC721(HUB).ownerOf(profileId), treasury, treasuryAmount);
    }

    function setPublicationMirrorableStatus(
        uint256 pubId,
        bool status,
        uint256 fee
    ) external {
        require(msg.sender == pubIdToRelationshipPublicationInfo[pubId].worker);

        PublicationMetadata storage publicationMetadata = pubIdToRelationshipPublicationInfo[pubId];
        publicationMetadata.fee = fee;
        publicationMetadata.mirroringAllowed = status;
    }
  function getPubIdByRelationship(uint256 _id) external view returns(uint256) {
      return relationshipIdToPublicationId[_id];
  }
}
