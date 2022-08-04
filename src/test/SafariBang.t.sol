// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

import "../SafariBang.sol";
import "./mocks/LinkToken.sol";
import "./mocks/MockVRFCoordinatorV2.sol";

contract SafariBangTest is Test {
    using stdStorage for StdStorage;
    using Strings for address;

    SafariBang private safariBang;

    address Alice = address(1);

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
    }

    function testCreateEntitty() public {
        uint new_guy_id = safariBang.createEntitty(Alice);

        (SafariBang.EntittyType entittyType, 
            SafariBang.Specie species,
            uint256 id, 
            uint256 size,
            uint256 strength,
            uint256 speed,
            uint256 fertility,
            uint256 anxiety,
            uint256 aggression,
            uint256 libido,
            bool gender,
            SafariBang.Position memory position,
            address owner) = safariBang.idToEntitty(new_guy_id);

        console.log("size: ", size);
        console.log("strength: ", strength);
        console.log("speed: ", speed);
        console.log("fertility: ", fertility);
        console.log("anxiety: ", anxiety);
        console.log("aggression: ", aggression);
        console.log("libido: ", libido);
        console.log("gender: ", gender);
        console.log("position.row", position.row);
        console.log("position.col", position.col);
        assert(position.row >= 0 && position.row <= 128);
        assert(position.col >= 0 && position.col <= 128);
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

        // CASE 2: EntittyById check positions of animals by mapping(id => entitty)
        (SafariBang.EntittyType entittyType, 
            SafariBang.Specie species,
            uint256 id, 
            uint256 size,
            uint256 strength,
            uint256 speed,
            uint256 fertility,
            uint256 anxiety,
            uint256 aggression,
            uint256 libido,
            bool gender,
            SafariBang.Position memory position,
            address owner) = safariBang.idToEntitty(69);
        
        assertEq(id, 69);
        assertEq(owner, address(safariBang));

        // CASE 3: Entitty by safariMap[][]
        uint256 idOfMyBoyAtRow0Col69 = safariBang.safariMap(position.row, position.col);
        assertEq(idOfMyBoyAtRow0Col69, 69);

        // CASE 4: idToPosition
        (uint8 row, uint8 col, SafariBang.Action pendingAction) = safariBang.idToPosition(69);
        assertEq(position.row, row);
        assertEq(position.col, col);

        // TODO: Compare Enums how?
        // assertEq(pendingAction, position.pendingAction);
    }

    function testQuiver() public {
        uint balance = Alice.balance;

        console.log(balance);

        safariBang.mapGenesis(10);

        vm.startPrank(address(safariBang));

        // quiver of SafariBang Contract should have all 10
        SafariBang.Entitty[] memory safariBangQuiver = safariBang.getQuiver(address(safariBang));

        assertEq(safariBangQuiver.length, 10);

        vm.stopPrank();

        // prank Alice to mint a Domesticated Animal
        vm.startPrank(Alice);

        // mint one for Alice
        safariBang.mintTo{value: 0.08 ether}(Alice);

        SafariBang.Entitty[] memory userQuiver = safariBang.getQuiver(address(safariBang));

        // quiver of user should have one Animal
        assertEq(userQuiver.length, 1);

        vm.stopPrank();

        // mock a fight win, should get the animal that was beaten in the quiver
    }


    // TODO: function testMove() public {}

    function testFailNoMintPricePaid() public {
        safariBang.mintTo(address(1));
    }

    function testMintPricePaid() public {
        safariBang.mintTo{value: 0.08 ether}(address(1));
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
        safariBang.mintTo{value: 0.08 ether}(address(1));
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
        assertEq(address(ownerOfTokenIdOne), address(1));
    }

    function testBalanceIncremented() public {
        safariBang.mintTo{value: 0.08 ether}(address(1));
        // get the storage slot of the balanceOf address(1)
        uint256 slotBalance = stdstore
            .target(address(safariBang))
            .sig(safariBang.balanceOf.selector)
            .with_key(address(1))
            .find();
        // vm.load(contract, balanceOf(address(1)))
        uint256 balanceFirstMint = uint256(
            vm.load(address(safariBang), bytes32(slotBalance))
        );
        assertEq(balanceFirstMint,1);

        safariBang.mintTo{value: 0.08 ether}(address(1));

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
        vm.etch(address(1), bytes("mock code"));
        safariBang.mintTo{value: 0.08 ether}(address(1));
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