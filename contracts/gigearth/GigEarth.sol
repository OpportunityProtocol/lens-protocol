// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./interface/IArbitrable.sol";
import "./interface/IEvidence.sol";
import "../lens-protocol/contracts/interfaces/ILensHub.sol";
import "../lens-protocol/contracts/libraries/DataTypes.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IContentReferenceModule {
    function getPubIdByRelationship(uint256 _id) external view returns(uint256);
}

contract GigEarth is IArbitrable, IEvidence {
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

    error InvalidStatus();
    error ReleasedTooEarly();
    error NotPayer();
    error NotArbitrator();
    error ThirdPartyNotAllowed();
    error PayeeDepositStillPending();
    error ReclaimedTooLate();
    error InsufficientPayment(uint256 _available, uint256 _required);
    error InvalidRuling(uint256 _ruling, uint256 _numberOfChoices);

    struct Relationship {
        address valuePtr;
        uint256 id;
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
        uint256 satisfactoryScore;
        string solutionMetadataPtr;
    }
    struct Market {
        string marketName;
        uint256 marketID;
        uint256[] relationships;
        address valuePtr;
    }

    struct UserSummary {
        uint256 lensProfileID;
        uint256 registrationTimestamp;
        address trueIdentification;
        bool isRegistered;
        uint256 referenceFee;
    }

    enum RulingOptions {
        PayerWins,
        PayeeWins
    }

    enum EscrowStatus {
        Initial,
        Reclaimed,
        Disputed,
        Resolved
    }

        enum Persona {
        Employer,
        Worker
    }

    /**
     * @dev Enum representing the states ownership for a relationship
     */
    enum ContractOwnership {
        Unclaimed,
        Pending,
        Claimed
    }

    /**
     * @dev Enum representing the states ownership for a relationship
     */
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

    struct RelationshipEscrowDetails {
        EscrowStatus status;
        uint256 valuePtr;
        uint256 disputeID;
        uint256 createdAt;
        uint256 reclaimedAt;
        uint256 payerFeeDeposit;
        uint256 payeeFeeDeposit;
    }

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
    
    mapping(address => UserSummary) private universalAddressToSummary;
    mapping(uint256 => UserSummary) private lensProfileIdToSummary;
    mapping(uint256 => Market) public marketIDToMarket;
    mapping(uint256 => Relationship)
        public relationshipIDToRelationship;
    mapping(uint256 => uint256) public relationshipIDToMilestones;
    mapping(uint256 => uint256) public relationshipIDToCurrentMilestoneIndex;
    mapping(uint256 => uint256) public relationshipIDToDeadline;
    mapping(uint256 => uint256) public disputeIDtoRelationshipID;
    mapping(uint256 => RelationshipEscrowDetails) public relationshipIDToEscrowDetails;

    modifier onlyGovernance() {
        require(msg.sender == governance);
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

    function setLensFollowModule(address _LENS_FOLLOW_MODULE) external onlyGovernance {
        LENS_FOLLOW_MODULE = _LENS_FOLLOW_MODULE;
    }

    function setLensContentReferenceModule(address _LENS_CONTENT_REFERENCE_MODULE) external onlyGovernance {
        LENS_CONTENT_REFERENCE_MODULE = _LENS_CONTENT_REFERENCE_MODULE;
    }

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

    function grantProposalRequest(uint256 _relationshipID, address _newWorker, address _valuePtr,uint256 _wad, string memory _extraData) external   {
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
        relationship.contractStatus = ContractStatus.AwaitingWorkerApproval;

        emit ContractStatusUpdate();
        emit ContractOwnershipUpdate();
    }

    function work(uint256 _relationshipID, string memory _extraData) external   {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.worker);
        require(relationship.contractOwnership == ContractOwnership.Pending);
        require(relationship.contractStatus == ContractStatus.AwaitingWorkerApproval);

        _initializeEscrowFundsAndTransfer(_relationshipID);

        relationship.contractOwnership = ContractOwnership.Claimed;
        relationship.contractStatus = ContractStatus.AwaitingResolution;
        relationship.acceptanceTimestamp = block.timestamp;

        emit EnteredContract();
        emit ContractStatusUpdate();
        emit ContractOwnershipUpdate();
    }

    function releaseJob(uint256 _relationshipID) external   {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];
        require(relationship.contractOwnership == ContractOwnership.Claimed);

        relationship.worker = address(0);
        relationship.acceptanceTimestamp = 0;
        relationship.wad = 0;
        relationship.contractStatus = ContractStatus.AwaitingWorker;
        relationship.contractOwnership = ContractOwnership.Unclaimed;

        _surrenderFunds(_relationshipID);

        emit ContractStatusUpdate();
        emit ContractOwnershipUpdate();
    }

    function updateTaskMetadataPointer(uint256 _relationshipID, string calldata _newTaskPointerHash) external   {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.employer);
        require(relationship.contractOwnership == ContractOwnership.Unclaimed);

        relationship.taskMetadataPtr = _newTaskPointerHash;
    }

    function submitWork() external {}

    function resolveTraditional(uint256 _relationshipID, uint256 _satisfactoryScore, DataTypes.EIP712Signature calldata _sig) external   {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.employer);
        require(relationship.worker != address(0));
        require(relationship.wad != uint256(0));
        require(relationship.contractStatus == ContractStatus.AwaitingResolution);

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

        bytes memory t;

        uint256[] memory profileIds = new uint256[](1);
        profileIds[0] = universalAddressToSummary[relationship.worker].lensProfileID;

        bytes[] memory b = new bytes[](1);
        b[0] = abi.encode(_relationshipID, _satisfactoryScore);

        lensHub.followWithSig(DataTypes.FollowWithSigData({
            follower: relationship.employer,
            profileIds: profileIds,
            datas: b,
            sig: _sig
        }));
        
        lensHub.post(DataTypes.PostData({
            profileId: universalAddressToSummary[relationship.worker].lensProfileID,
            contentURI: relationship.solutionMetadataPtr,
            collectModule: address(0),
            collectModuleData: t,
            referenceModule: LENS_CONTENT_REFERENCE_MODULE,
            referenceModuleData: abi.encode(_relationshipID, relationship.valuePtr,  universalAddressToSummary[relationship.worker].referenceFee)
        }));
        
        emit ContractStatusUpdate();
    }

    function resolveBounty(uint256 _relationshipID, address _worker) external {}

    /**
     * @notice Sets the contract status to resolved and releases the funds to the appropriate user.
     */
    function _resolveContractAndRewardWorker(uint256 _relationshipID) internal {
        Relationship storage relationship = relationshipIDToRelationship[_relationshipID];
         
        _releaseFunds(relationship.wad, _relationshipID);
        relationship.contractStatus = ContractStatus.Resolved;
    }

    function getRelationshipData(uint256 _relationshipID) external returns (Relationship memory)
    {
        return relationshipIDToRelationship[_relationshipID];
    }

    /// Non Interface Functionality ///

    /// Dispute Related Functions ///
    
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

    // User Functions
    function register(DataTypes.CreateProfileData calldata vars) external returns(uint256) {
        //check if the user is registered
        if (isRegisteredUser(msg.sender)) {
            revert();
        }

        //register user to lenshub and retrieve the user id from the profile handle (to will be GigEarth and user's can elect to remove opportunity as owner - will mint the nft back to the user)
        lensHub.createProfile(vars);
        uint256 lensProfileId = lensHub.getProfileIdByHandle(vars.handle);
        lensHub.setDispatcher(lensProfileId, address(this));
        
        //create a user summary and assign the user's address to the summary
        universalAddressToSummary[msg.sender] = _createUserSummary(msg.sender, lensProfileId);
    

        emit UserRegistered(msg.sender);
        
        return userSummaries.length - 1;
    }

    function unlink() external {

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

    function _createUserSummary(address _universalAddress, uint256 _lendsID) internal returns(UserSummary memory) {
        UserSummary memory userSummary = UserSummary({
            lensProfileID: _lendsID,
            registrationTimestamp: block.timestamp,
            trueIdentification: _universalAddress,
            isRegistered: true,
            referenceFee: 0
        });

         userSummaries.push();

        emit UserSummaryCreated(userSummary.registrationTimestamp, userSummaries.length, _universalAddress);
        return userSummary;
    }

    function isRegisteredUser(address _userAddress) public view returns(bool) {
        return universalAddressToSummary[_userAddress].isRegistered;
    }

    // Market Functions
    function createMarket(
        string memory _marketName,
        address _valuePtr
    ) public returns (uint256) {
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

    // Getters
    function getUserCount() public view returns(uint) {
        return userSummaries.length;
    }

    /**
     * What value will this return and in what relation will it be to the normalized value?
     */
    function getLocalPeerScore(address _observer, address _observed) public view {
        
    }

    function getSummaryByLensId(uint256 profileId) external view returns(UserSummary memory) {
        return lensProfileIdToSummary[profileId];
    }

    function getAddressByLensId(uint256 profileId) external view returns(address) {
        return lensProfileIdToSummary[profileId].trueIdentification;
    }


}