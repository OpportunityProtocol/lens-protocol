pragma solidity 0.8.10;

import {IFollowModule} from '../../../interfaces/IFollowModule.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from './FollowValidatorFollowModuleBase.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface IGigEarth {
    function getRelationshipData(uint256 _relationshipID) external returns (RelationshipLibrary.Relationship memory);
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

contract RelationshipFollowModule is IFollowModule, FollowValidatorFollowModuleBase {

    IGigEarth immutable governor;
    mapping(address => mapping(address => uint8)) public profileIdToTrust;
    
    error InvalidConnectRequest();

    constructor(address _hub, address _governor) ModuleBase(_hub) {
        governor = IGigEarth(_governor);
    }

    function initializeFollowModule(uint256 profileId, bytes calldata data)
        external
        override
        onlyHub
        returns (bytes memory)
    {}

    function processFollow(
        address follower,
        uint256 profileId,
        bytes calldata data
    ) external override {
        //ensure the two have worked together before
        (uint256 relationshipId, uint8 satisfactoryScore) = abi.decode(data, (uint256, uint8));

        RelationshipLibrary.Relationship memory relationship = governor.getRelationshipData(relationshipId);
         
        //Must have had a resolved relationship
        require(relationship.contractStatus == RelationshipLibrary.ContractStatus.Resolved);
        
        //set the satisfaction score or alter based on the previous score
        profileIdToTrust[IERC721(HUB).ownerOf(profileId)][follower] = satisfactoryScore;
    }

    function followModuleTransferHook(
        uint256 profileId,
        address from,
        address to,
        uint256 followNFTTokenId
    ) external override {}

}