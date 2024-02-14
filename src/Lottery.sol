// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title Lotttery Smart Contract
 * @author Nadina Oates
 * @notice This contract handles the lottery logic
 * @dev Implements Chainnlink VRFv2
 */
contract Lottery is VRFConsumerBaseV2 {
    /**
     * Types
     */
    enum LotteryState {
        OPEN, // 0
        CALCULATING // 1

    }

    /**
     * Storage Variables
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_entranceFee;

    /// @dev Duration of the lottery in seconds
    uint256 private s_interval;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;

    LotteryState private s_lotteryState;

    /**
     * Events
     */
    event EnteredLottery(address indexed player);
    event SetEntranceFee(uint256 indexed fee);
    event SetInterval(uint256 indexed interval);
    event PickedWinner(address indexed winner);

    /**
     * Errors
     */
    error Lottery__InsufficientFee();
    error Lottery__TransferFailed();
    error Lottery__LotteryNotOpen();

    /**
     * Modifiers
     */

    /// @notice Constructor
    /// @param entranceFee minimum lottery fee
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        s_entranceFee = entranceFee;
        s_interval = interval;

        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lotteryState = LotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    /**
     * external
     * public
     * internal
     * private
     * view/pure last
     */

    /// @notice Enters lottery ticket
    function enterLottery() public payable {
        if (msg.value < s_entranceFee) revert Lottery__InsufficientFee();

        if (s_lotteryState != LotteryState.OPEN) {
            revert Lottery__LotteryNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit EnteredLottery(msg.sender);
    }

    /// @notice Picks a lottery winner
    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < s_interval) {
            revert();
        }

        s_lotteryState = LotteryState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        // effects on own contract
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        // here, wouldn't it possible that someone might enter the lottery before the winner is paid.
        // The next round might then override the current winner?
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = LotteryState.OPEN;

        emit PickedWinner(winner);

        // interactions with other contracts
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__TransferFailed();
        }
    }

    /// @notice Sets entry fee
    function setEntranceFee(uint256 entranceFee) external {
        s_entranceFee = entranceFee;
        emit SetEntranceFee(entranceFee);
    }

    /// @notice Sets lottery interval in seconds
    /// @param interval in seconds of the interval
    function setInterval(uint256 interval) external {
        s_interval = interval;
        emit SetInterval(interval);
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return s_entranceFee;
    }
}
