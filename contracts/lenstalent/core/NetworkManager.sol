// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '../util/Initializable.sol';
import '../interface/IArbitrable.sol';
import '../interface/IEvidence.sol';
import '../interface/ITokenFactory.sol';
import '../interface/INetworkManager.sol';
import '../../interfaces/ILensHub.sol';
import '../../libraries/DataTypes.sol';
import '../libraries/NetworkLibrary.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import 'hardhat/console.sol';

interface IProfileCreator {
    function proxyCreateProfile(DataTypes.CreateProfileData memory vars) external;
}

contract NetworkManager is INetworkManager, Initializable, IEvidence {
    /**
     * Emitted when an address is registered with lenshub and lenstalent.
     *
     * @param registeredAddress The address submitting the registration.
     * @param lensHandle The handle chosen by the registering address.
     * @param profileId The profile id of the user registering through Lens
     * @param imageURI The URI of the image
     * @param metadata The URI of the user metadata
     */
    event UserRegistered(
        address indexed registeredAddress,
        string lensHandle,
        uint256 indexed profileId,
        string imageURI,
        string metadata
    );

    /**
     * Emitted when a new service is created
     *
     * @param serviceId The id of the created service
     * @param marketId The id of the market
     * @param creator The creator of the service
     */
    event ServiceCreated(
        uint256 indexed serviceId,
        uint256 indexed marketId,
        address indexed creator,
        uint256[] offers,
        string metadataPtr,
        uint256 pubId
    );

    /**
     * Emitted when a service is purchased
     *
     * @param purchaseId The id of the purchase
     * @param pubId The lens protocol publication id
     * @param serviceId The id of the service
     * @param owner The owner of the service
     * @param purchaser The address purchasing the service
     */
    event ServicePurchased(
        uint256 indexed serviceId,
        uint256 purchaseId,
        uint256 pubId,
        address indexed owner,
        address indexed purchaser,
        uint256 offer
    );

    /**
     * Emitted whena  service is resolved
     *
     * @param serviceId The id of the service
     * @param purchaseId The id of the purchase
     * @param serviceOwner The owner of the service
     * @param serviceClient The purchaser or client of the service
     * @param packageAmount The chosen package amount
     */
    event ServiceResolved(
        address indexed serviceOwner,
        address indexed serviceClient,
        uint256 indexed purchaseId,
        uint256 serviceId,
        uint8 packageAmount
    );

    /**
     * Emitted when a new worker is given permission to work the contract
     *
     * @param id The id of the contract
     * @param marketId The market id of the contract
     * @param ownership The new contract status
     * @param employer The address of the employer
     * @param worker The address of the worker (if any)
     */
    event ContractOwnershipUpdate(
        uint256 indexed id,
        uint256 indexed marketId,
        NetworkLibrary.ContractOwnership indexed ownership,
        address employer,
        address worker,
        uint256 amt
    );

    /**
     * Emitted when a new contract is created
     *
     * @param id The ID of the contract
     * @param creator The creator of the contract
     * @param marketId The market the contract was deployed to
     * @param metadataPtr The metadata hash on ipfs
     */
    event ContractCreated(
        uint256 id,
        address indexed creator,
        uint256 indexed marketId,
        string metadataPtr
    );

    /**
     * Emitted when a user's metadata pointer is updated.
     *
     * @param sender The associated address to the metadata
     * @param lensProfileId The lens profile id associated with this address
     * @param metadataPtr The pointer to the metadata
     */
    event UpdateUserMetadata(address sender, uint256 lensProfileId, string metadataPtr);

    event LogCancelArbitration(bytes32 indexed contractID);

    event LogNotifyOfArbitrationRequest(bytes32 indexed contractID, address indexed requester);

    IArbitrator public arbitrator;
    ILensHub public lensHub;
    IProfileCreator public proxyProfileCreator;
    ITokenFactory public _tokenFactory;
    IERC20 public _dai;

    uint16 internal constant BPS_MAX = 10000;
    uint256 _claimedServiceCounter;
    uint256 _protocolFee = 10;

    address public governance;
    address public treasury;
    address[] public verifiedFreelancers;

    NetworkLibrary.Relationship[] public relationships;
    NetworkLibrary.Service[] public services;

    mapping(address => uint256) public addressToLensProfileId;
    mapping(uint256 => uint256) public disputeIDtoRelationshipID;
    mapping(uint256 => NetworkLibrary.Relationship) public relationshipIDToRelationship;
    mapping(uint256 => NetworkLibrary.Service) public serviceIdToService;
    mapping(uint256 => NetworkLibrary.PurchasedServiceMetadata) public purchasedServiceIdToMetdata;
    mapping(uint256 => uint256) public relationshipIDToMarketID;
    mapping(uint256 => uint256) public serviceIDToMarketID;
    mapping(uint256 => uint256) public serviceIdToPublicationId;
    mapping(uint256 => uint256) public serviceIdToPurchaseId;

    modifier onlyWhenOwnership(uint256 contractID, NetworkLibrary.ContractOwnership ownership) {
        _;
    }

    modifier notServiceOwner() {
        _;
    }

    modifier onlyServiceClient() {
        _;
    }

    modifier onlyArbitrator() {
        require(msg.sender == address(arbitrator), 'Only arbitrator');
        _;
    }

    modifier onlyContractEmployer(uint256 contractID) {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractID];
        require(msg.sender == relationship.employer, 'only contract employer');
        _;
    }

    modifier onlyContractWorker(uint256 contractID) {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractID];
        require(msg.sender == relationship.worker, 'only contract worker');
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, 'only governance');
        _;
    }

    /**
     * Initializes the contract.
     */
    function initialize(
        address tokenFactory,
        address _treasury,
        address _arbitrator,
        address _lensHub,
        address _proxyProfileCreator,
        address _governance,
        address dai
    ) external virtual initializer {
        require(tokenFactory != address(0), 'token factory cannot be address0');
        require(_treasury != address(0), 'treasury cannot be address 0');
        require(_arbitrator != address(0), 'arbitrator cannot be address 0');
        require(_lensHub != address(0), 'lens hub cannot be address 0');
        require(_proxyProfileCreator != address(0), 'proxy profile creator');
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
    function register(DataTypes.CreateProfileData calldata vars, string calldata metadata)
        external
    {
        console.log('ONE');
        require(!isRegisteredUser(msg.sender), 'duplicate registration');
        /************ TESTNET ONLY ***************/
        proxyProfileCreator.proxyCreateProfile(vars);
        console.log('TWO');
        bytes memory b;
        b = abi.encodePacked(vars.handle, '.test');
        string memory registeredHandle = string(b);
        /************ END TESTNET ONLY ***************/

        /************ MAINNET ***************/
        // lensHub.createProfile(vars);
        // bytes memory b;
        // b = abi.encodePacked(vars.handle);
        // string memory registeredHandle = string(b);
        // /************ END MAINNET AND LOCAL ONLY ***************/

        uint256 profileId = lensHub.getProfileIdByHandle(registeredHandle);

        addressToLensProfileId[msg.sender] = profileId;
        verifiedFreelancers.push(msg.sender);

        lensHub.setDispatcher(profileId, msg.sender);

        emit UserRegistered(msg.sender, vars.handle, profileId, vars.imageURI, metadata);
    }

    /**
     * Allows any entity to update its own metadata pointer
     * @param metadataPtr The pointer to the entities metadata
     */
    function updateMetadata(string calldata metadataPtr) public {
        emit UpdateUserMetadata(msg.sender, addressToLensProfileId[msg.sender], metadataPtr);
    }

    /**
     * Returns the registration status of the address
     * @param account The address to check
     * @return bool true or false based on the registration status of the address
     */
    function isRegisteredUser(address account) public view returns (bool) {
        return addressToLensProfileId[account] != 0;
    }

    ///////////////////////////////////////////// Service Functions

    /**
     * Creates a service as well as deploys a new service token
     * @param marketId The market id the service belongs to
     * @param metadataPtr The ipfs hash for the metadata storage
     * @param offers The cost of the service
     */
    function createService(
        uint256 marketId,
        string calldata metadataPtr,
        uint256[] calldata offers,
        address lensTalentServiceCollectModule,
        address lensTalentReferenceModule
    ) external returns (uint256) {
        require(
            lensTalentServiceCollectModule != address(0),
            'invalid address for service collect module'
        );
        require(lensTalentReferenceModule != address(0), 'invalid address for reference module.');

        MarketDetails memory marketDetails = _tokenFactory.getMarketDetailsByID(marketId);
        uint256 serviceId = _tokenFactory.addToken(
            marketDetails.name,
            marketDetails.id,
            msg.sender
        );

        //create lens post
        uint256 pubId = lensHub.post(
            DataTypes.PostData({
                profileId: addressToLensProfileId[msg.sender],
                contentURI: metadataPtr,
                collectModule: lensTalentServiceCollectModule,
                collectModuleInitData: abi.encode(offers[0], address(_dai), msg.sender, 0, false),
                referenceModule: lensTalentReferenceModule,
                referenceModuleInitData: abi.encode()
            })
        );

        NetworkLibrary.Service memory newService = NetworkLibrary.Service({
            marketId: marketId,
            creator: msg.sender,
            metadataPtr: metadataPtr,
            offers: offers,
            id: serviceId,
            exist: true,
            collectModule: lensTalentServiceCollectModule,
            referenceModule: lensTalentReferenceModule,
            pubId: pubId
        });

        storeService(newService);
        return serviceId;
    }

    /**
     * Stores a service and emits a service created event
     * @dev Created to prevent stack too deep error
     */
    function storeService(NetworkLibrary.Service memory newService) internal {
        services.push(newService);
        serviceIdToService[newService.id] = newService;
        serviceIDToMarketID[newService.id] = newService.marketId;
        serviceIdToPublicationId[newService.id] = newService.pubId;
        emit ServiceCreated(
            newService.id,
            newService.marketId,
            newService.creator,
            newService.offers,
            newService.metadataPtr,
            newService.pubId
        );
    }

    /**
     * Purchases a service offering
     * @param serviceId The id of the service to purchase
     */
    function purchaseServiceOffering(uint256 serviceId, uint8 offerIndex)
        external
        notServiceOwner
        returns (uint256)
    {
        NetworkLibrary.Service memory service = serviceIdToService[serviceId];

        _claimedServiceCounter++;
        purchasedServiceIdToMetdata[_claimedServiceCounter] = NetworkLibrary
            .PurchasedServiceMetadata({
                exist: true,
                client: msg.sender,
                creator: service.creator,
                timestampPurchased: block.timestamp,
                purchaseId: _claimedServiceCounter,
                offer: 0,
                status: NetworkLibrary.ServiceResolutionStatus.PENDING
            });

        serviceIdToPurchaseId[serviceId] = _claimedServiceCounter;

        _dai.transferFrom(msg.sender, address(this), service.offers[0]);

        emit ServicePurchased(
            serviceId,
            _claimedServiceCounter,
            serviceIdToPublicationId[serviceId],
            service.creator,
            msg.sender,
            0
        );
        return _claimedServiceCounter;
    }

    /**
     * Resolves a service offering
     * @param serviceId The id of the service to resolve
     * @param purchaseId The purchase id of the service
     */
    function resolveService(
        uint256 serviceId,
        uint256 purchaseId,
        DataTypes.EIP712Signature calldata sig
    ) external onlyServiceClient {
        NetworkLibrary.PurchasedServiceMetadata memory metadata = purchasedServiceIdToMetdata[
            purchaseId
        ];
        NetworkLibrary.Service memory service = serviceIdToService[serviceId];

        require(
            metadata.status != NetworkLibrary.ServiceResolutionStatus.RESOLVED,
            'already resolved'
        );
        require(metadata.client == msg.sender, 'only client');
        require(metadata.exist == true, "service doesn't exist");

        bytes memory processCollectData = abi.encode(address(_dai), service.offers[0]);

        DataTypes.CollectWithSigData memory collectWithSigData = DataTypes.CollectWithSigData({
            collector: msg.sender,
            profileId: addressToLensProfileId[service.creator],
            pubId: serviceIdToPublicationId[serviceId],
            data: processCollectData,
            sig: sig
        });

        lensHub.collectWithSig(collectWithSigData);

        metadata.status = NetworkLibrary.ServiceResolutionStatus.RESOLVED;

        emit ServiceResolved(service.creator, msg.sender, purchaseId, serviceId, metadata.offer);
    }


    ///////////////////////////////////////////// Gig Functions

    /**
     * Creates a non service based contract
     * @param marketId The id of the market the contract will be created in
     * @param taskMetadataPtr The ipfs hash where the metadata of the contract is stored
     */
    function createContract(uint256 marketId, string calldata taskMetadataPtr)
        external
        returns (uint256)
    {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[
            relationships.length
        ];
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

        emit ContractCreated(relationshipID, msg.sender, marketId, taskMetadataPtr);
        return relationshipID;
    }

    /**
     * Accepts a proposal for the contract with relationshipId
     * @param contractID The id of the contract
     * @param newWorker The worker to assign the contract to
     * @param wad The agreed upon payout for the contract
     * @notice Calling this function will initialize the escrow funds
     */
    function grantProposalRequest(
        uint256 contractID,
        address newWorker,
        uint256 wad
    )
        external
        onlyWhenOwnership(contractID, NetworkLibrary.ContractOwnership.Unclaimed)
        onlyContractEmployer(contractID)
    {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractID];
        require(newWorker != address(relationship.employer), "Can't work your own contract.");
        require(newWorker != address(0), 'You must grant this proposal to a valid worker.');
        require(relationship.worker == address(0), 'This job is already being worked.');
        require(wad != uint256(0), 'The payout amount must be greater than 0.');

        relationship.wad = wad;
        relationship.worker = newWorker;
        relationship.acceptanceTimestamp = block.timestamp;
        relationship.contractOwnership = NetworkLibrary.ContractOwnership.Claimed;

        _dai.transferFrom(relationship.employer, address(this), relationship.wad);

        emit ContractOwnershipUpdate(
            contractID,
            relationship.marketId,
            NetworkLibrary.ContractOwnership.Claimed,
            relationship.employer,
            newWorker,
            wad
        );
    }

    /**
     * Resolves the contract and transfers escrow funds to the specified worker of the contract
     * @param contractID The id of the contract
     * @param solutionMetadataPtr The ipfs hash storing the solution metadata
     */
    function resolveContract(uint256 contractID, string calldata solutionMetadataPtr)
        external
        onlyWhenOwnership(contractID, NetworkLibrary.ContractOwnership.Claimed)
        onlyContractEmployer(contractID)
    {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractID];

        require(relationship.worker != address(0), 'worker cannot be 0.');
        require(relationship.wad != uint256(0), 'wad cannot be 0');

        _releaseContractFunds(relationship.wad, contractID);
        relationship.contractOwnership = NetworkLibrary.ContractOwnership.Resolved;

        emit ContractOwnershipUpdate(
            contractID,
            relationship.marketId,
            NetworkLibrary.ContractOwnership.Resolved,
            relationship.employer,
            relationship.worker,
            relationship.wad
        );
    }

    /**
     * Allows the worker to release the contract
     * @param contractID The id of the contract
     */
    function releaseContract(uint256 contractID)
        external
        onlyWhenOwnership(contractID, NetworkLibrary.ContractOwnership.Claimed)
        onlyContractWorker(contractID)
    {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractID];
        require(relationship.contractOwnership == NetworkLibrary.ContractOwnership.Claimed);

        _surrenderFunds(contractID);
        resetRelationshipState(contractID, relationship);
    }

    /**
     * Resets the contract state
     * @param contractStruct The contract struct
     */
    function resetRelationshipState(
        uint256 contractID,
        NetworkLibrary.Relationship storage contractStruct
    ) internal {
        contractStruct.worker = address(0);
        contractStruct.acceptanceTimestamp = 0;
        contractStruct.wad = 0;
        contractStruct.contractOwnership = NetworkLibrary.ContractOwnership.Unclaimed;

        emit ContractOwnershipUpdate(
            contractID,
            contractStruct.marketId,
            NetworkLibrary.ContractOwnership.Unclaimed,
            contractStruct.employer,
            address(0),
            contractStruct.wad
        );
    }

    /**
     * Updates a contract's ipfs metadata storage hash
     * @param contractID The id of the contract to update
     * @param newPointerHash The hash of the new pointer
     */
    function updateTaskMetadataPointer(uint256 contractID, string calldata newPointerHash)
        external
        onlyWhenOwnership(contractID, NetworkLibrary.ContractOwnership.Unclaimed)
    {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[contractID];

        require(msg.sender == relationship.employer);
        require(relationship.contractOwnership == NetworkLibrary.ContractOwnership.Unclaimed);

        relationship.taskMetadataPtr = newPointerHash;
    }

    ///////////////////////////////////////////// Kleros

    /// @notice Notify the contract that the arbitrator has been paid for a disputing a contract, freezing it pending their decision.
    /// @dev The arbitrator contract is trusted to only call this if they've been paid, and tell us who paid them.
    /// @dev The arbitrator already checks the status of the contract ownership before making this call
    /// @param contractID The ID of the contract
    /// @param requester The account that requested arbitration
    function notifyOfContractArbitrationRequest(bytes32 contractID, address requester)
        external
        onlyArbitrator
    {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[
            uint256(contractID)
        ];
        relationship.contractOwnership = NetworkLibrary.ContractOwnership.Reclaimed;

        emit LogNotifyOfArbitrationRequest(contractID, requester);
    }

    /// @notice Cancel a previously-requested arbitration and extend the timeout
    /// @dev Useful when doing arbitration across chains that can't be requested atomically
    /// @param contractID The ID of the contract
    function cancelContractArbitration(bytes32 contractID) external onlyArbitrator {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[
            uint256(contractID)
        ];
        require(
            relationship.contractOwnership == NetworkLibrary.ContractOwnership.Reclaimed,
            'Contract must already be in a pending dispute state.'
        );

        relationship.contractOwnership = NetworkLibrary.ContractOwnership.Claimed;
        emit LogCancelArbitration(contractID);
    }


    /// @notice Triggers a dispute status in the network manager
    /// @param contractID The ID of the contract
    function triggerDisputeStatus(bytes32 contractID) external onlyArbitrator {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[
            uint256(contractID)
        ];
        require(
            relationship.contractOwnership == NetworkLibrary.ContractOwnership.Reclaimed,
            'Contract must already be in a pending dispute state.'
        );

        relationship.contractOwnership = NetworkLibrary.ContractOwnership.Disputed;
    }

    /// @notice Resolves the disputed contract
    /// @param contractID The ID of the contract
    /// @param ruling The ruling given at 0 or 1 reflecting the employer or worker.
    function resolveDisputedContract(bytes32 contractID, bytes32 ruling) external onlyArbitrator {
        NetworkLibrary.Relationship storage relationship = relationshipIDToRelationship[
            uint256(contractID)
        ];

        if (uint256(ruling) == uint256(NetworkLibrary.RulingOptions.EmployerWins)) {
            _dai.transfer(relationship.employer, relationship.wad);
        } else if (uint256(ruling) == uint256(NetworkLibrary.RulingOptions.WorkerWins)) {
            _dai.transfer(relationship.worker, relationship.wad);
        } else {
            _dai.transfer(relationship.worker, relationship.wad / 2);
            _dai.transfer(relationship.employer, relationship.wad / 2);
        }

        relationship.contractOwnership = NetworkLibrary.ContractOwnership.Resolved;
    }

    ///////////////////////////////////////////// Escrow

    /**
     * @notice Releases the escrow funds back to the employer.
     * @param contractID The ID of the relationship to surrender the funds.
     */
    function _surrenderFunds(uint256 contractID) internal {
        NetworkLibrary.Relationship memory relationship = relationshipIDToRelationship[contractID];
        _dai.transfer(relationship.employer, relationship.wad);
    }

    /**
     * @notice Releases the escrow funds to the worker.
     * @param _amount The amount to release to the worker
     * @param contractID The ID of the relationship to transfer funds
     */
    function _releaseContractFunds(uint256 _amount, uint256 contractID) internal {
        NetworkLibrary.Relationship memory relationship = relationshipIDToRelationship[contractID];

        uint256 fee = _amount / _protocolFee;
        uint256 payout = _amount - fee;
        _dai.transfer(relationship.worker, payout);
        _dai.transfer(treasury, fee);
    }

    ///////////////////////////////////////////// Setters

    /**
     * Sets the protocol fee
     * @param protocolFee The fee for the protocol
     */
    function setProtocolFee(uint256 protocolFee) external onlyGovernance {
        _protocolFee = protocolFee;
    }

    ///////////////////////////////////////////// Getters

    /**
     * Returns the list of services
     * @return services an array of all services
     */
    function getServices() external view returns (NetworkLibrary.Service[] memory) {
        return services;
    }

    /**
     * Returns the list of contracts
     * @return contracts an array of all contracts
     */
    function getContracts() external view returns (NetworkLibrary.Relationship[] memory) {
        return relationships;
    }

    /**
     * Returns service data based on the specified service id
     * @param serviceId The id of the service
     * @return Service The service to return
     */
    function getServiceData(uint256 serviceId)
        external
        view
        returns (NetworkLibrary.Service memory)
    {
        return serviceIdToService[serviceId];
    }

    /**
     * Returns contract data based on the specified contract id
     * @param contractID The id of the contract
     * @return Contract The contract to return
     */
    function getContractData(uint256 contractID)
        external
        view
        returns (NetworkLibrary.Relationship memory)
    {
        return relationshipIDToRelationship[contractID];
    }

    /**
     * Returns the protocol fee
     * @return uint256 The protocol fee
     */
    function getProtocolFee() external view returns (uint256) {
        return _protocolFee;
    }

    /**
     * Returns the lens protocol profile id for any address
     * @param account The address to query
     * @return uint256 The profile id
     */
    function getLensProfileIdFromAddress(address account) external view returns (uint256) {
        return addressToLensProfileId[account];
    }

    /**
     * Returns the complete list of verified users
     * @return address An array of all verified users
     */
    function getVerifiedFreelancers() external view returns (address[] memory) {
        return verifiedFreelancers;
    }

    /**
     * Returns the purchase metadata for a service
     * @param purchaseId The ID of the purchase
     */
    function getServicePurchaseMetadata(uint256 purchaseId)
        external
        view
        returns (NetworkLibrary.PurchasedServiceMetadata memory)
    {
        return purchasedServiceIdToMetdata[purchaseId];
    }
}
