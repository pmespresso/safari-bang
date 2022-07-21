// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/SafariBang.sol";

contract SafariBangScript is Script {
    // function setUp() public {}

    function run() public {
        vm.startBroadcast();

        SafariBang safaribang = new SafariBang("Safari Bang", "SAFABA", "https://ipfs.io/ipfs/");
        
        vm.stopBroadcast();
    }
}
