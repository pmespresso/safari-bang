// SPDX-License-Identifier: CC0
pragma solidity 0.8.16;

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
        // VRFConsumerV2 vrfConsumer = new VRFConsumerV2(subId, address(vrfCoordinator), address(linkToken), keyHash);

        safariBang = new SafariBang(
            "SafariBang",
            "SAFABA",
            "https://ipfs.io/ipfs/",
            address(vrfCoordinator),
            address(linkToken),
            subId,
            keyHash
        );
        vrfCoordinator.addConsumer(subId, address(safariBang));

        safariBang.getRandomWords();
        vrfCoordinator.fulfillRandomWords(safariBang.s_requestId(), address(safariBang));

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

    function testPickRandPlayer() public {
        vm.startPrank(Alice);

        uint256 slotA = stdstore
            .target(address(safariBang))
            .sig("whosTurnNext()")
            .find();
        
        vm.store(address(safariBang), bytes32(slotA), bytes32(abi.encode(Alice)));

        address whosNextBefore = safariBang.whosTurnNext();
        address[] memory allPlayers = safariBang.getAllPlayers();

        console.log("whosNextBefore: ", whosNextBefore);

        safariBang.randPickNextPlayer();

        address whosNextAfter = safariBang.whosTurnNext();
        console.log("whosNextAfter: ", whosNextAfter);

        require(whosNextBefore != whosNextAfter, "whosNext should have changed.");

        vm.stopPrank();

        vm.startPrank(whosNextAfter);

        safariBang.randPickNextPlayer();

        address whosNextAfterAfter = safariBang.whosTurnNext();

        require(whosNextBefore != whosNextAfter && whosNextBefore != whosNextAfterAfter, "whosNext should not repeat.");
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
        safariBang.randPickNextPlayer();
        address whosNext = safariBang.whosTurnNext();
        vm.startPrank(whosNext);

        (uint animalId, uint8 row, uint8 col) = safariBang.playerToPosition(whosNext);

        // Case 1: Go Up
        vm.assume(safariBang.safariMap(row - 1, col) == 0);

        SafariBang.Position memory whosNextNewPosition = safariBang.move(SafariBangStorage.Direction.Up, 1);

        require(whosNextNewPosition.row == row - 1 && whosNextNewPosition.col == col, "whosNext should have moved down up square");
        require(safariBang.isPendingAction(whosNext) == false, "Whos Next should not be pending action after move.");

        safariBang.randPickNextPlayer();
        vm.stopPrank();

        whosNext = safariBang.whosTurnNext();
        vm.startPrank(whosNext);

        // Case 2: Go left
        (uint whosNextAnimalId, uint8 whosNextRow, uint8 whosNextCol) = safariBang.playerToPosition(whosNext);

        whosNextNewPosition = safariBang.move(SafariBangStorage.Direction.Left, 1);

        console.log("whosNext New Row: ", whosNextNewPosition.row);
        console.log("whosNext New Col: ", whosNextNewPosition.col);

        require(whosNextNewPosition.row == whosNextRow && whosNextNewPosition.col == whosNextCol - 1, "whosNext should have moved left 1 square");

        vm.stopPrank();

        // // Case 3: Go Right
        // vm.startPrank(Charlie);
        // (uint charlieAnimalId, uint8 charlieRow, uint8 charlieCol) = safariBang.playerToPosition(Charlie);

        // SafariBang.Position memory charlieNewPosition = safariBang.move(SafariBangStorage.Direction.Right, 1);
        
        // require(charlieNewPosition.row == charlieRow && charlieNewPosition.col == charlieCol + 1, "Charlie should have moved right 1 square");
        // vm.stopPrank();

        // // Case 4: Go Down
        // vm.startPrank(Daisy);
        // (uint daisyAnimalId, uint8 daisyRow, uint8 daisyCol) = safariBang.playerToPosition(Daisy);

        // SafariBang.Position memory daisyNewPosition = safariBang.move(SafariBangStorage.Direction.Down, 1);
        
        // require(daisyNewPosition.row == daisyRow + 1 && daisyNewPosition.col == daisyCol, "Daisy should have moved down 1 square");
        // // Case 5: Out of Moves
        // vm.expectRevert(bytes("You are out of moves"));
        // safariBang.move(SafariBangStorage.Direction.Down, 1);

        // // Case 6: Wrap around the map


        // vm.stopPrank();
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
        safariBang.randPickNextPlayer();

        address whosNext = safariBang.whosTurnNext();
        
        (uint whosNextAnimalId, uint8 whosNextRow, uint8 whosNextCol) = safariBang.playerToPosition(whosNext);

        (
            , 
            ,
            , 
            uint256 whosNextAnimalSize,
            uint256 whosNextAnimalStrength,
            uint256 whosNextAnimalSpeed,
            uint256 whosNextAnimalFertility,
            uint256 whosNextAnimalAnxiety,
            uint256 whosNextAnimalAggression,
            uint256 whosNextAnimalLibido,
            bool whosNextAnimalGender,
            address whosNextOwner) = safariBang.idToAnimal(whosNextAnimalId);
        (   , 
            ,
            , 
            uint256 fuckeeAnimalSize,
            uint256 fuckeeAnimalStrength,
            uint256 fuckeeAnimalSpeed,
            uint256 fuckeeAnimalFertility,
            uint256 fuckeeAnimalAnxiety,
            uint256 fuckeeAnimalAggression,
            uint256 fuckeeAnimalLibido,
            bool fuckeeAnimalGender,
            address fuckee) = safariBang.idToAnimal(3);
        
        uint fuckerBalanceBefore = safariBang.balanceOf(whosNext);
        uint fuckeeBalanceBefore = safariBang.balanceOf(fuckee);
            
        // address fuckee = whosNext == Bob ? Emily : Bob;
        // put fuckee next to whosNext
        safariBang.godModePlacement(fuckee, 3, whosNextRow - 1, whosNextCol);

        (uint fuckeeAnimalId, uint8 fuckeeRow, uint8 fuckeeCol) = safariBang.playerToPosition(fuckee);
        
        // give whosNext's animal insane libido and Bob's animal insane fertility, make sure whosNext is female and bob is male
        whosNextAnimalLibido = 100;
        fuckeeAnimalFertility = 100;
        whosNextAnimalGender = true;
        fuckeeAnimalGender = false;
        safariBang.godModeAttributes(
            whosNextAnimalId,
            whosNextAnimalFertility,
            whosNextAnimalLibido,
            whosNextAnimalGender
        );
        safariBang.godModeAttributes(
            fuckeeAnimalId,
            fuckeeAnimalFertility,
            fuckeeAnimalLibido,
            fuckeeAnimalGender
        );
        
        vm.startPrank(whosNext);

        (bool won, SafariBangStorage.Position memory newwhosNextPosition)= safariBang.fuck(SafariBangStorage.Direction.Up);

        uint fuckeeBalanceAfter = safariBang.balanceOf(fuckee);
        uint fuckerBalanceAfter = safariBang.balanceOf(whosNext);

        (uint fuckeeNewAnimalId, uint8 fuckeeNewRow, uint8 fuckeeNewCol) = safariBang.playerToPosition(fuckee);
        (uint fuckerNewAnimalId, uint8 fuckerNewRow, uint8 fuckerNewCol) = safariBang.
            playerToPosition(whosNext);

        if (won) {
            require(fuckeeBalanceAfter == fuckeeBalanceBefore - 1, "Fuckee's animal should be burned.");
            require(fuckerBalanceAfter == fuckerBalanceBefore + 1, "Fucker should have a brand new baby animal in her quiver.");
            require(fuckeeNewRow == 0 && fuckeeNewCol == 0 && fuckeeNewAnimalId == 0, "Fuckee should not be on the map at all anymore after getting fucked with only one animal in the quiver.");
            require(newwhosNextPosition.row == fuckeeRow && newwhosNextPosition.col == fuckeeCol, "whosNext should have moved into fuckee's old cell.");
        } else {
            require(fuckerBalanceAfter == fuckerBalanceBefore - 1, "Fucker's animal should be burned.");
            require(fuckeeBalanceAfter == fuckeeBalanceBefore, "Fuckee's animal balance should be exactly as it was before.");
            require(fuckerNewRow == 0 && fuckerNewCol == 0 && fuckerNewAnimalId == 0, "Fucker should not be on the map at all anymore after getting fucked with only one animal in the quiver.");
            require(fuckeeRow == fuckeeNewRow && fuckeeCol == fuckeeNewCol, "Fuckee should not have moved at all.");
        }
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
        safariBang.randPickNextPlayer();

        address whosNext = safariBang.whosTurnNext();

        require(whosNext != address(0), "Whos next should be a player");

        (uint whosNextAnimalId, uint8 whosNextRow, uint8 whosNextCol) = safariBang.playerToPosition(whosNext);
        (uint daisyAnimalId, uint8 daisyRow, uint8 daisyCol) = safariBang.playerToPosition(Daisy);

        // console.log("Daisy pos: ", daisyRow, daisyCol);

        uint whosNextBalanceBefore = safariBang.balanceOf(whosNext);
        uint daisyBalanceBefore = safariBang.balanceOf(Daisy);

        console.log("whosNextBalanceBefore: ", whosNextBalanceBefore);
        console.log("daisyBalanceBefore: ", daisyBalanceBefore);

        // put daisy next to charlie
        safariBang.godModePlacement(Daisy, 6, whosNextRow, whosNextCol + 1);
        
        (uint daisyAnimalIdNew, uint8 daisyRowNew, uint8 daisyColNew) = safariBang.playerToPosition(Daisy);
        
        console.log("whosNext pos: ", whosNextRow, whosNextCol);
        console.log("Daisy God Mode Placed: ", daisyRowNew, daisyColNew);
        
        vm.startPrank(whosNext);

        SafariBangStorage.Position memory whosNextNewPosition = safariBang.fight(SafariBangStorage.Direction.Right);

        uint whosNextBalanceAfter = safariBang.balanceOf(whosNext);

        console.log("whosNextBalanceAfter => ", whosNextBalanceAfter);

        require(whosNextBalanceAfter == whosNextBalanceBefore, "Winning a fight should not change your balance.");
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
        safariBang.randPickNextPlayer();

        address whosNext = safariBang.whosTurnNext();

        // place all of them adjacent to Bob in the middle
        safariBang.godModePlacement(Alice, 1, 10, 10);
        safariBang.godModePlacement(Bob, 4, 11, 10);
        safariBang.godModePlacement(Charlie, 5, 12, 10);
        safariBang.godModePlacement(Daisy, 6, 10, 9);
        safariBang.godModePlacement(Emily, 7, 10, 11);

        (, uint8 whosNextRow, uint8 whosNextCol) = safariBang.playerToPosition(whosNext);

        console.log("whosNext current pos: ", whosNextRow, whosNextCol);

        // make whosNext flee
        vm.startPrank(whosNext);
        safariBang.flee();

        // expect Bob to be 3 squares from previous
        (, uint8 whosNextNewRow, uint8 whosNextNewCol) = safariBang.playerToPosition(whosNext);

        console.log("whosNext new pos: ", whosNextNewRow, whosNextNewCol);

        require(safariBang.movesRemaining(whosNext) == 0, "whosNext should be out of moves.");

        // if fleer moved at all
        if (whosNextRow != whosNextNewRow) {
            require(whosNextNewRow > whosNextRow ? whosNextNewRow - whosNextRow == 3 : whosNextRow - whosNextNewRow == 3, "Bob should have moved 3 cells.");
        } else if(whosNextCol != whosNextNewCol) {
            require(whosNextNewCol > whosNextCol ? whosNextNewCol - whosNextCol == 3 : whosNextCol - whosNextNewCol == 3, "Bob should have moved 3 cells.");
        } else {
            require(whosNextNewRow == whosNextRow && whosNextNewCol == whosNextCol, "Bob failed to flee, should stay in place.");
        }
    }
    
}