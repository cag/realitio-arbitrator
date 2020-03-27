pragma solidity >=0.5.16;

interface IRealitio {
    /// @notice Set a fee for asking a question with us as the arbitrator
    /// @dev Default is no fee. Unlike the dispute fee, 0 is an acceptable setting.
    /// You could set an impossibly high fee if you want to prevent us being used as arbitrator unless we submit the question.
    /// (Submitting the question ourselves is not implemented here.)
    /// This fee can be used as a revenue source, an anti-spam measure, or both.
    /// @param fee The fee amount
    function setQuestionFee(uint256 fee) external;

    /// @notice Notify the contract that the arbitrator has been paid for a question, freezing it pending their decision.
    /// @dev The arbitrator contract is trusted to only call this if they've been paid, and tell us who paid them.
    /// @param questionId The ID of the question
    /// @param requester The account that requested arbitration
    /// @param maxPrevious If specified, reverts if a bond higher than this was submitted after you sent your transaction.
    function notifyOfArbitrationRequest(
        bytes32 questionId,
        address requester,
        uint256 maxPrevious
    ) external;

    /// @notice Submit the answer for a question, for use by the arbitrator.
    /// @dev Doesn't require (or allow) a bond.
    /// If the current final answer is correct, the account should be whoever submitted it.
    /// If the current final answer is wrong, the account should be whoever paid for arbitration.
    /// However, the answerer stipulations are not enforced by the contract.
    /// @param questionId The ID of the question
    /// @param answer The answer, encoded into bytes32
    /// @param answerer The account credited with this answer for the purpose of bond claims
    function submitAnswerByArbitrator(
        bytes32 questionId,
        bytes32 answer,
        address answerer
    ) external;

    /// @notice Report whether the answer to the specified question is finalized
    /// @param questionId The ID of the question
    /// @return Return true if finalized
    function isFinalized(bytes32 questionId) external view returns (bool);

    function withdraw() external;
}
