// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IDisputeResolver, IArbitrator} from '@kleros/dispute-resolver-interface-contract/contracts/IDisputeResolver.sol';
import {CappedMath} from '../libraries/CappedMath.sol';
import {FxBaseRootTunnel} from '../util//FxBaseRootTunnel.sol';
import {IForeignArbitrationProxy, IHomeArbitrationProxy} from '../interface/ArbitrationProxyInterfaces.sol';
import '../libraries/NetworkLibrary.sol';

/**
 * @title Arbitration proxy for Realitio on Ethereum side (A.K.A. the Foreign Chain).
 * @dev This contract is meant to be deployed to the Ethereum chains where Kleros is deployed.
 */
contract NetworkManagerForeignArbitrationProxy is
    IForeignArbitrationProxy,
    IDisputeResolver,
    FxBaseRootTunnel
{
    using CappedMath for uint256;

    /* Constants */
    // The number of choices for the arbitrator.
    uint256 public constant NUMBER_OF_CHOICES_FOR_ARBITRATOR = 3; //type(uint256).max;
    uint256 public constant REFUSE_TO_ARBITRATE = type(uint256).max; // Constant that represents "Refuse to rule" in realitio format.
    uint256 public constant MULTIPLIER_DIVISOR = 10000; // Divisor parameter for multipliers.
    uint256 public constant META_EVIDENCE_ID = 0; // The ID of the MetaEvidence for disputes.

    /* Storage */

    enum Status {
        None,
        Requested,
        Created,
        Ruled,
        Failed
    }

    struct ArbitrationRequest {
        Status status; // Status of the arbitration.
        uint248 deposit; // The deposit paid by the requester at the time of the arbitration.
        uint256 disputeID; // The ID of the dispute in arbitrator contract.
        uint256 answer; // The answer given by the arbitrator.
    }

    struct DisputeDetails {
        uint256 arbitrationID; // The ID of the arbitration.
        address requester; // The address of the requester who managed to go through with the arbitration request.
    }

    IArbitrator public immutable arbitrator; // The address of the arbitrator. TRUSTED.
    bytes public arbitratorExtraData; // The extra data used to raise a dispute in the arbitrator.

    string public termsOfService; // The path for the Terms of Service for Kleros as an arbitrator for Realitio.

    mapping(uint256 => mapping(address => ArbitrationRequest)) public arbitrationRequests; // Maps arbitration ID to its data. arbitrationRequests[uint(questionID)][requester].
    mapping(uint256 => DisputeDetails) public disputeIDToDisputeDetails; // Maps external dispute ids to local arbitration ID and requester who was able to complete the arbitration request.
    mapping(uint256 => bool) public arbitrationIDToDisputeExists; // Whether a dispute has already been created for the given arbitration ID or not.
    mapping(uint256 => address) public arbitrationIDToRequester; // Maps arbitration ID to the requester who was able to complete the arbitration request.
    mapping(uint256 => uint256) public disputeIDtoRelationshipID;

    /**
     * @dev This is applied to functions called via the internal function
     * `_processMessageFromChild` which is invoked via the Polygon bridge (see FxBaseRootTunnel)
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
     * @notice Creates an arbitration proxy on the foreign chain.
     * @param _checkpointManager For Polygon FX-portal bridge.
     * @param _fxRoot Address of the FxRoot contract of the Polygon bridge.
     * @param _arbitrator Arbitrator contract address.
     * @param _arbitratorExtraData The extra data used to raise a dispute in the arbitrator.
     * @param _metaEvidence The URI of the meta evidence file.
     * @param _termsOfService The path for the Terms of Service for Kleros as an arbitrator for Realitio.
     */
    constructor(
        address _checkpointManager,
        address _fxRoot,
        IArbitrator _arbitrator,
        bytes memory _arbitratorExtraData,
        string memory _metaEvidence,
        string memory _termsOfService
    ) FxBaseRootTunnel(_checkpointManager, _fxRoot) {
        arbitrator = _arbitrator;
        arbitratorExtraData = _arbitratorExtraData;
        termsOfService = _termsOfService;

        emit MetaEvidence(META_EVIDENCE_ID, _metaEvidence);
    }

    /**
     * @notice Requests arbitration for the current state of a contract
     * @param contractID The ID of the contract
     */
    function requestContractArbitration(bytes32 contractID) external payable override {
        //require(!arbitrationIDToDisputeExists[uint256(contractID)], "Dispute already created");

        ArbitrationRequest storage arbitration = arbitrationRequests[uint256(contractID)][
            msg.sender
        ];
        require(arbitration.status == Status.None, 'Arbitration already requested');

        uint256 arbitrationCost = arbitrator.arbitrationCost(arbitratorExtraData);
        require(msg.value >= arbitrationCost, 'Deposit value too low');

        arbitration.status = Status.Requested;
        arbitration.deposit = uint248(msg.value);

        bytes4 methodSelector = IHomeArbitrationProxy.receiveContractArbitrationRequest.selector;
        bytes memory data = abi.encodeWithSelector(methodSelector, contractID, msg.sender);
        _sendMessageToChild(data);

        emit ArbitrationRequested(contractID, msg.sender);
    }

    /**
     * @notice Receives the acknowledgement of the arbitration request for the given contract and requester. TRUSTED.
     * @param contractID The ID of the contract.
     * @param requester The requester.
     */
    function receiveContractArbitrationAcknowledgement(bytes32 contractID, address requester)
        external
        override
        onlyBridge
    {
        uint256 arbitrationID = uint256(contractID);
        ArbitrationRequest storage arbitration = arbitrationRequests[arbitrationID][requester];
        require(arbitration.status == Status.Requested, 'Invalid arbitration status');

        uint256 arbitrationCost = arbitrator.arbitrationCost(arbitratorExtraData);

        if (arbitration.deposit >= arbitrationCost) {
            try
                arbitrator.createDispute{value: arbitrationCost}(
                    NUMBER_OF_CHOICES_FOR_ARBITRATOR,
                    arbitratorExtraData
                )
            returns (uint256 disputeID) {
                DisputeDetails storage disputeDetails = disputeIDToDisputeDetails[disputeID];
                disputeDetails.arbitrationID = arbitrationID;
                disputeDetails.requester = requester;

                arbitrationIDToDisputeExists[arbitrationID] = true;
                arbitrationIDToRequester[arbitrationID] = requester;
                disputeIDtoRelationshipID[disputeID] = arbitrationID;

                // At this point, arbitration.deposit is guaranteed to be greater than or equal to the arbitration cost.
                uint256 remainder = arbitration.deposit - arbitrationCost;

                arbitration.status = Status.Created;
                arbitration.deposit = 0;
                arbitration.disputeID = disputeID;

                if (remainder > 0) {
                    payable(requester).send(remainder);
                }

                bytes4 methodSelector = IHomeArbitrationProxy.receiveDisputeAccepted.selector;
                bytes memory data = abi.encodeWithSelector(methodSelector, contractID);
                _sendMessageToChild(data);

                emit ArbitrationCreated(contractID, requester, disputeID);
                emit Dispute(arbitrator, disputeID, META_EVIDENCE_ID, arbitrationID);
            } catch {
                arbitration.status = Status.Failed;
                emit ArbitrationFailed(contractID, requester);
            }
        } else {
            arbitration.status = Status.Failed;
            emit ArbitrationFailed(contractID, requester);
        }
    }

    /**
     * @notice Rules a specified dispute. Can only be called by the arbitrator.
     * @dev Accounts for the situation where the winner loses a case due to paying less appeal fees than expected.
     * @param disputeID The ID of the dispute in the ERC792 arbitrator.
     * @param ruling The ruling given by the arbitrator.
     */
    function rule(uint256 disputeID, uint256 ruling) external override {
        uint256 contractId = disputeIDtoRelationshipID[disputeID];
        DisputeDetails storage disputeDetails = disputeIDToDisputeDetails[disputeID];
        ArbitrationRequest storage arbitration = arbitrationRequests[disputeDetails.arbitrationID][
            disputeDetails.requester
        ];

        //only the arbitrator can rule
        if (msg.sender != address(arbitrator)) {
            revert NetworkLibrary.NotArbitrator();
        }

        //invalid option
        if (ruling > NUMBER_OF_CHOICES_FOR_ARBITRATOR) {
            revert NetworkLibrary.InvalidRuling(ruling, NUMBER_OF_CHOICES_FOR_ARBITRATOR);
        }

        require(arbitration.status == Status.Created, 'Invalid arbitration status');

        arbitration.answer = ruling;
        arbitration.status = Status.Ruled;

        bytes4 methodSelector = IHomeArbitrationProxy.receiveContractArbitrationAnswer.selector;
        bytes memory data = abi.encodeWithSelector(
            methodSelector,
            bytes32(disputeDetails.arbitrationID),
            bytes32(ruling)
        );
        _sendMessageToChild(data);

        emit Ruling(arbitrator, disputeID, ruling);
    }

    /**
     * @notice Receives the cancelation of the arbitration request for the given question and requester. TRUSTED.
     * @param contractID The ID of the question.
     * @param requester The requester.
     */
    function receiveContractArbitrationCancelation(bytes32 contractID, address requester)
        external
        override
        onlyBridge
    {
        uint256 arbitrationID = uint256(contractID);
        ArbitrationRequest storage arbitration = arbitrationRequests[arbitrationID][requester];
        require(arbitration.status == Status.Requested, 'Invalid arbitration status');
        uint256 deposit = arbitration.deposit;

        delete arbitrationRequests[arbitrationID][requester];
        payable(requester).send(deposit);

        emit ArbitrationCanceled(contractID, requester);
    }
    
    function handleContractFailedArbitrationNotification(bytes32 contractID, address requester) external override {
        uint256 arbitrationID = uint256(contractID);
        ArbitrationRequest storage arbitration = arbitrationRequests[arbitrationID][requester];
        arbitration.status = Status.Failed;
    }

    /**
     * @notice Cancels the arbitration in case the dispute could not be created.
     * @param contractID The ID of the question.
     * @param requester The address of the arbitration requester.
     */
    function handleContractFailedDisputeCreation(bytes32 contractID, address requester)
        external
        override
    {
        uint256 arbitrationID = uint256(contractID);
        ArbitrationRequest storage arbitration = arbitrationRequests[arbitrationID][requester];
        require(arbitration.status == Status.Failed, 'Invalid arbitration status');
        uint256 deposit = arbitration.deposit;

        delete arbitrationRequests[arbitrationID][requester];
        payable(requester).send(deposit);

        bytes4 methodSelector = IHomeArbitrationProxy.receiveContractArbitrationFailure.selector;
        bytes memory data = abi.encodeWithSelector(methodSelector, contractID, requester);
        _sendMessageToChild(data);

        emit ArbitrationCanceled(contractID, requester);
    }

    // ********************************* //
    // *    Appeals and arbitration    * //
    // ********************************* //

    /**
     * @notice Takes up to the total amount required to fund an answer. Reimburses the rest. Creates an appeal if at least two answers are funded.
     * @param _arbitrationID The ID of the arbitration, which is questionID cast into uint256.
     * @param _answer One of the possible rulings the arbitrator can give that the funder considers to be the correct answer to the question.
     * Note that the answer has Kleros denomination, meaning that it has '+1' offset compared to Realitio format.
     * Also note that '0' answer can be funded.
     * @return Whether the answer was fully funded or not.
     */
    function fundAppeal(uint256 _arbitrationID, uint256 _answer) external payable override returns (bool) {
        return false;
    }

    /**
     * @notice Sends the fee stake rewards and reimbursements proportional to the contributions made to the winner of a dispute. Reimburses contributions if there is no winner.
     * @param _arbitrationID The ID of the arbitration.
     * @param _beneficiary The address to send reward to.
     * @param _round The round from which to withdraw.
     * @param _answer The answer to query the reward from.
     * @return reward The withdrawn amount.
     */
    function withdrawFeesAndRewards(
        uint256 _arbitrationID,
        address payable _beneficiary,
        uint256 _round,
        uint256 _answer
    ) public override returns (uint256 reward) {
        return 0;
    }

    /**
     * @notice Allows to withdraw any rewards or reimbursable fees for all rounds at once.
     * @dev This function is O(n) where n is the total number of rounds. Arbitration cost of subsequent rounds is `A(n) = 2A(n-1) + 1`.
     *      So because of this exponential growth of costs, you can assume n is less than 10 at all times.
     * @param _arbitrationID The ID of the arbitration.
     * @param _beneficiary The address that made contributions.
     * @param _contributedTo Answer that received contributions from contributor.
     */
    function withdrawFeesAndRewardsForAllRounds(
        uint256 _arbitrationID,
        address payable _beneficiary,
        uint256 _contributedTo
    ) external override {}

    /**
     * @notice Allows to submit evidence for a particular contract.
     * @param arbitrationID The ID of the arbitration related to the contract.
     * @param evidenceURI Link to evidence.
     */
    function submitEvidence(uint256 arbitrationID, string calldata evidenceURI) external override {
        emit Evidence(arbitrator, arbitrationID, msg.sender, evidenceURI);
    }

    /* External Views */

    /**
     * @notice Returns stake multipliers.
     * @return winner Winners stake multiplier.
     * @return loser Losers stake multiplier.
     * @return loserAppealPeriod Multiplier for calculating an appeal period duration for the losing side.
     * @return divisor Multiplier divisor.
     */
    function getMultipliers()
        external
        view
        override
        returns (
            uint256 winner,
            uint256 loser,
            uint256 loserAppealPeriod,
            uint256 divisor
        )
    {
        return (0, 0, 0, 0);
    }

    /**
     * @notice Returns number of possible ruling options. Valid rulings are [0, return value].
     * @return count The number of ruling options.
     */
    function numberOfRulingOptions(uint256 _arbitrationID) external pure override returns (uint256) {
        return NUMBER_OF_CHOICES_FOR_ARBITRATOR;
    }

    /**
     * @notice Gets the fee to create a dispute.
     * @return The fee to create a dispute.
     */
    function getDisputeFee(bytes32) external view returns (uint256) {
        return arbitrator.arbitrationCost(arbitratorExtraData);
    }

    /**
     * @notice Gets the number of rounds of the specific question.
     * @param _arbitrationID The ID of the arbitration related to the question.
     * @return The number of rounds.
     */
    function getNumberOfRounds(uint256 _arbitrationID) external view returns (uint256) {
        return 1;
    }

    /**
     * @notice Gets the information of a round of a question.
     * @param _arbitrationID The ID of the arbitration.
     * @param _round The round to query.
     * @return paidFees The amount of fees paid for each fully funded answer.
     * @return feeRewards The amount of fees that will be used as rewards.
     * @return fundedAnswers IDs of fully funded answers.
     */
    function getRoundInfo(uint256 _arbitrationID, uint256 _round)
        external
        view
        returns (
            uint256[] memory paidFees,
            uint256 feeRewards,
            uint256[] memory fundedAnswers
        )
    {
        uint256[] memory paidFeesOut;
        uint256[] memory fundedAnswersOut;
        return (paidFeesOut,0,fundedAnswersOut);
    }

    /**
     * @notice Gets the information of a round of a question for a specific answer choice.
     * @param _arbitrationID The ID of the arbitration.
     * @param _round The round to query.
     * @param _answer The answer choice to get funding status for.
     * @return raised The amount paid for this answer.
     * @return fullyFunded Whether the answer is fully funded or not.
     */
    function getFundingStatus(
        uint256 _arbitrationID,
        uint256 _round,
        uint256 _answer
    ) external view returns (uint256 raised, bool fullyFunded) {
        return (0, false);
    }

    /**
     * @notice Gets contributions to the answers that are fully funded.
     * @param _arbitrationID The ID of the arbitration.
     * @param _round The round to query.
     * @param _contributor The address whose contributions to query.
     * @return fundedAnswers IDs of the answers that are fully funded.
     * @return contributions The amount contributed to each funded answer by the contributor.
     */
    function getContributionsToSuccessfulFundings(
        uint256 _arbitrationID,
        uint256 _round,
        address _contributor
    ) external view returns (uint256[] memory fundedAnswers, uint256[] memory contributions) {
        uint256[] memory fundedAnswers;
        uint256[] memory contributions;
        return (fundedAnswers, contributions);
    }

    /**
     * @notice Returns the sum of withdrawable amount.
     * @dev This function is O(n) where n is the total number of rounds.
     * @dev This could exceed the gas limit, therefore this function should be used only as a utility and not be relied upon by other contracts.
     * @param _arbitrationID The ID of the arbitration.
     * @param _beneficiary The contributor for which to query.
     * @param _contributedTo Answer that received contributions from contributor.
     * @return sum The total amount available to withdraw.
     */
    function getTotalWithdrawableAmount(
        uint256 _arbitrationID,
        address payable _beneficiary,
        uint256 _contributedTo
    ) external view override returns (uint256 sum) {
        return 0;
    }

    /**
     * @notice Casts question ID into uint256 thus returning the related arbitration ID.
     * @param contractID The ID of the question.
     * @return The ID of the arbitration.
     */
    function contractIDToArbitrationID(bytes32 contractID) external pure returns (uint256) {
        return uint256(contractID);
    }

    /**
     * @notice Maps external (arbitrator side) dispute id to local (arbitrable) dispute id.
     * @param _externalDisputeID Dispute id as in arbitrator side.
     * @return localDisputeID Dispute id as in arbitrable contract.
     */
    function externalIDtoLocalID(uint256 _externalDisputeID) external view override returns (uint256) {
        return disputeIDToDisputeDetails[_externalDisputeID].arbitrationID;
    }


    function _processMessageFromChild(bytes memory _data) internal override {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(this).call(_data);
        require(success, "Failed to call contract");
    }
}
