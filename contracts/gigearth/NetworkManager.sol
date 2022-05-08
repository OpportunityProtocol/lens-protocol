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
import "./core/Initializable.sol";
//import "./interface/INetworkManager.sol";

interface IContentReferenceModule {
    function getPubIdByRelationship(uint256 _id) external view returns(uint256);
}

contract NetworkManager is /*INetworkManager,*/ Initializable, IArbitrable, IEvidence {
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
     * @dev To be emitted upon relationship ownership update
     */
    event ContractOwnershipUpdate();

    /**
     */
    event OperationResult(address data);

    /**
     *
     */
    event ContractCreated();

    /**
     *
     */
    event ServiceCreated();

    /**
     */
    event ServicePurchased(uint256 indexed purchaseId, uint256 indexed serviceId, address indexed purchaser, address referral);

    IArbitrator immutable arbitrator;
    ILensHub immutable public lensHub;

    uint256 constant numberOfRulingOptions = 2;
    uint256 public constant arbitrationFeeDepositPeriod = 1;
    uint8 public constant OPPORTUNITY_WITHDRAWAL_FEE = 10;

    address _owner;
    address immutable governance;
    address immutable treasury;
    address LENS_FOLLOW_MODULE;
    address LENS_CONTENT_REFERENCE_MODULE;
    ITokenFactory _tokenFactory;
    IERC20 _dai;
    
    mapping(address => uint256) public addressToLensProfileId;

    mapping(uint256 => uint256) public disputeIDtoRelationshipID;
    mapping(uint256 => NetworkInterface.RelationshipEscrowDetails) public relationshipIDToEscrowDetails;

    NetworkInterface.Relationship[] public relationships;
    mapping(uint256 => NetworkInterface.Relationship) public relationshipIDToRelationship;

    uint256 _claimedServiceCounter;
    NetworkInterface.Service[] public services;
    mapping(uint256 => uint256) public serviceIdToMaxWaitlistSize;
    mapping(uint256 => Queue.Uint256Queue) private serviceIdToWaitlist;
    mapping(uint256 => NetworkInterface.Service) public serviceIdToService;
    mapping(uint256 => NetworkInterface.PurchasedServiceMetadata) public purchasedServiceIdToMetdata;

    //TODO: Add global service/relationship identifier

    modifier onlyWhenOwnership(uint256 contractId, NetworkInterface.ContractOwnership ownership) {
        _;
    }

    modifier onlyContractEmployer() {
        _;
    }

    modifier notServiceOwner() {
        _;
    }

    modifier onlyServiceClient() {
        _;
    }

    modifier onlyOwnerOrDispatcherOfLensProfileId() {
        _;
    }

    modifier onlyContractWorker() {
        _;
    }
    
    modifier onlyGovernance() {
        require(msg.sender == governance);
        _;
    }

    constructor(
        address _governance,
        address _treasury,
        address _arbitrator, 
        address _lensHub,
        address dai
    ) 
    {
        governance = _governance;
        treasury = _treasury;
        arbitrator = IArbitrator(_arbitrator);
        lensHub = ILensHub(_lensHub);
        _dai = IERC20(dai);
    }

    function initialize(address owner, address tokenFactory) external virtual initializer {
        require(tokenFactory != address(0), "token factory cannot be 0");
        require(owner != address(0), "owner cannot be 0");
        _owner = owner;
        _tokenFactory = ITokenFactory(tokenFactory);
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
     * @param marketId The market id the service belongs to
     * @param metadataPtr The ipfs hash for the metadata storage
     * @param wad The cost of the service
     * @param initialMaxWaitlistSize The payout for referral based purchases
     * @param referralSharePayout The share to payout to the referral address
     * @param postSignature EIP712Signature to confirm lens posting.
     */
    function createService(
        uint256 marketId, 
        string calldata metadataPtr, 
        uint256 wad, 
        uint256 initialMaxWaitlistSize,
        uint256 referralSharePayout,
        DataTypes.EIP712Signature calldata postSignature
    ) external {
        uint256 serviceId = _tokenFactory.addToken("Name", marketId, msg.sender);

        //create service
        NetworkInterface.Service memory newService = NetworkInterface.Service({
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

        emit ServiceCreated();
    }

    /**
     * Purchases a service offering
     * @param serviceId The id of the service to purchase
     * @param referral The referrer of the contract
     */
    function purchaseServiceOffering(uint256 serviceId, address referral) public notServiceOwner {
        NetworkInterface.Service memory service = serviceIdToService[serviceId];
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
    function resolveServiceOffering(uint256 serviceId, uint256 purchaseId) public onlyServiceClient() {
        NetworkInterface.PurchasedServiceMetadata memory metadata = purchasedServiceIdToMetdata[serviceId];
        NetworkInterface.Service memory service = serviceIdToService[serviceId];
        require(metadata.client == msg.sender, "only client");
        require(metadata.exist == true, "service doesn't exist");

        uint256 networkFee;
        uint256 payout = service.wad;
        if (metadata.referral != address(0)) {
            uint256 referralShare = payout - service.referralShare;
            _dai.transfer(metadata.referral, service.referralShare);
            
            //TODO change network fee
            networkFee = (payout * 1);
        } else {
            //TODO change network fee
            networkFee = payout * 1;
        }
    
        uint256 ownerPayout = payout - networkFee;
        _dai.transfer(service.owner, ownerPayout); //transfer dai from escrow to client
        _dai.transfer(treasury, networkFee); //transfer dai to gig earth treasruy

        //remove from waitlist
        if (serviceIdToWaitlist[serviceId].peekLast() == purchaseId) {
            serviceIdToWaitlist[serviceId].dequeue();
        } else {
            serviceIdToWaitlist[serviceId].dequeueById(purchaseId);
        }
    }

    ///////////////////////////////////////////// Gig Functions

    /**
     * Creates a non service based contract
     * @param marketId The id of the market the contract will be created in
     * @param taskMetadataPtr The ipfs hash where the metadata of the contract is stored
     */
    function createContract(uint256 marketId, string calldata taskMetadataPtr) external onlyContractEmployer {
        NetworkInterface.Relationship memory relationshipData = NetworkInterface.Relationship({
                employer: msg.sender,
                worker: address(0),
                taskMetadataPtr: taskMetadataPtr,
                contractOwnership: NetworkInterface.ContractOwnership
                    .Unclaimed,
                wad: 0,
                acceptanceTimestamp: 0,
                resolutionTimestamp: 0,
                satisfactoryScore: 0,
                solutionMetadataPtr: "",
                marketId: marketId
        });

        relationships.push(relationshipData);
        relationshipIDToRelationship[relationships.length - 1] = relationshipData;

        emit ContractCreated();
    }

    /**
     * Accepts a proposal for the contract with relationshipId
     * @param contractId The id of the contract
     * @param newWorker The worker to assign the contract to
     * @param wad The agreed upon payout for the contract
     * @notice Calling this function will initialize the escrow funds
     */
    function grantProposalRequest(uint256 contractId, address newWorker, uint256 wad) external onlyWhenOwnership(contractId, NetworkInterface.ContractOwnership.Unclaimed) onlyContractEmployer {
        NetworkInterface.Relationship storage relationship = relationshipIDToRelationship[contractId];

        require(msg.sender == relationship.employer, "Only the employer of this relationship can grant the proposal.");
        require(newWorker != address(0), "You must grant this proposal to a valid worker.");
        require(relationship.worker == address(0), "This job is already being worked.");
        require(wad != uint256(0),"The payout amount must be greater than 0.");

        relationship.wad = wad;
        relationship.worker = newWorker;
        relationship.acceptanceTimestamp = block.timestamp;
        relationship.contractOwnership = NetworkInterface.ContractOwnership.Claimed;

        _initializeEscrowFundsAndTransfer(contractId);

        emit ContractOwnershipUpdate();
    }

    /**
     * Resolves the contract and transfers escrow funds to the specified worker of the contract
     * @param contractId The id of the contract
     * @param solutionMetadataPtr The ipfs hash storing the solution metadata
     * @param satisfactoryScore The solution satisfactory score
     */
    function resolveContract(uint256 contractId, string calldata solutionMetadataPtr, uint256 satisfactoryScore) external onlyWhenOwnership(contractId, NetworkInterface.ContractOwnership.Claimed) onlyContractEmployer {
        NetworkInterface.Relationship storage relationship = relationshipIDToRelationship[contractId];

        require(msg.sender == relationship.employer);
        require(relationship.worker != address(0));
        require(relationship.wad != uint256(0));

        bytes memory testEmptyString = bytes(relationship.solutionMetadataPtr);
        require(testEmptyString.length != 0, "Empty solution metadata pointer.");

        _releaseContractFunds(relationship.wad, contractId);
        relationship.satisfactoryScore = satisfactoryScore;

        emit ContractOwnershipUpdate();
    }

    /**
     * Allows the employer to release the contract
     * @param contractId The id of the contract
     */
    function releaseContract(uint256 contractId) external onlyWhenOwnership(contractId, NetworkInterface.ContractOwnership.Claimed) onlyContractWorker()  {
        NetworkInterface.Relationship storage relationship = relationshipIDToRelationship[contractId];
        require(relationship.contractOwnership == NetworkInterface.ContractOwnership.Claimed);

        _surrenderFunds(contractId);
        resetRelationshipState(relationship);

        emit ContractOwnershipUpdate();
    }

    /**
     * Resets the contract state
     * @param contractStruct The contract struct 
     */
    function resetRelationshipState(NetworkInterface.Relationship storage contractStruct) internal {
        contractStruct.worker = address(0);
        contractStruct.acceptanceTimestamp = 0;
        contractStruct.wad = 0;
        contractStruct.contractOwnership = NetworkInterface.ContractOwnership.Unclaimed;
    }

    /**
     * Updates a contract's ipfs metadata storage hash
     * @param contractId The id of the contract to update
     * @param newPointerHash The hash of the new pointer
     */
    function updateTaskMetadataPointer(uint256 contractId, string calldata newPointerHash) external onlyWhenOwnership(contractId, NetworkInterface.ContractOwnership.Unclaimed) {
        NetworkInterface.Relationship storage relationship = relationshipIDToRelationship[contractId];

        require(msg.sender == relationship.employer);
        require(relationship.contractOwnership == NetworkInterface.ContractOwnership.Unclaimed);

        relationship.taskMetadataPtr = newPointerHash;
    }

    ///////////////////////////////////////////// Kleros

    /**
     * @notice A call to this function initiates the arbitration pay period for the worker of the relationship.
     * @dev The employer must call this function a second time to claim the funds from this contract if worker does not with to enter arbitration.
     * @param contractId The id of the relationship to begin a disputed state 
     */
    function disputeRelationship(uint256 contractId) external payable {
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[contractId];

        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];

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

            relationship.contractOwnership = NetworkInterface.ContractOwnership.Resolved;
        } else {
            uint256 requiredAmount = arbitrator.arbitrationCost("");
            if (msg.value < requiredAmount) {
                revert NetworkInterface.InsufficientPayment(msg.value, requiredAmount);
            }

            escrowDetails.payerFeeDeposit = msg.value;
            escrowDetails.reclaimedAt = block.timestamp;
            escrowDetails.status = NetworkInterface.EscrowStatus.Reclaimed;

            relationship.contractOwnership = NetworkInterface.ContractOwnership.Disputed;
        }
    }

    /**
     * Deposits the arbitration fee 
     * @param contractId The disputed contract id
     * @notice Allows a worker to deposit an arbitration fee to accept and join the dispute 
     */
    function depositArbitrationFeeForPayee(uint256 contractId)
        external
        payable
    {
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];
        //TODO: Require the sender to be the worker of the contract

        if (escrowDetails.status != NetworkInterface.EscrowStatus.Reclaimed) {
            revert NetworkInterface.InvalidStatus();
        }

        escrowDetails.payeeFeeDeposit = msg.value;
        escrowDetails.disputeID = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, "");
        escrowDetails.status = NetworkInterface.EscrowStatus.Disputed;
        disputeIDtoRelationshipID[escrowDetails.disputeID] = contractId;
        emit Dispute(
            arbitrator,
            escrowDetails.disputeID,
            contractId,
            contractId
        );
    }

    /**
     * Submites a ruling on a disputed contract
     * @param disputeId The id of the dispute
     * @param ruling The submitted ruling for contract
     * @notice This function is called by the Kleros arbitrator
     */
    function rule(uint256 disputeId, uint256 ruling) public override {
        uint256 contractId = disputeIDtoRelationshipID[disputeId];
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[contractId];
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];

        if (msg.sender != address(arbitrator)) {
            revert NetworkInterface.NotArbitrator();
        }
        if (escrowDetails.status != NetworkInterface.EscrowStatus.Disputed) {
            revert NetworkInterface.InvalidStatus();
        }
        if (ruling > numberOfRulingOptions) {
            revert NetworkInterface.InvalidRuling(ruling, numberOfRulingOptions);
        }

        escrowDetails.status = NetworkInterface.EscrowStatus.Resolved;

        if (ruling == uint256(NetworkInterface.RulingOptions.PayerWins)) {
            _dai.transfer(relationship.employer, relationship.wad + escrowDetails.payerFeeDeposit);
        } else {
            _dai.transfer(relationship.worker, relationship.wad + escrowDetails.payeeFeeDeposit);
        }

        emit Ruling(arbitrator, disputeId, ruling);
        relationship.contractOwnership = NetworkInterface.ContractOwnership.Resolved;
    }

    /**
     * @notice Allows either party to submit evidence for the ongoing dispute.
     * @dev The escrow status of the smart contract must be in the disputed state.
     * @param contractId The id of the relationship to submit evidence.
     * @param _evidence A link to some evidence provided for this relationship.
     */
    function submitEvidence(uint256 contractId, string memory _evidence) public {
         NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[contractId];
        NetworkInterface.RelationshipEscrowDetails
            storage escrowDetails = relationshipIDToEscrowDetails[contractId];

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
            contractId,
            msg.sender,
            _evidence
        );
    }

    /**
     * @notice Returns the remaining time to deposit the arbitration fee.
     * @param contractId The id of the relationship to return the remaining time.
     */
     function remainingTimeToDepositArbitrationFee(uint256 contractId) external view returns (uint256) {
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];

        if (escrowDetails.status != NetworkInterface.EscrowStatus.Reclaimed) {
            revert NetworkInterface.InvalidStatus();
        }

        return (block.timestamp - escrowDetails.reclaimedAt) > arbitrationFeeDepositPeriod ? 0 : (escrowDetails.reclaimedAt + arbitrationFeeDepositPeriod - block.timestamp);
    }

    /// Escrow Related Functions ///

    /**
     * @notice Initializes the funds into the escrow and records the details of the escrow into a struct.
     * @param contractId The ID of the relationship to initialize escrow details
     */
    function _initializeEscrowFundsAndTransfer(uint256 contractId) internal {
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[contractId];
 
        relationshipIDToEscrowDetails[contractId] = NetworkInterface.RelationshipEscrowDetails({
            status: NetworkInterface.EscrowStatus.Initial,
            disputeID: contractId,
            createdAt: block.timestamp,
            reclaimedAt: 0,
            payerFeeDeposit: 0,
            payeeFeeDeposit: 0
        });

        _dai.transferFrom(relationship.employer, address(this), relationship.wad);
    }

    /**
     * @notice Releases the escrow funds back to the employer.
     * @param contractId The ID of the relationship to surrender the funds.
     */
    function _surrenderFunds(uint256 contractId) internal {
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[contractId];
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];
        require(msg.sender == relationship.worker);
        _dai.transfer(relationship.employer,  relationship.wad);
    }

    /**
     * @notice Releases the escrow funds to the worker.
     * @param _amount The amount to release to the worker
     * @param contractId The ID of the relationship to transfer funds
     */
    function _releaseContractFunds(uint256 _amount, uint256 contractId) internal {
        NetworkInterface.Relationship memory relationship = relationshipIDToRelationship[contractId];
        NetworkInterface.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];
            
        require(msg.sender == relationship.employer, "only employer");

        escrowDetails.status = NetworkInterface.EscrowStatus.Resolved;

        uint256 fee = _amount * OPPORTUNITY_WITHDRAWAL_FEE;
        uint256 payout = _amount - fee;
        _dai.transfer(relationship.worker, payout);
        relationship.wad = 0;
    }

    ///////////////////////////////////////////// Setters

    /**
     * Sets the appropriate lens protocol follow module
     * @param _LENS_FOLLOW_MODULE The address of the lens follow module
     */
    function setLensFollowModule(address _LENS_FOLLOW_MODULE) external onlyGovernance {
        LENS_FOLLOW_MODULE = _LENS_FOLLOW_MODULE;
    }

    /**
     * Sets the appropriate lens protocol reference module
     * @param _LENS_CONTENT_REFERENCE_MODULE The address of the lens follow module
     */
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

    /**
     * Returns the list of registered services
     * @return All registered services
     */
    function getServices() public view returns(NetworkInterface.Service[] memory) {
        return services;
    }

    /**
     * Returns service data based on the specified service id
     * @param serviceId The id of the service
     * @return Service The service to return
     */
    function getServiceData(uint256 serviceId) public view returns(NetworkInterface.Service memory) {
        return serviceIdToService[serviceId];
    }

    /**
     * Returns contract data based on the specified contract id
     * @param contractId The id of the contract
     * @return Contract The contract to return
     */
    function getContractData(uint256 contractId) external returns (NetworkInterface.Relationship memory) {
        return relationshipIDToRelationship[contractId];
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