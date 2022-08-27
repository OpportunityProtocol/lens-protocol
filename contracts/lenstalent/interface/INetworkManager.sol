// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../libraries/DataTypes.sol";

/**
 * @title INetworkManager
 *
 * NetworkManager Interface
 */
interface INetworkManager {
    function initialize(
        address tokenFactory,
        address _treasury,
        address _arbitrator,
        address _lensHub,
        address _proxyProfileCreator,
        address _governance,
        address dai
    ) external;

    function register(DataTypes.CreateProfileData calldata vars, string calldata metadata) external;

    function updateMetadata(string calldata metadataPtr) public;

    function isRegisteredUser(address account) public view returns (bool);

    function createService(
        uint256 marketId,
        string calldata metadataPtr,
        uint256[] calldata offers,
        address lensTalentServiceCollectModule,
        address lensTalentReferenceModule
    ) public returns (uint256);

    function storeService(NetworkLibrary.Service memory newService) internal;

    function purchaseServiceOffering(uint256 serviceId, uint8 offerIndex) public returns (uint256);

    function resolveService(
        uint256 serviceId,
        uint256 purchaseId,
        DataTypes.EIP712Signature calldata sig
    ) public;

    function isFamiliarWithService(address employer, uint256 serviceId) external returns (bool);

    function createContract(uint256 marketId, string calldata taskMetadataPtr)
        external
        returns (uint256);

    function grantProposalRequest(
        uint256 contractId,
        address newWorker,
        uint256 wad
    ) external;

    function resolveContract(uint256 contractId, string calldata solutionMetadataPtr) external;

    function releaseContract(uint256 contractId) external;

    function resetRelationshipState(
        uint256 contractId,
        NetworkLibrary.Relationship storage contractStruct
    ) internal;

    function updateTaskMetadataPointer(uint256 contractId, string calldata newPointerHash) external;

    function disputeService(uint256 serviceId) external payable;

    function disputeRelationship(uint256 contractId) external payable;

    function depositArbitrationFeeForPayee(uint256 contractId) external payable;

    function submitEvidence(uint256 contractId, string memory _evidence) public;

    function remainingTimeToDepositArbitrationFee(uint256 contractId)
        external
        view
        returns (uint256);

    function _initializeEscrowFundsAndTransfer(uint256 contractId) internal;

    function _surrenderFunds(uint256 contractId) internal;

    function _releaseContractFunds(uint256 _amount, uint256 contractId) internal;

    function setProtocolFee(uint256 protocolFee) external;

    function getServices() public view returns (NetworkLibrary.Service[] memory);

    function getContracts() public view returns (NetworkLibrary.Relationship[] memory);

    function getServiceData(uint256 serviceId) public view returns (NetworkLibrary.Service memory);

    function getContractData(uint256 contractId)
        public
        view
        returns (NetworkLibrary.Relationship memory);

    function getProtocolFee() external view returns (uint256);

    function getLensProfileIdFromAddress(address account) public view returns (uint256);

    function getPubIdFromServiceId(uint256 serviceId) public view returns (uint256);

    function getPurchaseIdFromServiceId(uint256 serviceId) public view returns (uint256);

    function getVerifiedFreelancers() public view returns (address[] memory);

    function getServicePurchaseMetadata(uint256 purchaseId)
        public
        view
        returns (NetworkLibrary.PurchasedServiceMetadata memory);
}
