// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../SafariBang.sol";
import "../Storage.sol";
import "../KeepersOMFG.sol";
import "forge-std/Test.sol";
import "./utils/Cheats.sol";

import "./mocks/MockVRFCoordinatorV2.sol";

contract KeepersOMFGTest is Test {
    SafariBang public safariBang;
    KeepersOMFG public asteroidKeeper;
    MockVRFCoordinatorV2 public vrfCoordinator;
    uint256 public staticTime;
    uint256 public INTERVAL;
    Cheats internal constant cheats = Cheats(HEVM_ADDRESS);
    address Alice = address(1);

    function setUp() public {
        staticTime = block.timestamp;
        
        vrfCoordinator = new MockVRFCoordinatorV2();
        uint64 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1 * 10**18);

        safariBang = new SafariBang(
            "SafariBang",
            "SAFABA",
            "https://ipfs.io/ipfs/",
            subId,
            address(vrfCoordinator),
            address(0),
            vrfCoordinator
        );

        // safariBang.transferSuperOwnership(address(asteroidKeeper));

        cheats.warp(staticTime);

        asteroidKeeper = new KeepersOMFG(INTERVAL, address(safariBang));

        // safariBang.mapGenesis(10);

        vm.deal(Alice, 100 ether);
    }

    /**
     * The Keeper needs to be superowner to be able to reset state
     */
    // function testIsSuperOwnerOfSafariBang() public {
    //     address superOwner = safariBang.superOwner();
        
    //     require(superOwner == address(asteroidKeeper), "Keeper contract should be super owner of Safari Bang");
    // }

    /**
     * An asteroid hits the map and wipes everything on it including:
     *   - Every animal on the grid (gets ERC721::burn() and safariMap[row][col] = 0)
     *   - Delete the burned animal from quiver. The next up animal is used for the next round
     *   - Increment roundCounter
     */
    function testClearsSafariMapStateWithAllEmptyQuivers() public {
        uint currentTokenId = safariBang.currentTokenId();
        
        // console.log("BEFORE UPKEEP");
        // before upkeep, every id should occupy a cell
        for (uint i = 1; i <= currentTokenId; i++) {
            (uint8 row, uint8 col, SafariBang.Action pendingAction) = safariBang.idToPosition(i);

            assert(!(row == 0 && col == 0));
        }

        // Upkeep
        // cheats.expectEmit(false, true, true, true);
        uint balanceBefore = safariBang.balanceOf(address(safariBang));
        console.log("Balance before: ", balanceBefore);
        cheats.warp(staticTime + INTERVAL + 1);
        asteroidKeeper.performUpkeep("0x");

        // console.log("AFTER UPKEEP");
        for (uint i = 1; i <= currentTokenId; i++) {
            (uint8 row, uint8 col, SafariBang.Action pendingAction) = safariBang.idToPosition(i);
            
            require(row == 0 && col == 0, "Position should be cleared");
        }
        uint balanceAfter = safariBang.balanceOf(address(safariBang));
        console.log("Balance After: ", balanceAfter);

        assert(balanceBefore > balanceAfter);
        assert(balanceAfter == 0);
    }

    function testClearsMapWithMixedPlayersAndWildAnimals() public {
        vm.prank(Alice);

        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Alice);

        vm.stopPrank();

        console.log("Alice balance: ", safariBang.balanceOf(Alice));

        // Upkeep
        cheats.warp(staticTime + INTERVAL + 1);
        asteroidKeeper.performUpkeep("0x");

        // For Wild Animals, check that they are wiped
        for (uint i = 1; i <= safariBang.currentTokenId(); i++) {
            (uint8 row, uint8 col, SafariBang.Action pendingAction) = safariBang.idToPosition(i);
            address owner = safariBang.ownerOf(i);

            // Wild
            if (owner == address(safariBang)) {
                require(row == 0 && col == 0, "Position should be cleared");
            } else {
                // Domestic
                SafariBang.Animal[] memory quiver = safariBang.getQuiver(owner);
                uint idOfAnimalOnCell = safariBang.safariMap(row, col);

                require(quiver.length == 2, "Should have 2 in quiver after asteroid");
                require(idOfAnimalOnCell > 0, "Should have been replaced by new animal from quiver");
            }
        }
    }

    function testCheckupReturnsFalseBeforeTime() public {
        (bool upkeepNeeded, ) = asteroidKeeper.checkUpkeep("0x");
        assertTrue(!upkeepNeeded);
    }

    function testCheckupReturnsTrueAfterTime() public {
        cheats.warp(staticTime + INTERVAL + 1); // Needs to be more than the interval
        (bool upkeepNeeded, ) = asteroidKeeper.checkUpkeep("0x");
        assertTrue(upkeepNeeded);
    }

    function testPerformUpkeepUpdatesTime() public {
        // Arrange
        uint256 currentCounter = asteroidKeeper.roundCounter();
        cheats.warp(staticTime + INTERVAL + 1); // Needs to be more than the interval

        // Act
        asteroidKeeper.performUpkeep("0x");

        // Assert
        assertTrue(asteroidKeeper.lastTimeStamp() == block.timestamp);
        assertTrue(currentCounter + 1 == asteroidKeeper.roundCounter());
    }

    function testFuzzingExample(bytes memory variant) public {
        // We expect this to fail, no matter how different the input is!
        cheats.expectRevert(bytes("Time interval not met"));
        asteroidKeeper.performUpkeep(variant);
    }
}
