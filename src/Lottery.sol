// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title Lotttery Smart Contract
 * @author Nadina Oates
 * @notice This contract handles the lottery logic
 * @dev Implements Chainlink VRFv2 and Chainlink Automation
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
    uint256 private s_interval;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;

    LotteryState private s_lotteryState;

    /**
     * Events
     */
    event EnteredLottery(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedLotteryWinner(uint256 indexed requestId);

    /**
     * Errors
     */
    error Lottery__InsufficientFee();
    error Lottery__TransferFailed();
    error Lottery__LotteryNotOpen();
    error Lottery__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 lotteryState, uint256 timestamp);

    /**
     * Modifiers
     */

    /// @notice Constructor
    /// @param entranceFee minimum lottery fee
    /// @param interval lottery round interval in seconds
    /// @param vrfCoordinator Chainlink VRFCoordinator contract to receive true random number
    /// @param gasLane gas lane for chainlink automation
    /// @param subscriptionId subscription id for chainlink automation
    /// @param callbackGasLimit callback gas limlit for chainlink automation
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
    function enterLottery() external payable {
        if (msg.value < s_entranceFee) revert Lottery__InsufficientFee();

        if (s_lotteryState != LotteryState.OPEN) {
            revert Lottery__LotteryNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit EnteredLottery(msg.sender);
    }

    /**
     * @notice Chainlink Automation function
     * @dev This is the function that the Chainlink Automation nodes call to see if
     * it's time to perform an upkeep.
     * The following should be true for this to return true:
     * 1. The time interval has passed between lottery runs
     * 2. The lottery state is OPEN
     * 3. The contract has ETH
     * 4. Has players
     * 5. The subscription is funded with LINK
     */
    function checkUpkeep(bytes memory /* check data */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= s_interval);
        bool isOpen = LotteryState.OPEN == s_lotteryState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    /// @notice Picks a lottery winner
    /// @dev Is triggered by chainlink network
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__UpkeepNotNeeded(
                address(this).balance, s_players.length, uint256(s_lotteryState), block.timestamp
            );
        }
        s_lotteryState = LotteryState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );

        emit RequestedLotteryWinner(requestId);
    }

    /// @notice Callback function for Chainlink VRFConsumer contract to retreive the random number
    /// @param randomWords is an array of random numbers - here length = 1
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] memory randomWords) internal override {
        // draw winner
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = LotteryState.OPEN;

        emit PickedWinner(winner);

        // pay winner
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */

    /// @notice gets minimum entrance fee
    function getEntranceFee() external view returns (uint256) {
        return s_entranceFee;
    }

    /// @notice gets lottery round interval in seconds
    function getInterval() external view returns (uint256) {
        return s_interval;
    }

    /// @notice gets current lottery state
    function getLotteryState() external view returns (LotteryState) {
        return s_lotteryState;
    }

    /// @notice gets player address at index
    /// @param indexOfPlayer is player's index in player array
    function getPlayerAtIndex(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    /// @notice gets number of players
    function getNumberOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    /// @notice gets most recent winner
    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    /// @notice gets timestamp of last draw if any
    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    /// @notice gets Chainlink VRFCoordinator contract address
    function getVrfCoordinator() external view returns (address) {
        return address(i_vrfCoordinator);
    }

    /// @notice gets subscription id for Chainlink Automation
    function getSubscriptionId() external view returns (uint64) {
        return i_subscriptionId;
    }
}
