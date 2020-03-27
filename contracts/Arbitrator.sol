pragma solidity >=0.5.16;

import { Ownable } from "@openzeppelin/contracts/ownership/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IRealitio } from './IRealitio.sol';

contract Arbitrator is Ownable {

    IRealitio public realitio;

    mapping(bytes32 => uint256) public arbitration_bounties;

    uint256 disputeFee;
    mapping(bytes32 => uint256) customDisputeFees;

    string public metadata;

    event LogRequestArbitration(
        bytes32 indexed questionId,
        uint256 feePaid,
        address requester,
        uint256 remaining
    );

    event LogSetRealitio(
        address realitio
    );

    event LogSetQuestionFee(
        uint256 fee
    );


    event LogSetDisputeFee(
        uint256 fee
    );

    event LogSetCustomDisputeFee(
        bytes32 indexed questionId,
        uint256 fee
    );

    /// @notice Returns the IRealitio contract address - deprecated in favour of realitio()
    function realitycheck() external view returns (IRealitio) {
        return realitio;
    }

    /// @notice Set the Reality Check contract address
    /// @param addr The address of the Reality Check contract
    function setRealitio(address addr)
        external
        onlyOwner
    {
        realitio = IRealitio(addr);
        emit LogSetRealitio(addr);
    }

    /// @notice Set the default fee
    /// @param fee The default fee amount
    function setDisputeFee(uint256 fee)
        external
        onlyOwner
    {
        disputeFee = fee;
        emit LogSetDisputeFee(fee);
    }

    /// @notice Set a custom fee for this particular question
    /// @param questionId The question in question
    /// @param fee The fee amount
    function setCustomDisputeFee(bytes32 questionId, uint256 fee)
        external
        onlyOwner
    {
        customDisputeFees[questionId] = fee;
        emit LogSetCustomDisputeFee(questionId, fee);
    }

    /// @notice Return the dispute fee for the specified question. 0 indicates that we won't arbitrate it.
    /// @param questionId The question in question
    /// @dev Uses a general default, but can be over-ridden on a question-by-question basis.
    function getDisputeFee(bytes32 questionId)
        public
        view
        returns (uint256)
    {
        return (customDisputeFees[questionId] > 0) ? customDisputeFees[questionId] : disputeFee;
    }

    /// @notice Set a fee for asking a question with us as the arbitrator
    /// @param fee The fee amount
    /// @dev Default is no fee. Unlike the dispute fee, 0 is an acceptable setting.
    /// You could set an impossibly high fee if you want to prevent us being used as arbitrator unless we submit the question.
    /// (Submitting the question ourselves is not implemented here.)
    /// This fee can be used as a revenue source, an anti-spam measure, or both.
    function setQuestionFee(uint256 fee)
        external
        onlyOwner
    {
        realitio.setQuestionFee(fee);
        emit LogSetQuestionFee(fee);
    }

    /// @notice Submit the arbitrator's answer to a question.
    /// @param questionId The question in question
    /// @param answer The answer
    /// @param answerer The answerer. If arbitration changed the answer, it should be the payer. If not, the old answerer.
    function submitAnswerByArbitrator(bytes32 questionId, bytes32 answer, address answerer)
        external
        onlyOwner
    {
        delete arbitration_bounties[questionId];
        realitio.submitAnswerByArbitrator(questionId, answer, answerer);
    }

    /// @notice Request arbitration, freezing the question until we send submitAnswerByArbitrator
    /// @dev The bounty can be paid only in part, in which case the last person to pay will be considered the payer
    /// Will trigger an error if the notification fails, eg because the question has already been finalized
    /// @param questionId The question in question
    /// @param maxPrevious If specified, reverts if a bond higher than this was submitted after you sent your transaction.
    function requestArbitration(bytes32 questionId, uint256 maxPrevious)
        external
        payable
        returns (bool)
    {
        uint256 arbitrationFee = getDisputeFee(questionId);
        require(arbitrationFee > 0, "The arbitrator must have set a non-zero fee for the question");

        arbitration_bounties[questionId] += msg.value;
        uint256 paid = arbitration_bounties[questionId];

        if (paid >= arbitrationFee) {
            realitio.notifyOfArbitrationRequest(questionId, msg.sender, maxPrevious);
            emit LogRequestArbitration(questionId, msg.value, msg.sender, 0);
            return true;
        } else {
            require(!realitio.isFinalized(questionId), "The question must not have been finalized");
            emit LogRequestArbitration(questionId, msg.value, msg.sender, arbitrationFee - paid);
            return false;
        }
    }

    /// @notice Withdraw any accumulated ETH fees to the specified address
    /// @param recipient The address to which the balance should be sent
    function withdraw(address payable recipient)
        external
        onlyOwner
    {
        recipient.transfer(address(this).balance);
    }

    /// @notice Withdraw any accumulated token fees to the specified address
    /// @param recipient The address to which the balance should be sent
    /// @dev Only needed if the IRealitio contract used is using an ERC20 token
    /// @dev Also only normally useful if a per-question fee is set, otherwise we only have ETH.
    function withdrawERC20(IERC20 token, address recipient)
        external
        onlyOwner
    {
        require(
            IERC20(token).transfer(recipient, token.balanceOf(address(this))),
            "withdrawing ERC-20 failed"
        );
    }

    function () external payable {}

    /// @notice Withdraw any accumulated question fees from the specified address into this contract
    /// @dev Funds can then be liberated from this contract with our withdraw() function
    /// @dev This works in the same way whether the realitio contract is using ETH or an ERC20 token
    function callWithdraw()
        external
        onlyOwner
    {
        realitio.withdraw();
    }

    /// @notice Set a metadata string, expected to be JSON, containing things like arbitrator TOS address
    function setMetaData(string calldata _metadata)
        external
        onlyOwner
    {
        metadata = _metadata;
    }
}
