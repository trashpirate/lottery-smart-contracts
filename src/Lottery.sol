// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/interfaces/vrf/VRFCoordinatorV2Interface.sol";

/**
 * @title Lotttery Smart Contract
 * @author Nadina Oates
 * @notice This contract handles the lottery logic
 * @dev Implements Chainnlink VRFv2
 */
contract Lottery {
    /**
     * Types
     */

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

    /**
     * Events
     */
    event EnteredLottery(address indexed player);
    event SetEntranceFee(uint256 indexed fee);
    event SetInterval(uint256 indexed interval);

    /**
     * Errors
     */
    error Lottery__InsufficientFee();

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
    ) {
        s_entranceFee = entranceFee;
        s_interval = interval;
        s_lastTimeStamp = block.timestamp;

        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
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
        s_players.push(payable(msg.sender));

        emit EnteredLottery(msg.sender);
    }

    /// @notice Picks a lottery winner
    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < s_interval) {
            revert();
        }
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );
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
