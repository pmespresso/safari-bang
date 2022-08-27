// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

import "../Storage.sol";
import "../SafariBang.sol";
import "./mocks/LinkToken.sol";
import "./mocks/MockVRFCoordinatorV2.sol";

contract SafariBangTest is Test {
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
        vrfCoordinator = new MockVRFCoordinatorV2();
        bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
        linkToken = new LinkToken();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);
        
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
    }

    function testCreateAnimal() public {
        uint new_guy_id = safariBang.createAnimal(Alice);

        (, 
            ,
            uint256 id, 
            uint256 size,
            uint256 strength,
            uint256 speed,
            uint256 fertility,
            uint256 anxiety,
            uint256 aggression,
            uint256 libido,
            bool gender,
            ) = safariBang.idToAnimal(new_guy_id);

        console.log("size: ", size);
        console.log("strength: ", strength);
        console.log("speed: ", speed);
        console.log("fertility: ", fertility);
        console.log("anxiety: ", anxiety);
        console.log("aggression: ", aggression);
        console.log("libido: ", libido);
        console.log("gender: ", gender);
    }

    function testMapGenesis() public {
        safariBang.mapGenesis(80);

        // CASE 1: check currentTokenId is incremented
        uint256 slot = stdstore
            .target(address(safariBang))
            .sig("currentTokenId()")
            .find();
        bytes32 loc = bytes32(slot);

        bytes32 currentTokenId = vm.load(address(safariBang), loc);

        emit log_named_uint("next token id after genesis mint ", uint256(currentTokenId));

        assertEq(uint256(currentTokenId), 80);

        // CASE 2: AnimalById check positions of animals by mapping(id => animal)
        (, 
            ,
            uint256 id, 
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            address owner) = safariBang.idToAnimal(69);
        
        assertEq(id, 69);
        assertEq(owner, address(safariBang));

        // CASE 4: idToPosition
        (uint animalId, uint8 row, uint8 col) = safariBang.idToPosition(69);

        // CASE 3: Animal by safariMap[][]
        uint256 idOfMyBoyAtRow0Col69 = safariBang.safariMap(row, col);
        assertEq(idOfMyBoyAtRow0Col69, 69);
    }

    function testQuiver() public {
        uint balance = Alice.balance;

        safariBang.mapGenesis(10);

        vm.startPrank(address(safariBang));

        // SafariBang contract should have no quiver, i.e. Wild Animals don't belong in a quiver
        SafariBang.Animal[] memory safariBangQuiver = safariBang.getQuiver(address(safariBang));

        assertEq(safariBangQuiver.length, 0);

        vm.stopPrank();

        // prank Alice to mint a Domesticated Animal
        vm.startPrank(Alice);

        // mint one for Alice
        safariBang.mintTo{value: 0.08 ether}(Alice);

        SafariBang.Animal[] memory userQuiver = safariBang.getQuiver(address(Alice));

        // quiver of user should have one Animal
        assertEq(userQuiver.length, 1);

        vm.stopPrank();

        // mock a fight win, should get the animal that was beaten in the quiver
    }

    function testFailNoMintPricePaid() public {
        safariBang.mintTo(Alice);
    }

    function testMintPricePaid() public {
        safariBang.mintTo{value: 0.08 ether}(Alice);
    }

    function testMintWhileGameInSession() public {
        vm.warp(0);

        safariBang.rebirth();

        uint256 newMintingPeriodStartTime = safariBang.mintingPeriodStartTime();

        console.log("newMintingPeriodStartTime ", newMintingPeriodStartTime);

        safariBang.mintTo{value: 0.08 ether}(Alice);

        require(safariBang.balanceOf(Alice) == 1, "Alice should be able to mint during minting phase.");

        // console.log("safariBang.isGameInPlay() ", safariBang.isGameInPlay());
        vm.assume(safariBang.isGameInPlay() == true);
        vm.warp(696969);
        // console.log("safariBang.isGameInPlay() ", safariBang.isGameInPlay());
        vm.startPrank(Bob);

        // console.log(abi.encodeWithSelector(SafariBangStorage.MintingPeriodOver.selector));

        vm.expectRevert(
            abi.encodeWithSelector(SafariBangStorage.MintingPeriodOver.selector)
        );
    
        (bool status, bytes memory returndata) = address(safariBang).call{value: 0.08 ether}(abi.encodePacked(
            safariBang.mintTo.selector, abi.encode(Bob)
        ));

        console.log("status ", status);
        // console.log("returndata ", returndata);

        string memory returnString = abi.decode(returndata, (string));
        assertTrue(!status);
        console.log("returnString ", returnString);
        // require(safariBang.mintingPeriodStartTime() == newMintingPeriodStartTime, "Minting period should not change till the next asteroid & rebirth.");
    }

    function testMintTo() public {
        safariBang.mintTo{value: 0.08 ether}(Alice);
        safariBang.mintTo{value: 0.08 ether}(Bob);
        safariBang.mintTo{value: 0.08 ether}(Charlie);

        (uint aliceCurrentAnimalId, uint8 aliceRow, uint8 aliceCol) = safariBang.playerToPosition(Alice);
        (uint bobCurrentAnimalId, uint8 bobRow, uint8 bobCol) = safariBang.playerToPosition(Bob);
        (uint charlieCurrentAnimalId, uint8 charlieRow, uint8 charlieCol) = safariBang.playerToPosition(Charlie);
        
        uint _aliceCurrentAnimalId = safariBang.safariMap(aliceRow, aliceCol);
        uint _bobCurrentAnimalId = safariBang.safariMap(bobRow, bobCol);
        uint _charlieCurrentAnimalId = safariBang.safariMap(charlieRow, charlieCol);

        require(aliceRow >= 0 && aliceCol >= 0, "Alice position must be >= 0");
        require(aliceRow <= 127 && aliceCol <= 127, "Alice position must be <= Grid Size");
        require(_aliceCurrentAnimalId == aliceCurrentAnimalId, "Alice current animal Id in safariMap should match in playerToPosition");

        require(bobRow >= 0 && bobCol >= 0, "Bob position must be >= 0");
        require(bobRow <= 127 && bobCol <= 127, "Bob position must be <= Grid Size");
        require(_bobCurrentAnimalId == bobCurrentAnimalId, "Bob current animal Id in safariMap should match in playerToPosition");

        require(charlieRow >= 0 && charlieCol >= 0, "Charlie position must be >= 0");
        require(charlieRow <= 127 && charlieCol <= 127, "Charlie position must be <= Grid Size");
        require(_charlieCurrentAnimalId == charlieCurrentAnimalId, "Charlie current animal Id in safariMap should match in playerToPosition");

        console.log("Alice: ", aliceRow, aliceCol);
        console.log("Bob: ", bobRow, bobCol);
        console.log("Charlie: ", charlieRow, charlieCol);

        require(!(aliceRow == bobRow && aliceCol == bobCol) && !(bobRow == charlieRow && bobCol == charlieCol), "Should not occupy same cell");
    }

    function testFailMaxSupplyReached() public {
        uint256 slot = stdstore
            .target(address(safariBang))
            .sig("currentTokenId()")
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(10000));
        vm.store(address(safariBang), loc, mockedCurrentTokenId);
        safariBang.mintTo{value: 0.08 ether}(address(0));
    }

    function testFailMintToZeroAddress() public {
        safariBang.mintTo{value: 0.08 ether}(address(0));
    }

    function testNewMintOwnerRegistered() public {
        safariBang.mintTo{value: 0.08 ether}(Alice);
        uint256 slotOfNewOwner = stdstore
            .target(address(safariBang))
            .sig(safariBang.ownerOf.selector)
            .with_key(1)
            .find();

        uint160 ownerOfTokenIdOne = uint160(
                uint256(
                    (vm.load(address(safariBang), bytes32(abi.encode(slotOfNewOwner))))
                )
        );
        assertEq(address(ownerOfTokenIdOne), Alice);
    }

    function testBalanceIncremented() public {
        safariBang.mintTo{value: 0.08 ether}(Alice);
        // get the storage slot of the balanceOf Alice
        uint256 slotBalance = stdstore
            .target(address(safariBang))
            .sig(safariBang.balanceOf.selector)
            .with_key(Alice)
            .find();
        // vm.load(contract, balanceOf(Alice))
        uint256 balanceFirstMint = uint256(
            vm.load(address(safariBang), bytes32(slotBalance))
        );
        assertEq(balanceFirstMint,1);

        safariBang.mintTo{value: 0.08 ether}(Alice);

        uint256 balanceSecondMint = uint256(
            vm.load(address(safariBang), bytes32(slotBalance))
        );
        assertEq(balanceSecondMint, 2);
    }

    function testSafeContractReceiver() public {
        Receiver receiver = new Receiver();
        safariBang.mintTo{value: 0.08 ether}(address(receiver));
        uint256 slotBalance = stdstore
            .target(address(safariBang))
            .sig(safariBang.balanceOf.selector)
            .with_key(address(receiver))
            .find();

        uint256 balance = uint256(vm.load(address(safariBang), bytes32(slotBalance)));
        assertEq(balance, 1);
    }

    function testFailUnSafeContractReceiver() public {
        vm.etch(Alice, bytes("mock code"));
        safariBang.mintTo{value: 0.08 ether}(Alice);
    }

    function testWithdrawalWorksAsOwner() public {
        Receiver receiver = new Receiver();
        address payable payee = payable(address(0x1337));
        uint256 priorPayeeBalance = payee.balance;
        safariBang.mintTo{value: safariBang.MINT_PRICE()}(address(receiver));
        assertEq(address(safariBang).balance, safariBang.MINT_PRICE());
        uint256 safariBangBalance = address(safariBang).balance;
        safariBang.withdrawPayments(payee);
        assertEq(payee.balance, priorPayeeBalance + safariBangBalance);
    }

    function testWithdrawalFailsAsNotOwner() public {
        Receiver receiver = new Receiver();
        safariBang.mintTo{value: safariBang.MINT_PRICE()}(address(receiver));

        assertEq(address(safariBang).balance, safariBang.MINT_PRICE());

        vm.expectRevert("MultiOwnable: caller is not a super owner");
        vm.startPrank(address(0xd3ad));
        safariBang.withdrawPayments(payable(address(0xd3ad)));
        vm.stopPrank();
    }
}

contract Receiver is ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}