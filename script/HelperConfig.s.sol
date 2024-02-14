// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";

import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    // chain configurations
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    constructor() {
        if (block.chainid == 56) {
            activeNetworkConfig = getBinanceMainnetConfig();
        } else if (block.chainid == 97) {
            activeNetworkConfig = getBinanceTestnetConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getBinanceTestnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f,
            gasLane: 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314,
            subscriptionId: 3386,
            callbackGasLimit: 500000,
            link: 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06
        });
    }

    function getBinanceMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0xc587d9053cd1118f25F645F9E08BB98c9712A4EE,
            gasLane: 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: 0x404460C6A5EdE2D891e8297795264fDe62ADBB75
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether; // 0.25 LINK
        uint96 gasPriceLink = 1e9; // 1 gwei LINK

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
        vm.stopBroadcast();

        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04,
            subscriptionId: 0,
            callbackGasLimit: 500000
        });
    }
}
