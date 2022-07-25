// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "../src/SafariBang.sol";

contract SafariBangTest is Test {
    using stdStorage for StdStorage;
    using Strings for address;

    SafariBang private safaribang;

    function setUp() public {
        safaribang = new SafariBang("SafariBang", "SAFABA", "https://ipfs.io/ipfs/");
    }

    function testMapGenesis() public {
        safaribang.mapGenesis(79);

        // CASE 1: check currentTokenId is incremented
        uint256 slot = stdstore
            .target(address(safaribang))
            .sig("currentTokenId()")
            .find();
        bytes32 loc = bytes32(slot);

        bytes32 currentTokenId = vm.load(address(safaribang), loc);

        emit log_named_uint("next token id after genesis mint ", uint256(currentTokenId));

        assertEq(uint256(currentTokenId), 79);

        // CASE 2: check if square is populated by safariMap[][]
        uint256 idOfMyBoyAtRow0Col69 = safaribang.safariMap(0, 68);
        assertEq(idOfMyBoyAtRow0Col69, 69);
        emit log_named_uint("token id of row 0 col 68 ", uint256(idOfMyBoyAtRow0Col69));

        // CASE 3: check positions of animals by mapping(id => entitty)
        (SafariBang.EntittyType entittyType, 
            SafariBang.Species species,
            uint256 id, 
            uint32 size,
            uint32 strength,
            uint32 speed,
            uint32 fertility,
            uint32 anxiety,
            uint32 aggression,
            uint32 libido,
            bool gender,
            // uint32[2] memory position,
            address owner) = safaribang.idToEntitty(idOfMyBoyAtRow0Col69);
        
        assertEq(id, 69);
        assertEq(size, 1);
        assertEq(gender, true);
        assertEq(owner, address(safaribang));
        console.log("owner of 69", owner);
    }

    function testFailNoMintPricePaid() public {
        safaribang.mintTo(address(1));
    }

    function testMintPricePaid() public {
        safaribang.mintTo{value: 0.08 ether}(address(1));
    }

    function testFailMaxSupplyReached() public {
        uint256 slot = stdstore
            .target(address(safaribang))
            .sig("currentTokenId()")
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(10000));
        vm.store(address(safaribang), loc, mockedCurrentTokenId);
        safaribang.mintTo{value: 0.08 ether}(address(0));
    }

    function testFailMintToZeroAddress() public {
        safaribang.mintTo{value: 0.08 ether}(address(0));
    }

    function testNewMintOwnerRegistered() public {
        safaribang.mintTo{value: 0.08 ether}(address(1));
        uint256 slotOfNewOwner = stdstore
            .target(address(safaribang))
            .sig(safaribang.ownerOf.selector)
            .with_key(1)
            .find();

        uint160 ownerOfTokenIdOne = uint160(
                uint256(
                    (vm.load(address(safaribang), bytes32(abi.encode(slotOfNewOwner))))
                )
        );
        assertEq(address(ownerOfTokenIdOne), address(1));
    }

    function testBalanceIncremented() public {
        safaribang.mintTo{value: 0.08 ether}(address(1));
        // get the storage slot of the balanceOf address(1)
        uint256 slotBalance = stdstore
            .target(address(safaribang))
            .sig(safaribang.balanceOf.selector)
            .with_key(address(1))
            .find();
        // vm.load(contract, balanceOf(address(1)))
        uint256 balanceFirstMint = uint256(
            vm.load(address(safaribang), bytes32(slotBalance))
        );
        assertEq(balanceFirstMint,1);

        safaribang.mintTo{value: 0.08 ether}(address(1));

        uint256 balanceSecondMint = uint256(
            vm.load(address(safaribang), bytes32(slotBalance))
        );
        assertEq(balanceSecondMint, 2);
    }

    function testSafeContractReceiver() public {
        Receiver receiver = new Receiver();
        safaribang.mintTo{value: 0.08 ether}(address(receiver));
        uint256 slotBalance = stdstore
            .target(address(safaribang))
            .sig(safaribang.balanceOf.selector)
            .with_key(address(receiver))
            .find();

        uint256 balance = uint256(vm.load(address(safaribang), bytes32(slotBalance)));
        assertEq(balance, 1);
    }

    function testFailUnSafeContractReceiver() public {
        vm.etch(address(1), bytes("mock code"));
        safaribang.mintTo{value: 0.08 ether}(address(1));
    }

    function testWithdrawalWorksAsOwner() public {
        Receiver receiver = new Receiver();
        address payable payee = payable(address(0x1337));
        uint256 priorPayeeBalance = payee.balance;
        safaribang.mintTo{value: safaribang.MINT_PRICE()}(address(receiver));
        assertEq(address(safaribang).balance, safaribang.MINT_PRICE());
        uint256 safaribangBalance = address(safaribang).balance;
        safaribang.withdrawPayments(payee);
        assertEq(payee.balance, priorPayeeBalance + safaribangBalance);
    }

    function testWithdrawalFailsAsNotOwner() public {
        Receiver receiver = new Receiver();
        safaribang.mintTo{value: safaribang.MINT_PRICE()}(address(receiver));

        assertEq(address(safaribang).balance, safaribang.MINT_PRICE());

        vm.expectRevert("MultiOwnable: caller is not a super owner");
        vm.startPrank(address(0xd3ad));
        safaribang.withdrawPayments(payable(address(0xd3ad)));
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