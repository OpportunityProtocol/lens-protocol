// SPDX-License-Identifier: MIT

/**
 *  @authors: [@hbarcelos, @shalzz]
 *  @reviewers: [@ferittuncer*, @fnanni-0*, @nix1g*, @epiqueras*, @clesaege*, @unknownunknown1]
 *  @auditors: []
 *  @bounties: []
 *  @deployments: []
 */

pragma solidity ^0.8.0;

import {FxBaseChildTunnel} from '../util/FxBaseChildTunnel.sol';
import '../interface/INetworkManager.sol';
import {IForeignArbitrationProxy, IHomeArbitrationProxy} from '../interface/ArbitrationProxyInterfaces.sol';

/**
 * @title Arbitration proxy for Realitio on the side-chain side (A.K.A. the Home Chain).
 * @dev This contract is meant to be deployed to side-chains in which Reality.eth is deployed.
 */
contract NetworkManagerHomeArbitrationProxy is IHomeArbitrationProxy, FxBaseChildTunnel {
    INetworkManager public immutable _networkManager;

    enum Status {
        None,
        Rejected,
        Notified,
        AwaitingRuling,
        Ruled,
        Finished
    }

    struct Request {
        Status status;
        bytes32 arbitratorAnswer;
    }

    /// @dev Associates an arbitration request with a question ID and a requester address. requests[questionID][requester]
    mapping(bytes32 => mapping(address => Request)) public requests;

    /// @dev Associates a contract ID with the requester who succeeded in requesting arbitration. contractIDToRequester[contractID]
    mapping(bytes32 => address) public contractIDToRequester;

    /**
     * @dev This is applied to functions called via the internal function
     * `_processMessageFromRoot` which is invoked via the Polygon bridge (see FxBaseChildTunnel)
     *
     * The functions requiring this modifier cannot simply be declared internal as
     * we still need the ABI generated of these functions to be able to call them
     * across contracts and have the compiler type check the function signatures.
     */
    modifier onlyBridge() {
        require(msg.sender == address(this), 'Can only be called via bridge');
        _;
    }

    /**
     * @notice Creates an arbitration proxy on the home chain.
     * @param fxChild Address of the FxChild contract of the Polygon bridge
     * @param networkManager NetworkManager contract address.
     */
    constructor(address fxChild, INetworkManager networkManager) FxBaseChildTunnel(fxChild) {
        _networkManager = networkManager;
    }

    /**
     * @dev Receives the requested arbitration for a contract TRUSTED.
     * @param contractID The ID of the question.
     * @param requester The address of the user that requested arbitration.
     */
    function receiveContractArbitrationRequest(bytes32 contractID, address requester)
        external
        override
        onlyBridge
    {
        Request storage request = requests[contractID][requester];
        require(request.status != Status.None, 'Request already exists');

        NetworkLibrary.Relationship memory relationship = _networkManager.getContractData(
            uint256(contractID)
        );
        if (
            requester != relationship.worker ||
            requester != relationship.employer ||
            relationship.contractOwnership != NetworkLibrary.ContractOwnership.Claimed
        ) {
            emit RequestRejected(contractID, requester, 'Unable to request this arbitration.');
            return;
        }

        try _networkManager.notifyOfContractArbitrationRequest(contractID, requester) {
            request.status = Status.Notified;
            contractIDToRequester[contractID] = requester;

            //send receive to root
            handleNotifiedRequest(contractID, requester);

            emit RequestNotified(contractID, requester);
        } catch Error(string memory reason) {

            //send failure to root
             handleNotifiedFailure(contractID, requester);

            emit RequestRejected(contractID, requester, reason);
        } catch {
            // In case `reject` did not have a reason string or some other error happened
             handleNotifiedFailure(contractID, requester);

            emit RequestRejected(contractID, requester, '');
        }
    }

    /**
     * @notice Handles arbitration request after it has been notified to Lens Talent for a given contract.
     * @dev This method exists because `receiveContractArbitrationRequest` is called by the Polygon Bridge
     * and cannot send messages back to it.
     * @param contractID The ID of the question.
     * @param requester The address of the user that requested arbitration.
     */
    function handleNotifiedRequest(bytes32 contractID, address requester) internal {
        Request storage request = requests[contractID][requester];
        //require(request.status == Status.Notified, 'Invalid request status');

        request.status = Status.AwaitingRuling;

        bytes4 selector = IForeignArbitrationProxy
            .receiveContractArbitrationAcknowledgement
            .selector;
        bytes memory data = abi.encodeWithSelector(selector, contractID, requester);
        _sendMessageToRoot(data);

        emit RequestAcknowledged(contractID, requester);
    }

    function handleNotifiedFailure(bytes32 contractID, address requester) internal {
        Request storage request = requests[contractID][requester];
       // require(request.status == Status.Notified, 'Invalid request status');

        request.status = Status.Rejected;

        bytes4 selector = IForeignArbitrationProxy
            .handleContractFailedArbitrationNotification
            .selector;
        bytes memory data = abi.encodeWithSelector(selector, contractID, requester);
        _sendMessageToRoot(data);

       // emit RequestAcknowledged(contractID, requester);
    }

    /**
     * @notice Handles arbitration request after it has been rejected.
     * @dev This method exists because `receiveArbitrationRequest` is called by the Polygon Bridge
     * and cannot send messages back to it.
     * Reasons why the request might be rejected:
     *  - The question does not exist
     *  - The question was not answered yet
     *  - The quesiton bond value changed while the arbitration was being requested
     *  - Another request was already accepted
     * @param contractID The ID of the question.
     * @param requester The address of the user that requested arbitration.
     */
    function handleRejectedRequest(bytes32 contractID, address requester) internal {
        Request storage request = requests[contractID][requester];
        require(request.status == Status.Rejected, 'Invalid request status');

        // At this point, only the request.status is set, simply reseting the status to Status.None is enough.
        request.status = Status.None;

        bytes4 selector = IForeignArbitrationProxy.receiveContractArbitrationCancelation.selector;
        bytes memory data = abi.encodeWithSelector(selector, contractID, requester);
        _sendMessageToRoot(data);

        emit RequestCanceled(contractID, requester);
    }

    /**
     */
    function receiveDisputeAccepted(bytes32 contractID) external onlyBridge {
        _networkManager.triggerDisputeStatus(contractID);
    }

    /**
     * @notice Receives a failed attempt to request arbitration. TRUSTED.
     * @dev Currently this can happen only if the arbitration cost increased.
     * @param contractID The ID of the question.
     * @param requester The address of the user that requested arbitration.
     */
    function receiveContractArbitrationFailure(bytes32 contractID, address requester)
        external
        override
        onlyBridge
    {
        Request storage request = requests[contractID][requester];
        require(request.status == Status.AwaitingRuling, 'Invalid request status');

        // At this point, only the request.status is set, simply reseting the status to Status.None is enough.
        request.status = Status.None;

        _networkManager.cancelContractArbitration(contractID);

        emit ArbitrationFailed(contractID, requester);
    }

    /**
     * @notice Receives the a. TRUSTED.
     * @param contractID The ID of the question.
     * @param ruling The answer from the arbitrator.
     */
    function receiveContractArbitrationAnswer(bytes32 contractID, bytes32 ruling)
        external
        override
        onlyBridge
    {
        address requester = contractIDToRequester[contractID];
        Request storage request = requests[contractID][requester];
        require(request.status == Status.AwaitingRuling, 'Invalid request status');

        request.status = Status.Ruled;
        request.arbitratorAnswer = ruling;

        _networkManager.resolveDisputedContract(contractID, ruling);

        emit ArbitratorAnswered(contractID, ruling);
    }

    function _processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes memory _data
    ) internal override validateSender(sender) {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(this).call(_data);
        require(success, 'Failed to call contract');
    }
}
