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
    address Emily = address(5);

    uint64 subId;
    uint96 constant FUND_AMOUNT = 1 * 10**18;

    LinkToken linkToken;
    MockVRFCoordinatorV2 vrfCoordinator;

    function setUp() public {
        bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
        linkToken = new LinkToken();
        vrfCoordinator = new MockVRFCoordinatorV2();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);
        VRFConsumerV2 vrfConsumer = new VRFConsumerV2(subId, address(vrfCoordinator), address(linkToken), keyHash);

        safariBang = new SafariBang(
            "SafariBang",
            "SAFABA",
            "https://ipfs.io/ipfs/",
            vrfConsumer,
            address(vrfCoordinator)
        );

        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
        vm.deal(Charlie, 100 ether);
        vm.deal(Daisy, 100 ether);
        vm.deal(Emily, 100 ether);

        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Bob);
        safariBang.mintTo{value: 0.08 ether}(Charlie);
        safariBang.mintTo{value: 0.08 ether}(Daisy);
        safariBang.mintTo{value: 0.08 ether}(Emily);

        require(address(safariBang).balance >= 0.5 ether, "safari bang should have collected Ether from mints");
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

        SafariBang.Position memory aliceNewPosition = safariBang.move(SafariBangStorage.Direction.Up, 1);

        require(aliceNewPosition.row == row - 1 && aliceNewPosition.col == col, "Alice should have moved down up square");

        vm.stopPrank();

        vm.startPrank(Bob);

        // Case 2: Go left
        (uint bobAnimalId, uint8 bobRow, uint8 bobCol) = safariBang.playerToPosition(Bob);

        SafariBang.Position memory bobNewPosition = safariBang.move(SafariBangStorage.Direction.Left, 1);

        console.log("Bob New Row: ", bobNewPosition.row);
        console.log("Bob New Col: ", bobNewPosition.col);

        require(bobNewPosition.row == bobRow && bobNewPosition.col == bobCol - 1, "Bob should have moved left 1 square");

        vm.stopPrank();

        // Case 3: Go Right
        vm.startPrank(Charlie);
        (uint charlieAnimalId, uint8 charlieRow, uint8 charlieCol) = safariBang.playerToPosition(Charlie);

        SafariBang.Position memory charlieNewPosition = safariBang.move(SafariBangStorage.Direction.Right, 1);
        
        require(charlieNewPosition.row == charlieRow && charlieNewPosition.col == charlieCol + 1, "Charlie should have moved right 1 square");
        vm.stopPrank();

        // Case 4: Go Down
        vm.startPrank(Daisy);
        (uint daisyAnimalId, uint8 daisyRow, uint8 daisyCol) = safariBang.playerToPosition(Daisy);

        SafariBang.Position memory daisyNewPosition = safariBang.move(SafariBangStorage.Direction.Down, 1);
        
        require(daisyNewPosition.row == daisyRow + 1 && daisyNewPosition.col == daisyCol, "Daisy should have moved down 1 square");
        // Case 5: Out of Moves
        vm.expectRevert(bytes("You are out of moves"));
        safariBang.move(SafariBangStorage.Direction.Down, 1);

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


        SafariBangStorage.Position memory newAlicePosition = safariBang.fuck(SafariBangStorage.Direction.Up);

        console.log("Alice new position: ", newAlicePosition.row, newAlicePosition.col);
        require(safariBang.balanceOf(Bob) == 0, "Bob's animal should be burned.");

        (uint bobNewAnimalId, uint8 bobNewRow, uint8 bobNewCol) = safariBang.playerToPosition(Bob);

        require(bobNewRow == 0 && bobNewCol == 0 && bobNewAnimalId == 0, "Bob should not be on the map at all anymore after getting fucked with only one animal in the quiver.");
        require(newAlicePosition.row == bobRow && newAlicePosition.col == bobCol, "Alice should have moved into Bob's old cell.");
        require(safariBang.movesRemaining(Alice) == 3, "Alice should have used 1 move to do this whole thing");
        require(safariBang.balanceOf(Alice) == aliceBalanceBefore + 1, "Alice should have a brand new baby animal in her quiver.");
    }

    /**
    @dev Fight as a defense mechanism
            Pseudocode below:

        | 0 | 0 | B | 0 |
        | 0 | 0 | A | 0 |
        | C | D | 0 | 0 |
        
        A.Quiver = [1, 2, 3]
        B.Quiver = [4]
        C.Quiver = [5]
        D.Quiver = [6]

        C.Fight -> D
        burn(D.Quiver[0]) // if C wins fight

        | 0 | 0 | A | 0 |
        | 0 | 0 | 0 | 0 |
        | 0 | C | 0 | 0 |

        C.Quiver = [5]
        D.Quiver = []
    */
    function testFight() public {

        (uint charlieAnimalId, uint8 charlieRow, uint8 charlieCol) = safariBang.playerToPosition(Charlie);
        (uint daisyAnimalId, uint8 daisyRow, uint8 daisyCol) = safariBang.playerToPosition(Daisy);

        // console.log("Daisy pos: ", daisyRow, daisyCol);

        uint charlieBalanceBefore = safariBang.balanceOf(Charlie);
        uint daisyBalanceBefore = safariBang.balanceOf(Daisy);

        console.log("charlieBalanceBefore: ", charlieBalanceBefore);
        console.log("daisyBalanceBefore: ", daisyBalanceBefore);

        (SafariBang.AnimalType charlieAnimalType, 
            SafariBang.Specie charlieAnimalSpecies,
            uint256 _charlieAnimalId, 
            uint256 charlieAnimalSize,
            uint256 charlieAnimalStrength,
            uint256 charlieAnimalSpeed,
            uint256 charlieAnimalFertility,
            uint256 charlieAnimalAnxiety,
            uint256 charlieAnimalAggression,
            uint256 charlieAnimalLibido,
            bool charlieAnimalGender,
            address charlieOwner) = safariBang.idToAnimal(charlieAnimalId);
        (SafariBang.AnimalType daisyAnimalType, 
            SafariBang.Specie daisyAnimalSpecies,
            uint256 _daisyAnimalId, 
            uint256 daisyAnimalSize,
            uint256 daisyAnimalStrength,
            uint256 daisyAnimalSpeed,
            uint256 daisyAnimalFertility,
            uint256 daisyAnimalAnxiety,
            uint256 daisyAnimalAggression,
            uint256 daisyAnimalLibido,
            bool daisyAnimalGender,
            address daisyOwner) = safariBang.idToAnimal(daisyAnimalId);

        // put daisy next to charlie
        safariBang.godModePlacement(Daisy, 6, charlieRow, charlieCol + 1);
        
        (uint daisyAnimalIdNew, uint8 daisyRowNew, uint8 daisyColNew) = safariBang.playerToPosition(Daisy);
        
        console.log("Charlie pos: ", charlieRow, charlieCol);
        console.log("Daisy God Mode Placed: ", daisyRowNew, daisyColNew);
        
        vm.startPrank(Charlie);

        SafariBangStorage.Position memory newCharliePosition = safariBang.fight(SafariBangStorage.Direction.Right);

        uint charlieBalanceAfter = safariBang.balanceOf(Charlie);

        require(charlieBalanceAfter == charlieBalanceBefore, "Winning a fight should not change your balance.");
    }

    
    /**
    @dev Flee as a defense mechanism
            Pseudocode below:

        B.Pos = [10, 10]
        | 0 | 0 | 0 | 0 | 0 |
        | 0 | 0 | A | 0 | 0 |
        | 0 | D | B | E | 0 |
        | 0 | 0 | C | 0 | 0 |
        | 0 | 0 | 0 | 0 | 0 |

        B.Flee

        B.Pos = [10, 13]
        | 0 | 0 | 0 | 0 | 0 | 0 |
        | 0 | 0 | A | 0 | 0 | 0 |
        | 0 | D | 0 | E | 0 | B |
        | 0 | 0 | C | 0 | 0 | 0 |
        | 0 | 0 | 0 | 0 | 0 | 0 |

        
    */
    function testFlee() public {
        // place all of them adjacent to Bob in the middle
        safariBang.godModePlacement(Alice, 1, 10, 10);
        safariBang.godModePlacement(Bob, 4, 11, 10);
        safariBang.godModePlacement(Charlie, 5, 12, 10);
        safariBang.godModePlacement(Daisy, 6, 10, 9);
        safariBang.godModePlacement(Emily, 7, 10, 11);

        (uint _bobId, uint8 bobRow, uint8 bobCol) = safariBang.playerToPosition(Bob);

        console.log("bob current pos: ", bobRow, bobCol);

        // make Bob flee
        vm.startPrank(Bob);
        safariBang.flee();

        // expect Bob to be 3 squares from previous
        (uint bobId, uint8 bobNewRow, uint8 bobNewCol) = safariBang.playerToPosition(Bob);

        console.log("bob new pos: ", bobNewRow, bobNewCol);

        require(safariBang.movesRemaining(Bob) == 0, "Bob should be out of moves.");

        // if fleer moved at all
        if (bobRow != bobNewRow) {
            require(bobNewRow > bobRow ? bobNewRow - bobRow == 3 : bobRow - bobNewRow == 3, "Bob should have moved 3 cells.");
        } else if(bobCol != bobNewCol) {
            require(bobNewCol > bobCol ? bobNewCol - bobCol == 3 : bobCol - bobNewCol == 3, "Bob should have moved 3 cells.");
        } else {
            require(bobNewRow == bobRow && bobNewCol == bobCol, "Bob failed to flee, should stay in place.");
        }
    }
    
}