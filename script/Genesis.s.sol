// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
// import "../broadcast/SafariBang.s.sol/run-latest.json";

interface ISafariBang {
    function mapGenesis(uint) external;
}

contract Genesis is Script {
    function run() public {
        ISafariBang safariBang = ISafariBang(0x2b02De252B0FcF30e9473856268dD73323118450);

        vm.startBroadcast();

        safariBang.mapGenesis(10);

        vm.stopBroadcast();
    }
}