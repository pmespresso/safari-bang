// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "./HelperConfig.sol";
import "../src/SafariBang.sol";

contract SafariBangScript is Script {
    function run() public {
        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            ,
            address link,
            ,
            ,
            uint64 subscriptionId,
            address vrfCoordinator,
            bytes32 keyHash
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();

        SafariBang safariBang = new SafariBang(
            "SafariBang",
            "SAFABA",
            "https://ipfs.io/ipfs/",
            vrfCoordinator,
            link,
            subscriptionId,
            keyHash
        );

        vm.stopBroadcast();
    }
}
