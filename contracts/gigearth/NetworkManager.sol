// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./interface/IArbitrable.sol";
import "./interface/IEvidence.sol";
import "../interfaces/ILensHub.sol";
import "../libraries/DataTypes.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { 
    Relationship, 
    Market, 
    UserSummary, 
    RelationshipEscrowDetails, 
    Service, 
    RulingOptions, 
    EscrowStatus, 
    Persona, 
    ContractOwnership, 
    ContractStatus, 
    ContractPayout,
    InvalidStatus,
    ReleasedTooEarly,
    NotPayer,
    NotArbitrator,
    ThirdPartyNotAllowed,
    PayeeDepositStillDepending,
    RelcaimedTooLate,
    InsufficientPayment,
    InvalidRuling
} from '../libraries/NetworkInterface.sol';

interface IContentReferenceModule {
    function getPubIdByRelationship(uint256 _id) external view returns(uint256);
}

contract NetworkManager is IArbitrable, IEvidence, TokenExchange {
    /**
     */
    event UserRegistered(address indexed universalAddress);

    /**
     */
    event UserSummaryCreated(uint256 indexed registrationTimestamp, uint256 indexed index, address indexed universalAddress);

    /**
     * @dev To be emitted upon deploying a market
     */
    event MarketCreated(
        uint256 indexed index,
        address indexed creator,
        string indexed marketName
    );

     /**
     * @dev To be emitted upon employer and worker entering contract.
     */
    event EnteredContract();

    /**
     * @dev To be emitted upon relationship status update
     */
    event ContractStatusUpdate();

    /**
     * @dev To be emitted upon relationship ownership update
     */
    event ContractOwnershipUpdate();

    UserSummary[] private userSummaries;
    Market[] public markets;
    IArbitrator immutable arbitrator;
    ILensHub immutable public lensHub;

    uint256 numRelationships;
    uint256 constant numberOfRulingOptions = 2;
    uint256 public constant arbitrationFeeDepositPeriod = 1;
    uint8 public constant OPPORTUNITY_WITHDRAWAL_FEE = 10;

    address immutable governance;
    address immutable treasury;
    address LENS_FOLLOW_MODULE;
    address LENS_CONTENT_REFERENCE_MODULE;
    
    mapping(address => address) private universalAddressToSummaryAddress;
    mapping(address => UserSummary) public universalAddressToUserSummary;
    mapping(uint256 => UserSummary) private lensProfileIdToSummary;
    mapping(uint256 => Market) public marketIDToMarket;
    mapping(uint256 => Relationship)
        public relationshipIDToRelationship;
    mapping(uint256 => uint256) public relationshipIDToMilestones;
    mapping(uint256 => uint256) public relationshipIDToCurrentMilestoneIndex;
    mapping(uint256 => uint256) public relationshipIDToDeadline;
    mapping(uint256 => uint256) public disputeIDtoRelationshipID;
    mapping(uint256 => RelationshipEscrowDetails) public relationshipIDToEscrowDetails;
    mapping(address => bool) public universalAddressToAutomatedActions;

    Service[] public services;
    mapping(uint256 => Service) public serviceIdToService;
    mapping(uint256 => address[]) public serviceIdToWaitlist; //waitlist for a given service id
    mapping(uint256 => uint256) public serviceIdToMaxWaitlistSize;

    modifier onlyGovernance() {
        require(msg.sender == governance);
        _;
    }

    modifier onlyWhenStatus(uint256 _relationshipID, ContractStatus _status) {
        Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        require(relationship.contractStatus == _status);
        _;
    }

    constructor(
        address _governance,
        address _treasury,
        address _arbitrator, 
        address _lensHub
    ) 
    {
        governance = _governance;
        treasury = _treasury;
        arbitrator = IArbitrator(_arbitrator);
        lensHub = ILensHub(_lensHub);
    }

    ///////////////////////////////////////////// User

    /**
     * Register as a worker
     * @param vars LensProtocol profile data struct
     * @return Returns The user's GigEarth id
     */
    function registerWorker(DataTypes.CreateProfileData calldata vars) external returns(uint256) {
        //check if the user is alredy registered
        if (_isRegisteredUser(msg.sender)) {
            revert();
        }   

        //create lens hub profile
        lensHub.createProfile(vars);
        uint256 lensProfileId = lensHub.getProfileIdByHandle(vars.handle);

        //create and store user summary
        universalAddressToSummaryAddress[msg.sender] = new address(UserSummary(msg.sender, lensProfileId, vars.contentUri)); //_createUserSummary(msg.sender, lensProfileId);
    
        emit UserRegistered(msg.sender);
    }

    function _createUserSummary(address _universalAddress, uint256 _lendsID) internal returns(UserSummary memory) {
        UserSummary memory userSummary = UserSummary({
            lensProfileID: _lendsID,
            registrationTimestamp: block.timestamp,
            trueIdentification: _universalAddress,
            isRegistered: true,
            referenceFee: 0
        });

         userSummaries.push(userSummary);

        emit UserSummaryCreated(userSummary.registrationTimestamp, userSummaries.length, _universalAddress);
        return userSummary;
    }

    function submitReview(
        uint256 _relationshipID, 
        string calldata _reviewHash
    ) external {
        Relationship memory relationship = relationshipIDToRelationship[_relationshipID];

        require(relationship.contractStatus == ContractStatus.Resolved);
        require(block.timestamp < relationship.resolutionTimestamp + 30 days);

        uint256 pubIdPointed = IContentReferenceModule(LENS_CONTENT_REFERENCE_MODULE).getPubIdByRelationship(_relationshipID);

        bytes memory t;
        DataTypes.CommentData memory commentData = DataTypes.CommentData({
            profileId: universalAddressToSummary[relationship.employer].lensProfileID,
            contentURI: _reviewHash,
            profileIdPointed:  universalAddressToSummary[relationship.worker].lensProfileID,
            pubIdPointed: pubIdPointed,
            collectModule: address(0),
            collectModuleData: t,
            referenceModule: address(0),
            referenceModuleData: t
        });

        lensHub.comment(commentData);
    }

    function _isRegisteredUser(address userAddress) public view returns(bool) {
        return universalAddressToSummary[userAddress] != address(0);
    }

    ///////////////////////////////////////////// Service Functions

    function createService(
        uint256 marketId, 
        string metadataPtr, 
        uint256 wad, 
        uint256 initialWaitlistSize,
        uint256 referralSharePayout
        EIP712MintTokenSignature mintTokenSig
    ) external {
        //compute service id
        uint256 serviceId = services.length;

        //create service
        Service storage newService = Service({
            marketId: marketId,
            owner: msg.sender,
            metadataPtr: metadataPtr,
            wad: wad,
            MAX_WAITLIST_SIZE: initialWaitlistSize,
            id: serviceId,
            exist: false,
            referralShare: referralSharePayout
        });

        services.push(newService);

        uint256 profileId = IUserSummary(universalAddressToSummary[msg.sender]).getLensProfileId();

        //create lens post
        DataTypes.PostData vars = DataTypes.PostData({
            profileId: profileId,
            contentURI: metadataPtr,
            collectModule: 0,
            collectModuleData: bytes(0),
            referenceModule: LENS_CONTENT_REFERENCE_MODULE,
            referenceModuleData: bytes(0)
        });

        lensHub.postWithSig(vars);

        uint256 pubId = lensHub.getProfile(profileId).pubCount;

        _registerService(pubId, newService, mintTokenSig);
    }

    function _registerService(uint256 lensPublicationId, Service newService, uint256 initialWaitlistSize, EIP712MintTokenSignature sig) internal {
        //add service
        servicesIdToService[lensPublicationId] = newService;
        serviceIdToWaitlist[lensPublicationId] = [];
        serviceIdToMaxWaitlistSize[lensPublicationId] = initialWaitlistSize;

        //mint one token to owner
        IERC1155(universalAddressToSummaryAddress[msg.sender]).mint(newService.owner, newService.serviceId, 1, bytes(0));

        //verify sig
    }

    /**
     * Purchases a service offering
     * @param serviceId The id of the service to purchase
     *
     * @notice There is no mechanism to withdraw funds once a service has been purchased. All interactions should
     * be handled through gig earth incase of dispute.
     */
    function purchaseServiceOffering(uint256 serviceId) public notServiceOwner {
        uint256 currMaxWaitlistSize = serviceIdToMaxWaitlistSize[serviceId];
        uint256 serviceWaitlistSize = serviceIdToWaitlist[serviceId].length;

        require(serviceWaitlistSize <= currMaxWaitlistSize, "max waitlist reached");
        serviceIdToWaitlist[serviceId].push(ClaimedServiceMetadata({
            serviceId: serviceId,
            client: msg.sender,
            timestampPurchased: block.timestamp
        }));

        Service serviceDetails = serviceIdToService[serviceId];
        daiToken.approve(address(this), serviceDetails.wad);
        require(daiToken.transfer(address(this), serviceDetails.wad), "dai transfer");
    }

    /**
     * Resolves a service offering
     * @param serviceId The id of the service to resolve
     */
    function resolveServiceOffering(uint256 serviceId) onlyServiceClient {
        require(serviceIdToWaitlist[serviceId][serviceId].client == msg.sender);
        
        uint256 networkFee;
        uint256 payout = serviceIdToService[serviceId].wad;
        if (serviceIdToWaitlist[serviceId][serviceId].referral != address(0)) {
            uint256 referralShare = payout - serviceIdToWaitlist[serviceId][serviceId].referralShare;
            dai.transfer(serviceIdToWaitlist[serviceId][serviceId].referral, referralShare);
            
            //calculate gig earth fee
            //TODO change network fee amount
            networkFee = ((payout - referralShare) * .01)
        } else {
            //calculate gig earth fee
            //TODO change network fee amount
            networkFee = payout * .01;
        }
    
        uint256 ownerPayout = payout - networkFee;
        daiToken.transfer(serviceIdToService[serviceId].owner, ownerPayout); //transfer dai from escrow to client
        daiToken.transfer(treasury, networkFee); //transfer dai to gig earth treasruy

        //remove from waitlist
        delete serviceIdToWaitlist[serviceId][serviceId]; //leaves a gap at index [serviceId]
    }

    ///////////////////////////////////////////// Gig Functions

    function initializeContract(
        uint256 _relationshipID, 
        uint256 _deadline, 
        address _valuePtr, 
        address _employer, 
        uint256 _marketID, 
        string calldata _taskMetadataPtr
    ) internal {
        Relationship memory relationshipData = Relationship({
                valuePtr: _valuePtr,
                id: _relationshipID,
                marketPtr: _marketID,
                employer: _employer,
                worker: address(0),
                taskMetadataPtr: _taskMetadataPtr,
                contractStatus: ContractStatus
                    .AwaitingWorker,
                contractOwnership: ContractOwnership
                    .Unclaimed,
                contractPayoutType: ContractPayoutType.Flat,
                wad: 0,
                acceptanceTimestamp: 0,
                resolutionTimestamp: 0,
                satisfactoryScore: 0,
                solutionMetadataPtr: ""
            });

        relationshipIDToRelationship[_relationshipID] = relationshipData;

        if (_deadline != 0) {
            relationshipIDToDeadline[_relationshipID] = _deadline;
        }

        numRelationships++;
    }

    function grantProposalRequest(uint256 _relationshipID, address _newWorker, address _valuePtr,uint256 _wad, string memory _extraData) external onlyWhenStatus(_relationshipID, ContractStatus.AwaitingWorker)   {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.employer, "Only the employer of this relationship can grant the proposal.");
        require(_newWorker != address(0), "You must grant this proposal to a valid worker.");
        require(relationship.worker == address(0), "This job is already being worked.");
        require(_valuePtr != address(0), "You must enter a valid address for the value pointer.");
        require(_wad != uint256(0),"The payout amount must be greater than 0.");
        require(relationship.contractOwnership == ContractOwnership.Unclaimed,"This relationship must not already be claimed.");

        relationship.wad = _wad;
        relationship.valuePtr = _valuePtr;
        relationship.worker = _newWorker;
        relationship.acceptanceTimestamp = block.timestamp;
        relationship.contractOwnership = ContractOwnership.Pending;

        emit ContractStatusUpdate();
        emit ContractOwnershipUpdate();
    }

    function work(uint256 _relationshipID, string memory _extraData) external onlyWhenStatus(_relationshipID, ContractStatus.AwaitingWorker) {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.worker);
        require(relationship.contractOwnership == ContractOwnership.Pending);

        _initializeEscrowFundsAndTransfer(_relationshipID);

        relationship.contractOwnership = ContractOwnership.Claimed;
        relationship.contractStatus = ContractStatus.AwaitingResolution;
        relationship.acceptanceTimestamp = block.timestamp;

        emit EnteredContract();
        emit ContractStatusUpdate();
        emit ContractOwnershipUpdate();
    }

    function releaseJob(uint256 _relationshipID) external onlyWhenStatus(_relationshipID, ContractStatus.AwaitingWorker)  {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];
        require(relationship.contractOwnership == ContractOwnership.Claimed);

        _surrenderFunds(_relationshipID);
        resetRelationshipState(relationship);

        emit ContractStatusUpdate();
        emit ContractOwnershipUpdate();
    }

    function resetRelationshipState(Relationship storage relationship) internal {
        relationship.worker = address(0);
        relationship.acceptanceTimestamp = 0;
        relationship.wad = 0;
        relationship.contractStatus = ContractStatus.AwaitingWorker;
        relationship.contractOwnership = ContractOwnership.Unclaimed;
    }

    function updateTaskMetadataPointer(uint256 _relationshipID, string calldata _newTaskPointerHash) external onlyWhenStatus(_relationshipID, ContractStatus.AwaitingWorker)  {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.employer);
        require(relationship.contractOwnership == ContractOwnership.Unclaimed);

        relationship.taskMetadataPtr = _newTaskPointerHash;
    }
    
    /* The final solution hash - can be called as long as resolveTraditional hasn't been called  */
    function submitWork(uint256 _relationshipID, string calldata _solutionMetadataPtr) onlyWhenStatus(_relationshipID, ContractStatus.AwaitingWorker) external {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];
        require(msg.sender == relationship.worker, "Only the worker can call this function.");

        relationship.solutionMetadataPtr = _solutionMetadataPtr;
    }

    function resolveTraditional(uint256 _relationshipID, uint256 _satisfactoryScore) external   {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.employer);
        require(relationship.worker != address(0));
        require(relationship.wad != uint256(0));
        require(relationship.contractStatus == ContractStatus.AwaitingResolution);

        bytes memory testEmptyString = bytes(relationship.solutionMetadataPtr);
        require(testEmptyString.length != 0, "Empty solution metadata pointer.");

        if (relationship.contractPayoutType == ContractPayoutType.Flat) {
            _resolveContractAndRewardWorker(_relationshipID);
        } else {
            if (relationshipIDToCurrentMilestoneIndex[_relationshipID] == relationshipIDToMilestones[_relationshipID] - 1) {
                _resolveContractAndRewardWorker(_relationshipID);
            } else {
                relationshipIDToCurrentMilestoneIndex[_relationshipID]++;
            }
        }

        relationship.satisfactoryScore = _satisfactoryScore;
        emit ContractStatusUpdate();
    }

    /**
     * @notice Sets the contract status to resolved and releases the funds to the appropriate user.
     */
    function _resolveContractAndRewardWorker(uint256 _relationshipID) internal {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];
         
        _releaseFunds(relationship.wad, _relationshipID);
        relationship.contractStatus = ContractStatus.Resolved;
    }

    ///////////////////////////////////////////// Market Functions
    function createMarket(
        string memory _marketName,
        address _valuePtr
    ) public onlyGovernance returns (uint256) {
        uint256 marketID = markets.length + 1;

        Market memory newMarket = Market({
            marketName: _marketName,
            marketID: marketID,
            relationships: new uint256[](0),
            valuePtr: _valuePtr
        });

        markets.push(newMarket);
        marketIDToMarket[marketID] = newMarket;

        emit MarketCreated(
            marketID,
            msg.sender,
            _marketName
        );
        
        return markets.length;
    }

    /**
     * @param _marketID The id of the market to create the relationship
     * @param _taskMetadataPtr The hash on IPFS for the relationship metadata
     * @param _deadline The deadline for the worker to complete the relationship
     */
    function createFlatRateRelationship(
        uint256 _marketID, 
        string calldata _taskMetadataPtr, 
        uint256 _deadline
    ) external {
        Market storage market = marketIDToMarket[_marketID];
        uint256 relationshipID = market.relationships.length + 1;
        market.relationships.push(relationshipID);

        initializeContract(
            relationshipID,
            _deadline,
            market.valuePtr,
            msg.sender,
            _marketID,
            _taskMetadataPtr
        );
    }

    /**
     * @param _marketID The id of the market to create the relationship
     * @param _taskMetadataPtr The hash on IPFS for the relationship metadata
     * @param _deadline The deadline for the worker to complete the relationship
     * @param _numMilestones The number of milestones in this relationship
     */
    function createMilestoneRelationship(
        uint256 _marketID, 
        string calldata _taskMetadataPtr, 
        uint256 _deadline, 
        uint256 _numMilestones
    ) external {
        Market storage market = marketIDToMarket[_marketID];
        uint256 relationshipID = market.relationships.length + 1;
        market.relationships.push(relationshipID);

        initializeContract(
            relationshipID,
            _deadline,
            market.valuePtr,
            msg.sender,
            _marketID,
            _taskMetadataPtr
        );
    }

    ///////////////////////////////////////////// Kleros

    /**
     * @notice A call to this function initiates the arbitration pay period for the worker of the relationship.
     * @dev The employer must call this function a second time to claim the funds from this contract if worker does not with to enter arbitration.
     * @param _relationshipID The id of the relationship to begin a disputed state 
     */
    function disputeRelationship(uint256 _relationshipID) external payable {
        Relationship memory relationship = relationshipIDToRelationship[_relationshipID];

        RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (relationship.contractOwnership != ContractOwnership.Claimed) {
            revert InvalidStatus();
        }

        if (msg.sender != relationship.employer) {
            revert NotPayer();
        }

        if (escrowDetails.status == EscrowStatus.Reclaimed) {
            if (
                block.timestamp - escrowDetails.reclaimedAt <=
                arbitrationFeeDepositPeriod
            ) {
                revert PayeeDepositStillPending();
            }

            IERC20(relationship.valuePtr).transfer(relationship.worker,relationship.wad + escrowDetails.payerFeeDeposit);
            escrowDetails.status = EscrowStatus.Resolved;

            relationship.contractStatus = ContractStatus.Resolved;
        } else {
            uint256 requiredAmount = arbitrator.arbitrationCost("");
            if (msg.value < requiredAmount) {
                revert InsufficientPayment(msg.value, requiredAmount);
            }

            escrowDetails.payerFeeDeposit = msg.value;
            escrowDetails.reclaimedAt = block.timestamp;
            escrowDetails.status = EscrowStatus.Reclaimed;

            relationship.contractStatus = ContractStatus.Disputed;
        }
    }

    /**
     * @notice Allows the worker to depo
     */
    function depositArbitrationFeeForPayee(uint256 _relationshipID)
        external
        payable
    {
        RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (escrowDetails.status != EscrowStatus.Reclaimed) {
            revert InvalidStatus();
        }

        escrowDetails.payeeFeeDeposit = msg.value;
        escrowDetails.disputeID = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, "");
        escrowDetails.status = EscrowStatus.Disputed;
        disputeIDtoRelationshipID[escrowDetails.disputeID] = _relationshipID;
        emit Dispute(
            arbitrator,
            escrowDetails.disputeID,
            _relationshipID,
            _relationshipID
        );
    }

    /**
     *
     */
    function rule(uint256 _disputeID, uint256 _ruling) public override {
        uint256 _relationshipID = disputeIDtoRelationshipID[_disputeID];
        Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (msg.sender != address(arbitrator)) {
            revert NotArbitrator();
        }
        if (escrowDetails.status != EscrowStatus.Disputed) {
            revert InvalidStatus();
        }
        if (_ruling > numberOfRulingOptions) {
            revert InvalidRuling(_ruling, numberOfRulingOptions);
        }
        escrowDetails.status = EscrowStatus.Resolved;

        if (_ruling == uint256(RulingOptions.PayerWins)) {
            IERC20(relationship.valuePtr).transfer(relationship.employer, relationship.wad + escrowDetails.payerFeeDeposit);
        } else {
            IERC20(relationship.valuePtr).transfer(relationship.worker, relationship.wad + escrowDetails.payeeFeeDeposit);
        }

        emit Ruling(arbitrator, _disputeID, _ruling);

            relationship.contractStatus = ContractStatus.Resolved;
    }

    /**
     * @notice Allows either party to submit evidence for the ongoing dispute.
     * @dev The escrow status of the smart contract must be in the disputed state.
     * @param _relationshipID The id of the relationship to submit evidence.
     * @param _evidence A link to some evidence provided for this relationship.
     */
    function submitEvidence(uint256 _relationshipID, string memory _evidence)
        public
    {
         Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        RelationshipEscrowDetails
            storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (escrowDetails.status != EscrowStatus.Disputed) {
            revert InvalidStatus();
        }

        if (
            msg.sender != relationship.employer &&
            msg.sender != relationship.worker
        ) {
            revert ThirdPartyNotAllowed();
        }

        emit Evidence(
            arbitrator,
            _relationshipID,
            msg.sender,
            _evidence
        );
    }

    /**
     * @notice Returns the remaining time to deposit the arbitration fee.
     * @param _relationshipID The id of the relationship to return the remaining time.
     */
     function remainingTimeToDepositArbitrationFee(uint256 _relationshipID) external view returns (uint256) {
        RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (escrowDetails.status != EscrowStatus.Reclaimed) {
            revert InvalidStatus();
        }

        return (block.timestamp - escrowDetails.reclaimedAt) > arbitrationFeeDepositPeriod ? 0 : (escrowDetails.reclaimedAt + arbitrationFeeDepositPeriod - block.timestamp);
    }

    /// Escrow Related Functions ///

    /**
     * @notice Initializes the funds into the escrow and records the details of the escrow into a struct.
     * @param _relationshipID The ID of the relationship to initialize escrow details
     */
    function _initializeEscrowFundsAndTransfer(uint256 _relationshipID) internal {
        Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
 
        relationshipIDToEscrowDetails[_relationshipID] = RelationshipEscrowDetails({
            status: EscrowStatus.Initial,
            valuePtr: relationship.wad,
            disputeID: _relationshipID,
            createdAt: block.timestamp,
            reclaimedAt: 0,
            payerFeeDeposit: 0,
            payeeFeeDeposit: 0
        });

        IERC20(relationship.valuePtr).transferFrom(relationship.employer, address(this), relationship.wad);
    }

    /**
     * @notice Releases the escrow funds back to the employer.
     * @param _relationshipID The ID of the relationship to surrender the funds.
     */
    function _surrenderFunds(uint256 _relationshipID) internal {
        Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];
        require(msg.sender == relationship.worker);
        IERC20(relationship.valuePtr).transfer(relationship.employer,  relationship.wad);
    }

    /**
     * @notice Releases the escrow funds to the worker.
     * @param _amount The amount to release to the worker
     * @param _relationshipID The ID of the relationship to transfer funds
     */
    function _releaseFunds(uint256 _amount, uint256 _relationshipID) internal {
        Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];
            
        require(msg.sender == relationship.worker);


        if (relationship.contractStatus != ContractStatus.Resolved) {
            revert InvalidStatus();
        }

        escrowDetails.status = EscrowStatus.Resolved;

        uint256 fee = _amount * OPPORTUNITY_WITHDRAWAL_FEE;
        uint256 payout = _amount - fee;
        IERC20(relationship.valuePtr).transfer(relationship.worker, payout);
        relationship.wad = 0;
    }

    ///////////////////////////////////////////// Setters
    function setLensFollowModule(address _LENS_FOLLOW_MODULE) external onlyGovernance {
        LENS_FOLLOW_MODULE = _LENS_FOLLOW_MODULE;
    }

    function setLensContentReferenceModule(address _LENS_CONTENT_REFERENCE_MODULE) external onlyGovernance {
        LENS_CONTENT_REFERENCE_MODULE = _LENS_CONTENT_REFERENCE_MODULE;
    }

    /**
     * Set max waitlist size for any service
     * @param serviceId The id of the service
     * @param newMaxWaitlistSize The desired size of the waitlist for a given service
     */
    function setMaxWaitlistSize(uint256 serviceId, uint256 newMaxWaitlistSize) public onlyOwnerOrDispatcherOfLensProfileId {}

    ///////////////////////////////////////////// Getters
    function getUserCount() public view returns(uint) {
        return userSummaries.length;
    }


    function getLocalPeerScore(address _observer, address _observed) public view {}

    function getSummaryByLensId(uint256 profileId) external view returns(UserSummary memory) {
        return lensProfileIdToSummary[profileId];
    }

    function getAddressByLensId(uint256 profileId) external view returns(address) {
        return lensProfileIdToSummary[profileId].trueIdentification;
    }

    function getServices() public view returns(Services[]) {
        return services;
    }

    function getLensProfileId() external view returns(uint256) {
        return lensProfileId;
    }

    function getRelationshipData(uint256 _relationshipID) external returns (Relationship memory) {
        return relationshipIDToRelationship[_relationshipID];
    }
}