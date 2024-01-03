// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title Lotttery Smart Contract
 * @author Nadina Oates
 * @notice This contract handles the lottery logic
 * @dev Impolments Chainnlink VRFv2
 */
contract Lottery {
    /**
     * Errors
     */
    error Lottery__InsufficientFee();

    /**
     * Types
     */
    /**
     * Storage Variables
     */
    uint256 private s_entranceFee;

    /**
     * Events
     */

    /// @notice Constructor
    /// @param entranceFee minimum lottery fee
    constructor(uint256 entranceFee) {
        s_entranceFee = entranceFee;
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
    }

    function pickWinner() public {}

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return s_entranceFee;
    }
}
