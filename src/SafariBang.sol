// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "forge-std/console.sol";

import "./MultiOwnable.sol";

error MintPriceNotPaid();
error MaxSupply();
error NonExistentTokenUri();
error WithdrawTransfer();

contract SafariBang is ERC721, MultiOwnable, IERC721Receiver {
    using Strings for uint256;
    string public baseURI;
    uint256 public currentTokenId = 0;
    uint256 public constant TOTAL_SUPPLY = 12_500; // map is 128 * 128 = 16384 so leave ~24% of map empty
    uint256 public constant MINT_PRICE = 0.08 ether;

    uint32 public constant NUM_ROWS = 128;
    uint32 public constant NUM_COLS = 128;

    // _superOwner will always be the contract address, in order to clear state with asteroid later.
    enum EntittyType {
        DOMESTICATED_ANIMAL, // _owner is some Eth address
        WILD_ANIMAL // _owner is SafariBang contract address
    }

    enum Species {
        ZEBRAT, // Zebra with a bratty attitude
        LIONNESSY, // Lionness thinks she's a princess
        DOGGIE, // self explanatory canine slut
        PUSSYCAT, // self explanatory slut but feline
        THICCHIPPO, // fat chick
        GAZELLA, // jumpy anxious female character
        MOUSEY, // Spouse material
        WOLVERINERASS, // wolf her in her ass i dunno man
        ELEPHAT, // phat ass
        RHINOCERHOE, // always horny
        CHEETHA, // this cat ain't loyal
        BUFFALO, // hench stud
        MONKGOOSE, // zero libido just meditates
        WARTHOG, // genital warts
        BABOOB, // double D cup baboon
        WILDEBEEST, // the other stud
        IMPALA, // the inuendos just write themselves at this point
        COCKODILE, // i may need professional help
        HORNBILL, // who names these animals
        OXPECKER // this bird is hung like an ox
    }

    enum Direction {
        Up,
        Down,
        Left,
        Right
    }

    // probably put this offchain?
    struct Entitty {
        EntittyType entittyType;
        Species species; // this determines the image
        uint256 id;
        uint32 size;
        uint32 strength; // P(successfully "fight")
        uint32 speed; // P(successfully "flee")
        uint32 fertility; // P(successfully "fuck" and conceive)
        uint32 anxiety; // P(choose "flee" | isWildAnimal())
        uint32 aggression; // P(choose "fight" | isWildAnimal())
        uint32 libido; // P(choose "fuck" | isWildAnimal())
        bool gender; // animals are male or female, no in-between ladyboy shit like in our stupid human world
        uint32[2] position; // x,y coordinates on the map
        address owner;
    }

    mapping(uint256 => mapping(uint256 => uint256)) public safariMap; // just put the id's to save space?
    mapping (uint256 => Entitty) public idToEntitty; // then look it up here

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI
        // uint64[128][128] memory _initialMapState
        ) ERC721(_name, _symbol) {
        baseURI = _baseURI;
        // safariMap = _initialMapState;
    }

    /**
        "And on the 69th day, he said, let there be a bunch of horny angry animals" - God, probably
        @dev On each destruction of the game map, this genesis function is called by the contract super owner to randomly assign new animals across the map.
        @param howMany How many animals are you going to populate this map with, ser?
     */
    function mapGenesis(uint howMany) public onlySuperOwner {
        // TODO: use VRF to populate different number each round
        for (uint32 row = 0; row < NUM_ROWS; row++) {
            for (uint32 col = 0; col < NUM_COLS; col++) {
                uint256 currId = ++currentTokenId;

                if (currId == howMany) {
                    return;
                }

                // console.log("Minting => ", currId);

                if (currId > TOTAL_SUPPLY) {
                    console.log("ERROR: MAX SUPPLY");
                    revert MaxSupply();
                }

                _safeMint(address(this), currId);

                uint32[2] memory pos = [row, col];
                
                Entitty memory wipAnimal = Entitty({
                    entittyType: EntittyType.DOMESTICATED_ANIMAL,
                    species: Species.ZEBRAT, // TODO: use VRF
                    id: currId,
                    size: 1, // TODO: use VRF
                    strength: 1,
                    speed:1, // TODO: use VRF
                    fertility: 1, // TODO: use VRF
                    anxiety: 1, // TODO: use VRF
                    aggression: 1, // TODO: use VRF
                    libido: 1, // TODO: use VRF
                    gender: true,
                    position: pos, // TODO: use VRF
                    owner: address(this)
                });

                idToEntitty[currId] = wipAnimal;
                safariMap[row][col] = currId;
            }
        }

        console.log("===> ", safariMap[0][69]);
        console.log("IdToEntitty", idToEntitty[69].owner, idToEntitty[69].id);
    }

    /** 
    @dev A player must make a move on their turn. You can only move one square at a time.

    Possible cases:
        a) Empty square: just update position and that's it.
        b) Wild Animal: You need to fight, flee, or fuck. Consequences depend on the action.
        c) Domesicated Animal: You need to fight or fuck (cannot flee). Same consequences as above.
    @param direction up, down, left, or right.
    */
    function move(Direction direction) internal returns (uint32[2] newPosition) {
        return [0, 69];
    }

    /**
        @dev Fight the animal on the same square as you're trying to move to.
        

        If succeed, take the square and the animal goes into your quiver. 
        If fail, you lose the animal and you're forced to use the next animal in your quiver, or mint a new one if you don't have one, or wait till the next round if there are no more animals to mint.
     */
    function fight() public payable returns (bool) {}

    /**
        @dev Fuck an animal and maybe you can conceive (mint) a baby animal to your quiver.
     */
    function fuck() public payable returns (bool) {}

    /**
        @dev Flee an animal and maybe end up in the next square but if the square you land on has an animal on it again, then you have to fight or fuck it.
     */
    function flee() public payable returns (bool) {}

    /**
        @dev An Asteroid hits the map every interval of X blocks and we'll reset the game state:
            a) All Wild Animals are burned and taken off the map.
            b) All Domesticated Animals are burned and taken off the map.
            c) mapGenesis() again, but minus the delta of how many domesticated animals survived (were minted but in the quiver, not on the map).
     */
    function omfgAnAsteroidOhNo() public returns (bool) {
        
    }

    /**
        @dev Mint a character for a paying customer
        @param to address of who to mint the character to
     */
    function mintTo(address to) public payable returns (uint256) {
        if (msg.value < MINT_PRICE) {
            revert MintPriceNotPaid();
        }

        uint currId = ++currentTokenId;

        if (currId > TOTAL_SUPPLY) {
            revert MaxSupply();
        }

        _safeMint(to, currId);

        return currId;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert NonExistentTokenUri();
        }

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function withdrawPayments(address payable payee) external onlySuperOwner {
        uint256 balance = address(this).balance;
        (bool transferTx, ) = payee.call{value: balance}("");
        if (!transferTx) {
            revert WithdrawTransfer();
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}