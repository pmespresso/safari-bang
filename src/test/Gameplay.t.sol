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
    address Daisy = address(4);

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
        vm.deal(Daisy, 100 ether);

        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Bob);
        safariBang.mintTo{value: 0.08 ether}(Charlie);
        safariBang.mintTo{value: 0.08 ether}(Daisy);
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
        vm.startPrank(Alice);

        (uint animalId, uint8 row, uint8 col) = safariBang.playerToPosition(Alice);

        // Case 1: Go Up
        vm.assume(safariBang.safariMap(row - 1, col) == 0);

        SafariBang.Position memory aliceNewPosition = safariBang.move(SafariBangStorage.Direction.Up);

        require(aliceNewPosition.row == row - 1 && aliceNewPosition.col == col, "Alice should have moved down up square");

        vm.stopPrank();

        vm.startPrank(Bob);

        // Case 2: Go left
        (uint bobAnimalId, uint8 bobRow, uint8 bobCol) = safariBang.playerToPosition(Bob);

        SafariBang.Position memory bobNewPosition = safariBang.move(SafariBangStorage.Direction.Left);

        console.log("Bob New Row: ", bobNewPosition.row);
        console.log("Bob New Col: ", bobNewPosition.col);

        require(bobNewPosition.row == bobRow && bobNewPosition.col == bobCol - 1, "Bob should have moved left 1 square");

        vm.stopPrank();

        // Case 3: Go Right
        vm.startPrank(Charlie);
        (uint charlieAnimalId, uint8 charlieRow, uint8 charlieCol) = safariBang.playerToPosition(Charlie);

        SafariBang.Position memory charlieNewPosition = safariBang.move(SafariBangStorage.Direction.Right);
        
        require(charlieNewPosition.row == charlieRow && charlieNewPosition.col == charlieCol + 1, "Charlie should have moved right 1 square");
        vm.stopPrank();

        // Case 4: Go Down
        vm.startPrank(Daisy);
        (uint daisyAnimalId, uint8 daisyRow, uint8 daisyCol) = safariBang.playerToPosition(Daisy);

        SafariBang.Position memory daisyNewPosition = safariBang.move(SafariBangStorage.Direction.Down);
        
        require(daisyNewPosition.row == daisyRow + 1 && daisyNewPosition.col == daisyCol, "Daisy should have moved down 1 square");
        // Case 5: Out of Moves
        vm.expectRevert(bytes("You are out of moves"));
        safariBang.move(SafariBangStorage.Direction.Down);

        // Case 6: Wrap around the map


        vm.stopPrank();
    }


    function testFuck() public {
        vm.startPrank(Alice);

        (uint aliceAnimalId, uint8 aliceRow, uint8 aliceCol) = safariBang.playerToPosition(Alice);
        (uint bobAnimalId, uint8 bobRow, uint8 bobCol) = safariBang.playerToPosition(Bob);
        (SafariBang.AnimalType aliceAnimalType, 
            SafariBang.Specie aliceAnimalSpecies,
            uint256 _aliceAnimalId, 
            uint256 aliceAnimalSize,
            uint256 aliceAnimalStrength,
            uint256 aliceAnimalSpeed,
            uint256 aliceAnimalFertility,
            uint256 aliceAnimalAnxiety,
            uint256 aliceAnimalAggression,
            uint256 aliceAnimalLibido,
            bool aliceAnimalGender,
            SafariBang.Position memory alicePosition,
            address aliceOwner) = safariBang.idToAnimal(aliceAnimalId);
        (SafariBang.AnimalType bobAnimalType, 
            SafariBang.Specie bobAnimalSpecies,
            uint256 _bobAnimalId, 
            uint256 bobAnimalSize,
            uint256 bobAnimalStrength,
            uint256 bobAnimalSpeed,
            uint256 bobAnimalFertility,
            uint256 bobAnimalAnxiety,
            uint256 bobAnimalAggression,
            uint256 bobAnimalLibido,
            bool bobAnimalGender,
            SafariBang.Position memory bobPosition,
            address bobOwner) = safariBang.idToAnimal(bobAnimalId);

        // put bob next to alice
        safariBang.godModePlacement(Bob, bobAnimalId, alicePosition.row - 1, alicePosition.col);

        console.log("God Placement: ", bobPosition.row, bobPosition.col);

        // give Alice's animal insane libido and Bob's animal insane fertility
        aliceAnimalLibido = 100;
        bobAnimalFertility = 100;
        safariBang.godModeAttributes(
            aliceAnimalId,
            aliceAnimalFertility,
            aliceAnimalLibido,
            aliceAnimalGender
        );
        safariBang.godModeAttributes(
            bobAnimalId,
            bobAnimalFertility,
            bobAnimalLibido,
            bobAnimalGender);

        console.log("God Attributes Alice: ", aliceAnimalLibido, aliceAnimalFertility);
        console.log("God Attributes Bob: ", bobAnimalLibido, bobAnimalFertility);

        SafariBangStorage.Position memory newAlicePosition = safariBang.fuck(SafariBangStorage.Direction.Down);

        console.log("Alice new position: ", newAlicePosition.row, newAlicePosition.col);
    }
}