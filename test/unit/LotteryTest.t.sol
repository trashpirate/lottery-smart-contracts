// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract LotteryTest is Test {
    Lottery lottery;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    /* Events */
    event EnteredLottery(address indexed player);
    event SetEntranceFee(uint256 indexed fee);
    event SetInterval(uint256 indexed interval);
    event PickedWinner(address indexed winner);

    function setUp() external {
        DeployLottery deployer = new DeployLottery();
        (lottery, helperConfig) = deployer.run();

        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit) =
            helperConfig.activeNetworkConfig();

        deal(PLAYER, STARTING_USER_BALANCE);
    }

    function test__InitializesInOpenState() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }

    //////////////////////////////
    // enter Lottery            //
    //////////////////////////////

    function test__RecordsPlayer() public {
        vm.prank(PLAYER);

        lottery.enterLottery{value: entranceFee}();

        address playerRecorded = lottery.getPlayerAtIndex(0);
        assert(playerRecorded == PLAYER);
    }

    function test__RevertsWhen__InsufficientFee() public {
        vm.prank(PLAYER);

        vm.expectRevert(Lottery.Lottery__InsufficientFee.selector);
        lottery.enterLottery();
    }

    function test__RevertsWhen__EnterLotteryWhenCalculating() public {
        vm.prank(PLAYER);

        vm.expectRevert(Lottery.Lottery__InsufficientFee.selector);
        lottery.enterLottery();
    }

    function test__EmitsEvent__EnterLottery() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        lottery.performUpkeep("");

        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
    }
}
