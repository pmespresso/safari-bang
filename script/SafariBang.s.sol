// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "./HelperConfig.sol";
import "../src/SafariBang.sol";
import "../src/VRFConsumerV2.sol";

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
        VRFConsumerV2 vrfConsumer = new VRFConsumerV2(subscriptionId, vrfCoordinator, link, keyHash);

        SafariBang safariBang = new SafariBang(
            "SafariBang",
            "SAFABA",
            "https://ipfs.io/ipfs/",
            vrfConsumer,
            vrfCoordinator
        );

        vm.stopBroadcast();
    }
}
