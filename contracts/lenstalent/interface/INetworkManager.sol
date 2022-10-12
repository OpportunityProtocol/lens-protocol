// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '../../libraries/DataTypes.sol';
import '../libraries/NetworkLibrary.sol';

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

    function updateMetadata(string calldata metadataPtr) external;

    function createService(
        uint256 marketId,
        string calldata metadataPtr,
        uint256[] calldata offers,
        address lensTalentServiceCollectModule,
        address lensTalentReferenceModule
    ) external returns (uint256);

    function purchaseServiceOffering(uint256 serviceId, uint8 offerIndex)
        external
        returns (uint256);

    function resolveService(
        uint256 serviceId,
        uint256 purchaseId,
        DataTypes.EIP712Signature calldata sig
    ) external;

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

    function updateTaskMetadataPointer(uint256 contractId, string calldata newPointerHash) external;


    function setProtocolFee(uint256 protocolFee) external;

    function getServices() external view returns (NetworkLibrary.Service[] memory);

    function getContracts() external view returns (NetworkLibrary.Relationship[] memory);

    function getServiceData(uint256 serviceId)
        external
        view
        returns (NetworkLibrary.Service memory);

    function getContractData(uint256 contractId)
        external
        view
        returns (NetworkLibrary.Relationship memory);

    function getProtocolFee() external view returns (uint256);

    function getLensProfileIdFromAddress(address account) external view returns (uint256);

    function getVerifiedFreelancers() external view returns (address[] memory);

    function getServicePurchaseMetadata(uint256 purchaseId)
        external
        view
        returns (NetworkLibrary.PurchasedServiceMetadata memory);

    function notifyOfContractArbitrationRequest(bytes32 contractID, address requester) external;

    function triggerDisputeStatus(bytes32 contractID) external;

    function cancelContractArbitration(bytes32 contractID) external;

    function resolveDisputedContract(bytes32 contractID, bytes32 ruling) external;
}
