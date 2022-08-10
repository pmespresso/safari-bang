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
        // vm.deal(address(safariBang), 100 ether);

        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Bob);
        safariBang.mintTo{value: 0.08 ether}(Charlie);
        safariBang.mintTo{value: 0.08 ether}(Daisy);

        console.log("SafariBang balance: ", address(safariBang).balance);

        require(address(safariBang).balance == 0.48 ether, "safari bang should have collected Ether from mints");
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


    /**
        @dev Fuck as a defense mechanism
                Pseudocode below:

            | 0 | 0 | B | 0 |
            | 0 | 0 | A | 0 |
            | C | D | 0 | 0 |
            
            A.Quiver = [1, 2, 3]
            B.Quiver = [4]
            C.Quiver = [5]
            D.Quiver = [6]

            A.Fuck -> B
            burn(B.Quiver[0])
            mintTo(A)

            | 0 | 0 | A | 0 |
            | 0 | 0 | 0 | 0 |
            | C | D | 0 | 0 |

            A.Quiver = [1, 2, 3, 7]
            B.Quiver = []
    */
    function testFuck() public {
        vm.startPrank(Alice);

        (uint aliceAnimalId, uint8 aliceRow, uint8 aliceCol) = safariBang.playerToPosition(Alice);

        uint aliceBalanceBefore = safariBang.balanceOf(Alice);

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
            address bobOwner) = safariBang.idToAnimal(4);

        // put bob next to alice
        safariBang.godModePlacement(Bob, 4, aliceRow - 1, aliceCol);

        (uint bobAnimalId, uint8 bobRow, uint8 bobCol) = safariBang.playerToPosition(Bob);
        
        // console.log("Placement of Alice: ", aliceRow, aliceCol);
        // console.log("God Placement of Bob: ", bobRow, bobCol);

        // give Alice's animal insane libido and Bob's animal insane fertility, make sure alice is female and bob is male
        aliceAnimalLibido = 100;
        bobAnimalFertility = 100;
        aliceAnimalGender = true;
        bobAnimalGender = false;
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
            bobAnimalGender
        );

        // console.log("God Attributes Alice: ", aliceAnimalLibido, aliceAnimalFertility, aliceAnimalGender);
        // console.log("God Attributes Bob: ", bobAnimalLibido, bobAnimalFertility, bobAnimalGender);

        SafariBangStorage.Position memory newAlicePosition = safariBang.fuck(SafariBangStorage.Direction.Up);

        console.log("Alice new position: ", newAlicePosition.row, newAlicePosition.col);
        require(safariBang.balanceOf(Bob) == 0, "Bob's animal should be burned.");

        (uint bobNewAnimalId, uint8 bobNewRow, uint8 bobNewCol) = safariBang.playerToPosition(Bob);

        require(bobNewRow == 0 && bobNewCol == 0 && bobNewAnimalId == 0, "Bob should not be on the map at all anymore after getting fucked with only one animal in the quiver.");
        require(newAlicePosition.row == bobRow && newAlicePosition.col == bobCol, "Alice should have moved into Bob's old cell.");
        require(safariBang.movesRemaining(Alice) == 3, "Alice should have used 1 move to do this whole thing");
        require(safariBang.balanceOf(Alice) == aliceBalanceBefore + 1, "Alice should have a brand new baby animal in her quiver.");
    }
}