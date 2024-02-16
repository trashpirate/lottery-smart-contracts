// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    Lottery lottery;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    /* Events */
    event EnteredLottery(address indexed player);
    event PickedWinner(address indexed winner);

    /* Modifiers */
    modifier lotteryEntered() {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        _;
    }

    modifier timePassed() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
            _;
        }
    }

    function setUp() external {
        DeployLottery deployer = new DeployLottery();
        (lottery, helperConfig) = deployer.run();

        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, link,) =
            helperConfig.activeNetworkConfig();

        deal(PLAYER, STARTING_USER_BALANCE);
    }

    //////////////////////////////
    // initialization           //
    //////////////////////////////

    function test__initialization() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
        assert(lottery.getEntranceFee() == entranceFee);
        assert(lottery.getInterval() == interval);
        assert(lottery.getLastTimestamp() == block.timestamp);
        assert(lottery.getNumberOfPlayers() == 0);
        assert(lottery.getRecentWinner() == address(0));
        assert(lottery.getVrfCoordinator() != address(0));
        assert(lottery.getSubscriptionId() != 0);

        (uint96 balance, uint64 reqCount, address owner, address[] memory consumers) =
            VRFCoordinatorV2Mock(vrfCoordinator).getSubscription(lottery.getSubscriptionId());

        assert(consumers[0] == address(lottery));
    }

    //////////////////////////////
    // getter functions         //
    //////////////////////////////

    function test__getsRecentWinner() public lotteryEntered timePassed skipFork {
        vm.recordLogs();
        lottery.performUpkeep(""); // emits request id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(lottery));

        assertEq(lottery.getRecentWinner(), PLAYER);
    }

    function test__getsNumberOfPlayers() public lotteryEntered timePassed {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (uint256 index = startingIndex; index <= additionalEntrants; index++) {
            address player = address(uint160(index));
            hoax(player, STARTING_USER_BALANCE);
            lottery.enterLottery{value: entranceFee}();
        }

        assertEq(lottery.getNumberOfPlayers(), 6);
    }
    //////////////////////////////
    // enter Lottery            //
    //////////////////////////////

    function test__recordsPlayer() public lotteryEntered {
        address playerRecorded = lottery.getPlayerAtIndex(0);
        assert(playerRecorded == PLAYER);
    }

    function test__revertsWhen__insufficientFee() public {
        vm.prank(PLAYER);

        vm.expectRevert(Lottery.Lottery__InsufficientFee.selector);
        lottery.enterLottery();
    }

    function test__revertsWhen__enterLotteryWhenCalculating() public lotteryEntered timePassed {
        lottery.performUpkeep("");

        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);

        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
    }

    function test__emitsEvent__EnterLottery() public {
        vm.expectEmit(true, false, false, false);
        emit EnteredLottery(PLAYER);

        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
    }

    //////////////////////////////
    // checkUpkeep              //
    //////////////////////////////

    function test__checkUpkeepReturnsFalseIfNoBalance() public timePassed {
        (bool upkeepNeeded,) = lottery.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function test__checkUpkeepReturnsFalseIfLotteryNotOpen() public lotteryEntered timePassed {
        lottery.performUpkeep("");

        (bool upkeepNeeded,) = lottery.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function test__checkUpkeepReturnsFalseIfTimeHasNotExpired() public lotteryEntered {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval / 2);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = lottery.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function test__checkUpkeepReturnsTrueIfAllParametersPass() public lotteryEntered timePassed {
        (bool upkeepNeeded,) = lottery.checkUpkeep("");

        assert(upkeepNeeded);
    }

    //////////////////////////////
    // performUpkeep            //
    //////////////////////////////

    function test__performUpkeepRunsIfCheckUpkeepTrue() public lotteryEntered timePassed {
        lottery.performUpkeep("");
    }

    function test__revertsWhen__checkUpkeepFalse() public timePassed {
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__UpkeepNotNeeded.selector, 0, 0, 0, block.timestamp));
        lottery.performUpkeep("");
    }

    function test__emitsEvent__performUpkeepUpdatesState() public lotteryEntered timePassed {
        vm.recordLogs();
        lottery.performUpkeep(""); // emits request id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Lottery.LotteryState lotteryState = lottery.getLotteryState();

        assert(uint256(requestId) > 0);
        assert(lotteryState == Lottery.LotteryState.CALCULATING);
    }

    //////////////////////////////
    // fulfillRandomWords       //
    //////////////////////////////

    function test__emitsEvent__fulfillRandomWords() public lotteryEntered timePassed {
        vm.recordLogs();
        lottery.performUpkeep(""); // emits request id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        vm.expectEmit(true, false, false, false);
        emit PickedWinner(PLAYER);

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(lottery));
    }

    function test__fulfillRandomWordsPicksWinnerAndResets() public lotteryEntered timePassed skipFork {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (uint256 index = startingIndex; index <= additionalEntrants; index++) {
            address player = address(uint160(index));
            hoax(player, STARTING_USER_BALANCE);
            lottery.enterLottery{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        lottery.performUpkeep(""); // emits request id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = lottery.getLastTimestamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(lottery));

        assertEq(uint256(lottery.getLotteryState()), 0);
        assertNotEq(lottery.getRecentWinner(), address(0));
        assertEq(lottery.getNumberOfPlayers(), 0);
        assertGt(lottery.getLastTimestamp(), previousTimeStamp);
        assertEq(lottery.getRecentWinner().balance, prize + STARTING_USER_BALANCE - entranceFee);
    }

    function test__revertsWhen__fulfillRandomWordsCalledBeforePerformUpkeep(uint256 randomRequestId)
        public
        lotteryEntered
        timePassed
        skipFork
    {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(lottery));
    }

    function test__revertsWhen__fulfillRandomWordsTransferFails() public lotteryEntered timePassed {
        vm.recordLogs();
        lottery.performUpkeep(""); // emits request id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        vm.mockCallRevert(PLAYER, entranceFee, "", abi.encode("TRANSFER_FAILED"));
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(lottery));
        assertEq(lottery.getRecentWinner(), address(0));
    }
}
