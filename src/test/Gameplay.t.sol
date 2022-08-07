// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

import "../Storage.sol";
import "../SafariBang.sol";
import "./mocks/LinkToken.sol";
import "./mocks/MockVRFCoordinatorV2.sol";

contract GameplayTest is Test {
    using stdStorage for StdStorage;
    using Strings for address;

    SafariBang private safariBang;

    address Alice = address(1);
    address Bob = address(2);
    address Charlie = address(3);

    uint64 subId;
    uint96 constant FUND_AMOUNT = 1 * 10**18;

    LinkToken linkToken;
    MockVRFCoordinatorV2 vrfCoordinator;

    function setUp() public {
        linkToken = new LinkToken();
        vrfCoordinator = new MockVRFCoordinatorV2();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        safariBang = new SafariBang(
            "SafariBang",
            "SAFABA",
            "https://ipfs.io/ipfs/",
            subId,
            address(vrfCoordinator),
            address(linkToken),
            vrfCoordinator
        );

        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
        vm.deal(Charlie, 100 ether);

        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Bob);
        safariBang.mintTo{value: 0.08 ether}(Charlie);
    }

    /**
    Possible cases:
        a) Empty square: just update position and that's it.
        b) Wild Animal: You need to fight, flee, or fuck. Consequences depend on the action.
        c) Domesicated Animal: You need to fight or fuck (cannot flee). Same consequences as above.
    Edge cases:
        1. move off map, e.g. left from col 0,  should wrap to other side of map(this world is not flat).

     */
    function testMove() public {
        (uint animalId, uint8 row, uint8 col) = safariBang.playerToPosition(Alice);

        // Case 1: Move to Empty Square
        vm.assume(safariBang.safariMap(row - 1, col) == 0);

        SafariBang.Position memory newPosition = safariBang.move(animalId, SafariBangStorage.Direction.Up);

        require(newPosition.row == row - 1 && newPosition.col == col, "Should have moved up one row in the same col");
    }
}