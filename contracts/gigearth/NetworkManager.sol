// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./interface/IArbitrable.sol";
import "./interface/IEvidence.sol";
import "../interfaces/ILensHub.sol";
import "../libraries/DataTypes.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/Queue.sol";
import "./libraries/NetworkInterface.sol";
import "./interface/ITokenFactory.sol";
import "./core/TokenExchange.sol";
//import "./interface/INetworkManager.sol";

interface IContentReferenceModule {
    function getPubIdByRelationship(uint256 _id) external view returns(uint256);
}

contract NetworkManager is /*INetworkManager,*/ IArbitrable, IEvidence, TokenExchange {
    using Queue for Queue.Uint256Queue;

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

    /**
     */
    event OperationResult(address data);

    /**
     */
    event ServicePurchased(uint256 indexed purchaseId, uint256 indexed serviceId, address indexed purchaser, address referral);

    IArbitrator immutable arbitrator;
    ILensHub immutable public lensHub;

    uint256 constant numberOfRulingOptions = 2;
    uint256 public constant arbitrationFeeDepositPeriod = 1;
    uint8 public constant OPPORTUNITY_WITHDRAWAL_FEE = 10;

    address immutable governance;
    address immutable treasury;
    address LENS_FOLLOW_MODULE;
    address LENS_CONTENT_REFERENCE_MODULE;
    
    mapping(address => address) private universalAddressToSummaryAddress;
    mapping(uint256 => address) private lensProfileIdToSummary;
    mapping(address => uint256) public addressToLensProfileId;

    mapping(uint256 => uint256) public disputeIDtoRelationshipID;
    mapping(uint256 => NetworkInterface.RelationshipEscrowDetails) public relationshipIDToEscrowDetails;
    mapping(address => bool) public universalAddressToAutomatedActions;

    NetworkInterface.Relationship[] public relationships;
    mapping(uint256 => NetworkInterface.Relationship) public relationshipIDToRelationship;

    NetworkInterface.Service[] public services;
    mapping(uint256 => NetworkInterface.Service) public serviceIdToService;
    //mapping(uint256 => mapping(address => NetworkInterface.PurchasedServiceMetadata[])) public serviceIdToWaitlist; //waitlist for a given service id
    mapping(uint256 => uint256) public serviceIdToWaitlistSize;
    mapping(uint256 => uint256) public serviceIdToMaxWaitlistSize;

    mapping(uint256 => uint256) public relationshipIDToMarketID;

    mapping(uint256 => Queue.Uint256Queue) private serviceIdToWaitlist;
    mapping(uint256 => NetworkInterface.PurchasedServiceMetadata) public purchasedServiceIdToMetdata;
    uint256 _claimedServiceCounter;

    modifier notServiceOwner() {
        _;
    }

    modifier onlyServiceClient() {
        _;
    }

    modifier onlyOwnerOrDispatcherOfLensProfileId() {
        _;
    }
    
    modifier onlyGovernance() {
        require(msg.sender == governance);
        _;
    }

    modifier onlyWhenStatus(uint256 _relationshipID, NetworkInterface.ContractStatus _status) {
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        require(relationship.contractStatus == _status);
        _;
    }

    constructor(
        address _governance,
        address _treasury,
        address _arbitrator, 
        address _lensHub,
        address tokenFactory
    ) 
    {
        governance = _governance;
        treasury = _treasury;
        arbitrator = IArbitrator(_arbitrator);
        lensHub = ILensHub(_lensHub);
    }

    ///////////////////////////////////////////// User

    /**
     * Registers an address as a worker on gig earth
     * @param vars LensProtocol::DataTypes::CreateProfileData struct containing create profile data
     */
    function registerWorker(DataTypes.CreateProfileData calldata vars) external {
        if (isRegisteredUser(msg.sender)) {
            revert();
        }   

        //create lens hub profile
        lensHub.createProfile(vars);
        uint256 lensProfileId = lensHub.getProfileIdByHandle(vars.handle);
        addressToLensProfileId[msg.sender] = lensProfileId;

        emit UserRegistered(msg.sender);
    }

    /**
     * Returns the user's registration status
     * @param userAddress The address to check
     * @return True or false based on if the user is registered or not
     */
    function isRegisteredUser(address userAddress) public view returns(bool) {
        return addressToLensProfileId[userAddress] != 0;
    }

    ///////////////////////////////////////////// Service Functions

    /**
     * Creates a service as well as deploys a new service token
     * @param uint256 The market id the service belongs to
     * @param string The ipfs hash for the metadata storage
     * @param wad The cost of the service
     * @param uint256 The payout for referral based purchases
     * @param EIP712Signature EIP712Signature to confirm lens posting.
     */
    function createService(
        uint256 marketId, 
        string calldata metadataPtr, 
        uint256 wad, 
        uint256 initialMaxWaitlistSize,
        uint256 referralSharePayout,
        DataTypes.EIP712Signature calldata postSignature
    ) external {
        uint256 serviceId = _tokenFactory.addToken(metadataPtr, marketId, msg.sender);

        //create service
        NetworkInterface.Service calldata newService = NetworkInterface.Service({
            marketId: marketId,
            owner: msg.sender,
            metadataPtr: metadataPtr,
            wad: wad,
            id: serviceId,
            exist: false,
            referralShare: referralSharePayout,
            maxSize: initialMaxWaitlistSize
        });

        bytes memory collectModuleInitData = abi.encode(serviceId, newService);
        bytes memory referenceModuleInitData = abi.encode(serviceId, newService);

        //create lens post
        DataTypes.PostWithSigData memory vars = DataTypes.PostWithSigData({
            profileId: addressToLensProfileId[msg.sender],
            contentURI: metadataPtr,
            collectModule: address(0),
            collectModuleInitData: collectModuleInitData,
            referenceModule: LENS_CONTENT_REFERENCE_MODULE,
            referenceModuleInitData: referenceModuleInitData,
            sig: postSignature
        });

        lensHub.postWithSig(vars);

        services.push(newService);
        serviceIdToWaitlist[serviceId].initialize();
        serviceIdToService[serviceId] = newService;
    }

    /**
     * Purchases a service offering
     * @param serviceId The id of the service to purchase
     * @param referral The referrer of the contract
     */
    function purchaseServiceOffering(uint256 serviceId, address referral) public notServiceOwner {
        NetworkInterface memory service = serviceIdToService[serviceId];
        uint256 serviceWaitlistSize = getWaitlistLength(serviceId);

        require(serviceWaitlistSize < service.maxSize, "max waitlist reached");

        _claimedServiceCounter++;
        purchasedServiceIdToMetdata[_claimedServiceCounter] = NetworkInterface.PurchasedServiceMetadata({
            exist: true,
            client: msg.sender,
            timestampPurchased: block.timestamp,
            referral: referral,
            purchaseId: _claimedServiceCounter
        });

        serviceIdToWaitlist[serviceId].enqueue(_claimedServiceCounter);
        
        _dai.approve(address(this), service.wad);
        require(_dai.transfer(address(this), service.wad), "dai transfer");

        emit ServicePurchased(_claimedServiceCounter, serviceId, msg.sender, referral);
    }

    /**
     * Resolves a service offering
     * @param serviceId The id of the service to resolve
     * @param purchaseId The purchase id of the service
     */ 
    function resolveServiceOffering(uint256 serviceId, uint256 purchaseId) public onlyServiceClient(serviceId) {
        NetworkInterface.PurchasedServiceMetadata memory metadata = purchasedServiceIdToMetdata[serviceId];
        NetworkInterface.Service memory service = serviceIdToService[serviceId];
        require(metadata.client == msg.sender, "only client");
        require(metadata.exist == true, "service doesn't exist");

        uint256 networkFee;
        uint256 payout = service.wad;
        if (metadata.referral != address(0)) {
            uint256 referralShare = payout - service.referralShare;
            _dai.transfer(metadata.referral, service.referralShare);
            
            //calculate gig earth fee
            //TODO change network fee amount
            networkFee = (payout * 1);
        } else {
            //calculate gig earth fee
            //TODO change network fee amount
            networkFee = payout * 1;
        }
    
        uint256 ownerPayout = payout - networkFee;
        _dai.transfer(service.owner, ownerPayout); //transfer dai from escrow to client
        _dai.transfer(treasury, networkFee); //transfer dai to gig earth treasruy

        //remove from waitlist
        if (serviceIdToWaitlist[serviceId].peekLast() == purchaseId) {
            serviceIdToWaitlist[serviceId].pop();
        } else {
            serviceIdToWaitlist[serviceId].deleteWithId(purchaseId);
        }
    }

    ///////////////////////////////////////////// Gig Functions

    function createContract(
        uint256 _marketID, 
        string calldata _taskMetadataPtr
    ) internal {
        NetworkInterface.Relationship memory relationshipData = NetworkInterface.Relationship({
                employer: msg.sender,
                worker: address(0),
                taskMetadataPtr: _taskMetadataPtr,
                contractStatus: NetworkInterface.ContractStatus
                    .AwaitingWorker,
                contractOwnership: NetworkInterface.ContractOwnership
                    .Unclaimed,
                contractPayoutType: NetworkInterface.ContractPayoutType.Flat,
                wad: 0,
                acceptanceTimestamp: 0,
                resolutionTimestamp: 0,
                satisfactoryScore: 0,
                solutionMetadataPtr: ""
            });

        relationships.push(relationshipData);
        relationshipIDToRelationship[relationships.length - 1] = relationshipData;
    }

    function grantProposalRequest(uint256 _relationshipID, address _newWorker, uint256 _wad, string memory _extraData) external onlyWhenStatus(_relationshipID, NetworkInterface.ContractStatus.AwaitingWorker)   {
        NetworkInterface.Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.employer, "Only the employer of this relationship can grant the proposal.");
        require(_newWorker != address(0), "You must grant this proposal to a valid worker.");
        require(relationship.worker == address(0), "This job is already being worked.");
        require(_wad != uint256(0),"The payout amount must be greater than 0.");
        require(relationship.contractOwnership == NetworkInterface.ContractOwnership.Unclaimed,"This relationship must not already be claimed.");

        relationship.wad = _wad;
        relationship.worker = _newWorker;
        relationship.acceptanceTimestamp = block.timestamp;
        relationship.contractOwnership = NetworkInterface.ContractOwnership.Pending;

        emit ContractStatusUpdate();
        emit ContractOwnershipUpdate();
    }

        function resolveContract(uint256 _relationshipID, string calldata _solutionMetadataPtr, uint256 _satisfactoryScore) external   {
        NetworkInterface.Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.employer);
        require(relationship.worker != address(0));
        require(relationship.wad != uint256(0));
        require(relationship.contractStatus == NetworkInterface.ContractStatus.AwaitingResolution);

        bytes memory testEmptyString = bytes(relationship.solutionMetadataPtr);
        require(testEmptyString.length != 0, "Empty solution metadata pointer.");

        if (relationship.contractPayoutType == NetworkInterface.ContractPayoutType.Flat) {
            _resolveContractAndRewardWorker(_relationshipID);
        }

        relationship.satisfactoryScore = _satisfactoryScore;
        emit ContractStatusUpdate();
    }

    /**
     * @notice Sets the contract status to resolved and releases the funds to the appropriate user.
     */
    function _resolveContractAndRewardWorker(uint256 _relationshipID) internal {
        NetworkInterface.Relationship storage relationship = relationshipIDToRelationship[_relationshipID];
         
        _releaseFunds(relationship.wad, _relationshipID);
        relationship.contractStatus = NetworkInterface.ContractStatus.Resolved;
    }
    

    function releaseJob(uint256 _relationshipID) external onlyWhenStatus(_relationshipID, NetworkInterface.ContractStatus.AwaitingWorker)  {
        NetworkInterface.Relationship storage relationship = relationshipIDToRelationship[_relationshipID];
        require(relationship.contractOwnership == NetworkInterface.ContractOwnership.Claimed);

        _surrenderFunds(_relationshipID);
        resetRelationshipState(relationship);

        emit ContractStatusUpdate();
        emit ContractOwnershipUpdate();
    }

    function resetRelationshipState(NetworkInterface.Relationship storage relationship) internal {
        relationship.worker = address(0);
        relationship.acceptanceTimestamp = 0;
        relationship.wad = 0;
        relationship.contractStatus = NetworkInterface.ContractStatus.AwaitingWorker;
        relationship.contractOwnership = NetworkInterface.ContractOwnership.Unclaimed;
    }

    function updateTaskMetadataPointer(uint256 _relationshipID, string calldata _newTaskPointerHash) external onlyWhenStatus(_relationshipID, NetworkInterface.ContractStatus.AwaitingWorker)  {
        NetworkInterface.Relationship storage relationship = relationshipIDToRelationship[_relationshipID];

        require(msg.sender == relationship.employer);
        require(relationship.contractOwnership == NetworkInterface.ContractOwnership.Unclaimed);

        relationship.taskMetadataPtr = _newTaskPointerHash;
    }

    ///////////////////////////////////////////// Kleros

    /**
     * @notice A call to this function initiates the arbitration pay period for the worker of the relationship.
     * @dev The employer must call this function a second time to claim the funds from this contract if worker does not with to enter arbitration.
     * @param _relationshipID The id of the relationship to begin a disputed state 
     */
    function disputeRelationship(uint256 _relationshipID) external payable {
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[_relationshipID];

        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (relationship.contractOwnership != NetworkInterface.ContractOwnership.Claimed) {
            revert NetworkInterface.InvalidStatus();
        }

        if (msg.sender != relationship.employer) {
            revert NetworkInterface.NotPayer();
        }

        if (escrowDetails.status == NetworkInterface.EscrowStatus.Reclaimed) {
            if (
                block.timestamp - escrowDetails.reclaimedAt <=
                arbitrationFeeDepositPeriod
            ) {
                revert NetworkInterface.PayeeDepositStillPending();
            }

            _dai.transfer(relationship.worker,relationship.wad + escrowDetails.payerFeeDeposit);
            escrowDetails.status = NetworkInterface.EscrowStatus.Resolved;

            relationship.contractStatus = NetworkInterface.ContractStatus.Resolved;
        } else {
            uint256 requiredAmount = arbitrator.arbitrationCost("");
            if (msg.value < requiredAmount) {
                revert NetworkInterface.InsufficientPayment(msg.value, requiredAmount);
            }

            escrowDetails.payerFeeDeposit = msg.value;
            escrowDetails.reclaimedAt = block.timestamp;
            escrowDetails.status = NetworkInterface.EscrowStatus.Reclaimed;

            relationship.contractStatus = NetworkInterface.ContractStatus.Disputed;
        }
    }

    /**
     * @notice Allows the worker to depo
     */
    function depositArbitrationFeeForPayee(uint256 _relationshipID)
        external
        payable
    {
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (escrowDetails.status != NetworkInterface.EscrowStatus.Reclaimed) {
            revert NetworkInterface.InvalidStatus();
        }

        escrowDetails.payeeFeeDeposit = msg.value;
        escrowDetails.disputeID = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, "");
        escrowDetails.status = NetworkInterface.EscrowStatus.Disputed;
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
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (msg.sender != address(arbitrator)) {
            revert NetworkInterface.NotArbitrator();
        }
        if (escrowDetails.status != NetworkInterface.EscrowStatus.Disputed) {
            revert NetworkInterface.InvalidStatus();
        }
        if (_ruling > numberOfRulingOptions) {
            revert NetworkInterface.InvalidRuling(_ruling, numberOfRulingOptions);
        }
        escrowDetails.status = NetworkInterface.EscrowStatus.Resolved;

        if (_ruling == uint256(NetworkInterface.RulingOptions.PayerWins)) {
            _dai.transfer(relationship.employer, relationship.wad + escrowDetails.payerFeeDeposit);
        } else {
            _dai.transfer(relationship.worker, relationship.wad + escrowDetails.payeeFeeDeposit);
        }

        emit Ruling(arbitrator, _disputeID, _ruling);

            relationship.contractStatus = NetworkInterface.ContractStatus.Resolved;
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
         NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        NetworkInterface.RelationshipEscrowDetails
            storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (escrowDetails.status != NetworkInterface.EscrowStatus.Disputed) {
            revert NetworkInterface.InvalidStatus();
        }

        if (
            msg.sender != relationship.employer &&
            msg.sender != relationship.worker
        ) {
            revert NetworkInterface.ThirdPartyNotAllowed();
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
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];

        if (escrowDetails.status != NetworkInterface.EscrowStatus.Reclaimed) {
            revert NetworkInterface.InvalidStatus();
        }

        return (block.timestamp - escrowDetails.reclaimedAt) > arbitrationFeeDepositPeriod ? 0 : (escrowDetails.reclaimedAt + arbitrationFeeDepositPeriod - block.timestamp);
    }

    /// Escrow Related Functions ///

    /**
     * @notice Initializes the funds into the escrow and records the details of the escrow into a struct.
     * @param _relationshipID The ID of the relationship to initialize escrow details
     */
    function _initializeEscrowFundsAndTransfer(uint256 _relationshipID) internal {
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
 
        relationshipIDToEscrowDetails[_relationshipID] = NetworkInterface.RelationshipEscrowDetails({
            status: NetworkInterface.EscrowStatus.Initial,
            disputeID: _relationshipID,
            createdAt: block.timestamp,
            reclaimedAt: 0,
            payerFeeDeposit: 0,
            payeeFeeDeposit: 0
        });

        _dai.transferFrom(relationship.employer, address(this), relationship.wad);
    }

    /**
     * @notice Releases the escrow funds back to the employer.
     * @param _relationshipID The ID of the relationship to surrender the funds.
     */
    function _surrenderFunds(uint256 _relationshipID) internal {
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];
        require(msg.sender == relationship.worker);
        _dai.transfer(relationship.employer,  relationship.wad);
    }

    /**
     * @notice Releases the escrow funds to the worker.
     * @param _amount The amount to release to the worker
     * @param _relationshipID The ID of the relationship to transfer funds
     */
    function _releaseFunds(uint256 _amount, uint256 _relationshipID) internal {
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[_relationshipID];
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[_relationshipID];
            
        require(msg.sender == relationship.worker);


        if (relationship.contractStatus != NetworkInterface.ContractStatus.Resolved) {
            revert NetworkInterface.InvalidStatus();
        }

        escrowDetails.status = NetworkInterface.EscrowStatus.Resolved;

        uint256 fee = _amount * OPPORTUNITY_WITHDRAWAL_FEE;
        uint256 payout = _amount - fee;
        _dai.transfer(relationship.worker, payout);
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

    function getSummaryByLensId(uint256 profileId) external view returns(address) {
        return lensProfileIdToSummary[profileId];
    }

    function getServices() public view returns(NetworkInterface.Service[] memory) {
        return services;
    }

    function getRelationshipData(uint256 _relationshipID) external returns (NetworkInterface.Relationship memory) {
        return relationshipIDToRelationship[_relationshipID];
    }

    /**
     * Returns the length of the waitlist for any service
     * @param serviceId The id of the service
     * @return Returns the length of the waitlist
     */
    function getWaitlistLength(uint256 serviceId) public returns(uint256) {
        return serviceIdToWaitlist[serviceId].length();
    }
}