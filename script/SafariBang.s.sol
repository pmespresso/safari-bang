// SPDX-License-Identifier: CC0
pragma solidity 0.8.16;

import "forge-std/Script.sol";

import "./HelperConfig.sol";
import "../src/SafariBang.sol";

contract DeploySafariBang is Script {
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
