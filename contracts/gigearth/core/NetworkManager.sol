// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../util/Initializable.sol";
import "../interface/IArbitrable.sol";
import "../interface/IEvidence.sol";
import "../interface/ITokenFactory.sol";
import "../../interfaces/ILensHub.sol";
import "../../libraries/DataTypes.sol";
import "../libraries/Queue.sol";
import "../libraries/NetworkLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

interface IProfileCreator {
    function proxyCreateProfile(DataTypes.CreateProfileData memory vars) external;
}

interface IServiceCollectModule {
    function releaseCollectedFunds(uint256 profileId, uint256 pubId, uint8 package) external;
    function emergencyReleaseDisputedFunds(uint256 profileId, uint256 pubId, address recipient, uint8 package) external;

}

contract NetworkManager is Initializable, IArbitrable, IEvidence {
    using Queue for Queue.Uint256Queue;

    /**
     * Emitted when an address is registered with lenshub and lenstalent.
     * 
     * @param registeredAddress The address submitting the registration.
     * @param lensHandle The handle chosen by the registering address.
     */
    event UserRegistered(address indexed registeredAddress, string indexed lensHandle);

    /**
     * @param serviceId The id of the created service
     * @param marketId The id of the market
     * @param creator The creator of the service
     */
    event ServiceCreated(uint256 indexed serviceId, uint256 indexed marketId, address indexed creator);

    /**
     * Emitted when a service is purchased
     * 
     * @param purchaseId The id of the purchase
     * @param pubId The lens protocol publication id
     * @param serviceId The id of the service
     * @param owner The owner of the service
     * @param purchaser The address purchasing the service
     * @param referral The referral for the purchase, if any
     */
    event ServicePurchased(uint256 indexed serviceId, uint256 purchaseId, uint256 pubId,  address indexed owner, address indexed purchaser, address referral);

    /**
     * @param serviceId The id of the service
     * @param purchaseId The id of the purchase
     * @param serviceOwner The owner of the service
     * @param serviceClient The purchaser or client of the service
     * @param packageAmount The chosen package amount
     */
    event ServiceResolved(address indexed serviceOwner, address indexed serviceClient, uint256 indexed purchaseId, uint256 serviceId, uint8 packageAmount);

    /**
     * @param id The id of the market
     * @param marketName The name of the market
     */
    event MarketCreated(
        uint256 indexed id,
        string indexed marketName
    );

    /**
     * @dev To be emitted upon relationship ownership update
     */
    event ContractOwnershipUpdate();

    /**
     *
     */
    event ContractCreated();

    IArbitrator public arbitrator;
    ILensHub public lensHub;
    IProfileCreator public proxyProfileCreator;

    uint256 constant numberOfRulingOptions = 2;
    uint256 public constant arbitrationFeeDepositPeriod = 1;

    address public governance;
    address public treasury;
    address public LENS_FOLLOW_MODULE;
    address public LENS_CONTENT_REFERENCE_MODULE;
    ITokenFactory public _tokenFactory;
    IERC20 public _dai;

    uint256 _protocolFee = 10;
    
    mapping(address => uint256) public addressToLensProfileId;

    mapping(uint256 => uint256) public disputeIDtoRelationshipID;
    mapping(uint256 => NetworkLibrary.RelationshipEscrowDetails) public relationshipIDToEscrowDetails;

    NetworkLibrary.Relationship[] public relationships;
    mapping(uint256 => NetworkLibrary.Relationship) public relationshipIDToRelationship;

    uint256 _claimedServiceCounter;
    NetworkLibrary.Service[] public services;
    mapping(uint256 => NetworkLibrary.Service) public serviceIdToService;
    mapping(uint256 => NetworkLibrary.PurchasedServiceMetadata) public purchasedServiceIdToMetdata;

    mapping(uint256 => uint256) public relationshipIDToMarketID;
    mapping(uint256 => uint256) public serviceIDToMarketID;
    mapping(uint256 => uint256) public serviceIdToPublicationId;
    mapping(uint256 => uint256) public serviceIdToPurchaseId;

    address[] public verifiedFreelancers;

    modifier onlyWhenOwnership(uint256 contractId, NetworkLibrary.ContractOwnership ownership) {
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

    modifier onlyContractEmployer(uint256 contractId) {
         NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractId];
         require(msg.sender == relationship.employer, "only contract employer");
        _;
    }

    modifier onlyContractWorker() {
        _;
    }
    
    modifier onlyGovernance() {
        //require(msg.sender == governance);
        _;
    }

    function initialize(
        address tokenFactory,
        address _treasury,
        address _arbitrator,
        address _lensHub,
        address _proxyProfileCreator,
        address _governance,
        address dai
        ) external virtual initializer {
        require(tokenFactory != address(0), "token factory cannot be address0");
        require(_treasury != address(0), "treasury cannot be address 0");
        require(_arbitrator != address(0), "arbitrator cannot be address 0");
        require(_lensHub != address(0), "lens hub cannot be address 0");
        require(_proxyProfileCreator != address(0), "proxy profile creator");
        governance = _governance;
        treasury = _treasury;
        arbitrator = IArbitrator(_arbitrator);
        lensHub = ILensHub(_lensHub);
        proxyProfileCreator = IProfileCreator(_proxyProfileCreator);
        _dai = IERC20(dai);
        _tokenFactory = ITokenFactory(tokenFactory);
    }

    ///////////////////////////////////////////// User

    /**
     * Registers an address as a verified freelancer on lenstalent
     *
     * @param vars LensProtocol::DataTypes::CreateProfileData struct containing lenshub create profile data
     */
    function registerWorker(DataTypes.CreateProfileData calldata vars) external {
        require(!isRegisteredUser(msg.sender), "duplicate registration");
        /************ TESTNET ONLY ***************/
        //proxyProfileCreator.proxyCreateProfile(vars);
        //bytes memory b;
        //b = abi.encodePacked(vars.handle, ".test");
        //string memory registeredHandle = string(b);
        /************ END TESTNET ONLY ***************/

        /************ MAINNET AND LOCAL ONLY ***************/
        lensHub.createProfile(vars);
        bytes memory b;
        b = abi.encodePacked(vars.handle);
        string memory registeredHandle = string(b);
        /************ END MAINNET AND LOCAL ONLY ***************/
    
        addressToLensProfileId[msg.sender] = lensHub.getProfileIdByHandle(registeredHandle);
        verifiedFreelancers.push(msg.sender);
        emit UserRegistered(msg.sender, vars.handle);
    }

    /**
     * Returns the registration status of the address
     * @param account The address to check
     * @return bool true or false based on the registration status of the address
     */
    function isRegisteredUser(address account) public view returns(bool) {
        return addressToLensProfileId[account] != 0;
    }

    ///////////////////////////////////////////// Service Functions

    /**
     * Creates a service as well as deploys a new service token
     * @param marketId The market id the service belongs to
     * @param metadataPtr The ipfs hash for the metadata storage
     * @param wad The cost of the service
     * @param referralSharePayout The share to payout to the referral address
     */
    function createService(
        uint256 marketId, 
        string calldata metadataPtr, 
        uint256[] calldata wad, 
        uint256 referralSharePayout,
        address lensTalentServiceCollectModule
    ) public returns(uint) {
        MarketDetails memory marketDetails = _tokenFactory.getMarketDetailsByID(marketId);
        uint256 serviceId = _tokenFactory.addToken(marketDetails.name, marketDetails.id, msg.sender);
        console.log("New service id: ", serviceId);

        //create service
        NetworkLibrary.Service memory newService = NetworkLibrary.Service({
            marketId: marketId,
            owner: msg.sender,
            metadataPtr: metadataPtr,
            wad: wad,
            id: serviceId,
            exist: true,
            referralShare: referralSharePayout,
            collectModule: lensTalentServiceCollectModule
        });

        console.log("After added: ", newService.id);

        bytes memory collectModuleInitData = abi.encode(wad, address(_dai), msg.sender, referralSharePayout, serviceId);
        bytes memory referenceModuleInitData = abi.encode(newService);

        //create lens post
        DataTypes.PostData memory vars = DataTypes.PostData({
            profileId: addressToLensProfileId[msg.sender],
            contentURI: metadataPtr,
            collectModule: lensTalentServiceCollectModule,
            collectModuleInitData: collectModuleInitData,
            referenceModule: LENS_CONTENT_REFERENCE_MODULE,
            referenceModuleInitData: referenceModuleInitData
        });
        uint256 pubId = lensHub.post(vars);

        services.push(newService);
        serviceIdToService[serviceId] = newService;
        serviceIDToMarketID[serviceId] = marketId;
        serviceIdToPublicationId[serviceId] = pubId;

        emit ServiceCreated(serviceId, marketId, msg.sender);
        return serviceId;
    }

    /**
     * Purchases a service offering
     * @param serviceId The id of the service to purchase
     * @param referral The referrer of the contract
     */
    function purchaseServiceOffering(
        uint256 serviceId, 
        address referral,
        uint8 package,
        DataTypes.EIP712Signature calldata sig
        ) public notServiceOwner returns(uint) {
        NetworkLibrary.Service memory service = serviceIdToService[serviceId];

        _claimedServiceCounter++;
        purchasedServiceIdToMetdata[_claimedServiceCounter] = NetworkLibrary.PurchasedServiceMetadata({
            exist: true,
            client: msg.sender,
            timestampPurchased: block.timestamp,
            referral: referral,
            purchaseId: _claimedServiceCounter,
            package: package,
            status: NetworkLibrary.ServiceResolutionStatus.PENDING
        });

        serviceIdToPurchaseId[serviceId] = _claimedServiceCounter;
        bytes memory processCollectData = abi.encode(address(_dai), service.wad[0], package);

        DataTypes.CollectWithSigData memory collectWithSigData = DataTypes.CollectWithSigData({
            collector: msg.sender,
            profileId: addressToLensProfileId[service.owner],
            pubId: serviceIdToPublicationId[serviceId],
            data: processCollectData,
            sig: sig
        });

        lensHub.collectWithSig(collectWithSigData);

        emit ServicePurchased(serviceId, _claimedServiceCounter, serviceIdToPublicationId[serviceId], service.owner, msg.sender, referral);
        return _claimedServiceCounter;
    }

    /**
     * Resolves a service offering
     * @param serviceId The id of the service to resolve
     * @param purchaseId The purchase id of the service
     */ 
    function resolveService(uint256 serviceId, uint256 purchaseId) public onlyServiceClient {
        NetworkLibrary.PurchasedServiceMetadata memory metadata = purchasedServiceIdToMetdata[serviceId];
        NetworkLibrary.Service memory service = serviceIdToService[serviceId];
        require(metadata.status != NetworkLibrary.ServiceResolutionStatus.RESOLVED, "already resolved");
        require(metadata.client == msg.sender, "only client");
        require(metadata.exist == true, "service doesn't exist");

        IServiceCollectModule(service.collectModule).releaseCollectedFunds(addressToLensProfileId[service.owner], serviceIdToPublicationId[service.id], metadata.package);
        metadata.status = NetworkLibrary.ServiceResolutionStatus.RESOLVED;

       emit ServiceResolved(service.owner, msg.sender, purchaseId, serviceId, metadata.package);
    }

    ///////////////////////////////////////////// Gig Functions

    /**
     * Creates a non service based contract
     * @param marketId The id of the market the contract will be created in
     * @param taskMetadataPtr The ipfs hash where the metadata of the contract is stored
     */
    function createContract(uint256 marketId, string calldata taskMetadataPtr) external returns(uint) {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[relationships.length];
        relationship.employer = msg.sender;
        relationship.worker = address(0);
        relationship.taskMetadataPtr = taskMetadataPtr;
        relationship.wad = 0;
        relationship.acceptanceTimestamp = 0;
        relationship.resolutionTimestamp = 0;
        relationship.marketId = marketId;

        relationships.push(relationship);
        uint256 relationshipID = relationships.length - 1;
        relationshipIDToRelationship[relationshipID] = relationship;
        relationshipIDToMarketID[relationshipID] = marketId;

        emit ContractCreated();
        return relationshipID;
    }

    /**
     * Accepts a proposal for the contract with relationshipId
     * @param contractId The id of the contract
     * @param newWorker The worker to assign the contract to
     * @param wad The agreed upon payout for the contract
     * @notice Calling this function will initialize the escrow funds
     */
    function grantProposalRequest(uint256 contractId, address newWorker, uint256 wad) external onlyWhenOwnership(contractId, NetworkLibrary.ContractOwnership.Unclaimed) onlyContractEmployer(contractId) {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractId];
        require(newWorker != address(0), "You must grant this proposal to a valid worker.");
        require(relationship.worker == address(0), "This job is already being worked.");
        require(wad != uint256(0),"The payout amount must be greater than 0.");

        relationship.wad = wad;
        relationship.worker = newWorker;
        relationship.acceptanceTimestamp = block.timestamp;
        relationship.contractOwnership = NetworkLibrary.ContractOwnership.Claimed;

        _initializeEscrowFundsAndTransfer(contractId);

        emit ContractOwnershipUpdate();
    }

    /**
     * Resolves the contract and transfers escrow funds to the specified worker of the contract
     * @param contractId The id of the contract
     * @param solutionMetadataPtr The ipfs hash storing the solution metadata
     */
    function resolveContract(uint256 contractId, string calldata solutionMetadataPtr) external onlyWhenOwnership(contractId, NetworkLibrary.ContractOwnership.Claimed) onlyContractEmployer(contractId) {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractId];
    
        require(relationship.worker != address(0), "worker cannot be 0.");
        require(relationship.wad != uint256(0), "wad cannot be 0");

        _releaseContractFunds(relationship.wad, contractId);
        relationship.contractOwnership = NetworkLibrary.ContractOwnership.Resolved;

        emit ContractOwnershipUpdate();
    }

    /**
     * Allows the employer to release the contract
     * @param contractId The id of the contract
     */
    function releaseContract(uint256 contractId) external onlyWhenOwnership(contractId, NetworkLibrary.ContractOwnership.Claimed) onlyContractWorker()  {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractId];
        require(relationship.contractOwnership == NetworkLibrary.ContractOwnership.Claimed);

        _surrenderFunds(contractId);
        resetRelationshipState(relationship);

        emit ContractOwnershipUpdate();
    }

    /**
     * Resets the contract state
     * @param contractStruct The contract struct 
     */
    function resetRelationshipState(NetworkLibrary.Relationship storage contractStruct) internal {
        contractStruct.worker = address(0);
        contractStruct.acceptanceTimestamp = 0;
        contractStruct.wad = 0;
        contractStruct.contractOwnership = NetworkLibrary.ContractOwnership.Unclaimed;
    }

    /**
     * Updates a contract's ipfs metadata storage hash
     * @param contractId The id of the contract to update
     * @param newPointerHash The hash of the new pointer
     */
    function updateTaskMetadataPointer(uint256 contractId, string calldata newPointerHash) external onlyWhenOwnership(contractId, NetworkLibrary.ContractOwnership.Unclaimed) {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractId];

        require(msg.sender == relationship.employer);
        require(relationship.contractOwnership == NetworkLibrary.ContractOwnership.Unclaimed);

        relationship.taskMetadataPtr = newPointerHash;
    }

    ///////////////////////////////////////////// Kleros

    /**
     * @notice A call to this function initiates the arbitration pay period for the worker of the relationship.
     * @dev The employer must call this function a second time to claim the funds from this contract if worker does not with to enter arbitration.
     * @param contractId The id of the relationship to begin a disputed state 
     */
    function disputeRelationship(uint256 contractId) external payable {
        NetworkLibrary.Relationship memory relationship = relationshipIDToRelationship[contractId];

        NetworkLibrary.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];

        if (relationship.contractOwnership != NetworkLibrary.ContractOwnership.Claimed) {
            revert NetworkLibrary.InvalidStatus();
        }

        if (msg.sender != relationship.employer) {
            revert NetworkLibrary.NotPayer();
        }

        if (escrowDetails.status == NetworkLibrary.EscrowStatus.Reclaimed) {
            if (
                block.timestamp - escrowDetails.reclaimedAt <=
                arbitrationFeeDepositPeriod
            ) {
                revert NetworkLibrary.PayeeDepositStillPending();
            }

            _dai.transfer(relationship.worker,relationship.wad + escrowDetails.payerFeeDeposit);
            escrowDetails.status = NetworkLibrary.EscrowStatus.Resolved;

            relationship.contractOwnership = NetworkLibrary.ContractOwnership.Resolved;
        } else {
            uint256 requiredAmount = arbitrator.arbitrationCost("");
            if (msg.value < requiredAmount) {
                revert NetworkLibrary.InsufficientPayment(msg.value, requiredAmount);
            }

            escrowDetails.payerFeeDeposit = msg.value;
            escrowDetails.reclaimedAt = block.timestamp;
            escrowDetails.status = NetworkLibrary.EscrowStatus.Reclaimed;

            relationship.contractOwnership = NetworkLibrary.ContractOwnership.Disputed;
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
        NetworkLibrary.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];
        //TODO: Require the sender to be the worker of the contract

        if (escrowDetails.status != NetworkLibrary.EscrowStatus.Reclaimed) {
            revert NetworkLibrary.InvalidStatus();
        }

        escrowDetails.payeeFeeDeposit = msg.value;
        escrowDetails.disputeID = arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, "");
        escrowDetails.status = NetworkLibrary.EscrowStatus.Disputed;
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
        NetworkLibrary.Relationship memory relationship = relationshipIDToRelationship[contractId];
        NetworkLibrary.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];

        if (msg.sender != address(arbitrator)) {
            revert NetworkLibrary.NotArbitrator();
        }
        if (escrowDetails.status != NetworkLibrary.EscrowStatus.Disputed) {
            revert NetworkLibrary.InvalidStatus();
        }
        if (ruling > numberOfRulingOptions) {
            revert NetworkLibrary.InvalidRuling(ruling, numberOfRulingOptions);
        }

        escrowDetails.status = NetworkLibrary.EscrowStatus.Resolved;

        if (ruling == uint256(NetworkLibrary.RulingOptions.PayerWins)) {
            _dai.transfer(relationship.employer, relationship.wad + escrowDetails.payerFeeDeposit);
        } else {
            _dai.transfer(relationship.worker, relationship.wad + escrowDetails.payeeFeeDeposit);
        }

        emit Ruling(arbitrator, disputeId, ruling);
        relationship.contractOwnership = NetworkLibrary.ContractOwnership.Resolved;
    }

    /**
     * @notice Allows either party to submit evidence for the ongoing dispute.
     * @dev The escrow status of the smart contract must be in the disputed state.
     * @param contractId The id of the relationship to submit evidence.
     * @param _evidence A link to some evidence provided for this relationship.
     */
    function submitEvidence(uint256 contractId, string memory _evidence) public {
         NetworkLibrary.Relationship memory relationship = relationshipIDToRelationship[contractId];
        NetworkLibrary.RelationshipEscrowDetails
            storage escrowDetails = relationshipIDToEscrowDetails[contractId];

        if (escrowDetails.status != NetworkLibrary.EscrowStatus.Disputed) {
            revert NetworkLibrary.InvalidStatus();
        }

        if (
            msg.sender != relationship.employer &&
            msg.sender != relationship.worker
        ) {
            revert NetworkLibrary.ThirdPartyNotAllowed();
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
        NetworkLibrary.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];

        if (escrowDetails.status != NetworkLibrary.EscrowStatus.Reclaimed) {
            revert NetworkLibrary.InvalidStatus();
        }

        return (block.timestamp - escrowDetails.reclaimedAt) > arbitrationFeeDepositPeriod ? 0 : (escrowDetails.reclaimedAt + arbitrationFeeDepositPeriod - block.timestamp);
    }

    /// Escrow Related Functions ///

    /**
     * @notice Initializes the funds into the escrow and records the details of the escrow into a struct.
     * @param contractId The ID of the relationship to initialize escrow details
     */
    function _initializeEscrowFundsAndTransfer(uint256 contractId) internal {
        NetworkLibrary.Relationship memory relationship = relationshipIDToRelationship[contractId];
 
        relationshipIDToEscrowDetails[contractId] = NetworkLibrary.RelationshipEscrowDetails({
            status: NetworkLibrary.EscrowStatus.Initial,
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
        NetworkLibrary.Relationship memory relationship = relationshipIDToRelationship[contractId];
        NetworkLibrary.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];
        require(msg.sender == relationship.worker);
        _dai.transfer(relationship.employer,  relationship.wad);
    }

    /**
     * @notice Releases the escrow funds to the worker.
     * @param _amount The amount to release to the worker
     * @param contractId The ID of the relationship to transfer funds
     */
    function _releaseContractFunds(uint256 _amount, uint256 contractId) internal {
        NetworkLibrary.Relationship memory relationship = relationshipIDToRelationship[contractId];
        NetworkLibrary.RelationshipEscrowDetails storage escrowDetails = relationshipIDToEscrowDetails[contractId];
        require(msg.sender == relationship.employer, "only employer");
        
        escrowDetails.status = NetworkLibrary.EscrowStatus.Resolved;
        uint256 fee = _amount / _protocolFee;
        uint256 payout = _amount - fee;
        _dai.transfer(relationship.worker, payout);
        _dai.transfer(treasury, fee);
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
     */
    function setProtocolFee(uint256 protocolFee) external onlyGovernance {
        _protocolFee = protocolFee;
    }
    ///////////////////////////////////////////// Getters

    /**
     * Returns the list of registered services
     * @return All registered services
     */
    function getServices() public view returns(NetworkLibrary.Service[] memory) {
        return services;
    }

    function getContracts() public view returns(NetworkLibrary.Relationship[] memory) {
        return relationships;
    }

    /**
     * Returns service data based on the specified service id
     * @param serviceId The id of the service
     * @return Service The service to return
     */
    function getServiceData(uint256 serviceId) public view returns(NetworkLibrary.Service memory) {
        return serviceIdToService[serviceId];
    }

    /**
     * Returns contract data based on the specified contract id
     * @param contractId The id of the contract
     * @return Contract The contract to return
     */
    function getContractData(uint256 contractId) public view returns (NetworkLibrary.Relationship memory) {
        return relationshipIDToRelationship[contractId];
    }

    function getProtocolFee() external view returns(uint) {
        return _protocolFee;
    }

    function getLensProfileIdFromAddress(address account) public view returns(uint) {
        return addressToLensProfileId[account];
    }

    function getPubIdFromServiceId(uint256 serviceId) public view returns(uint) {
        return serviceIdToPublicationId[serviceId];
    }

    function getPurchaseIdFromServiceId(uint256 serviceId) public view returns(uint) {
        return serviceIdToPurchaseId[serviceId];
    }

    function getVerifiedFreelancers() public view returns(address[] memory) {
        return verifiedFreelancers;
    }

    function getServicePurchaseMetadata(uint256 purchaseId) public view returns(NetworkLibrary.PurchasedServiceMetadata memory) {
        return purchasedServiceIdToMetdata[purchaseId];
    }
}