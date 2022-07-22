// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

import "./MultiOwnable.sol";

error MintPriceNotPaid();
error MaxSupply();
error NonExistentTokenUri();
error WithdrawTransfer();

contract SafariBang is ERC721, MultiOwnable {
    using Strings for uint256;
    string public baseURI;
    uint256 public currentTokenId = 0;
    uint256 public constant TOTAL_SUPPLY = 12_500; // map is 128 * 128 = 16384 so leave ~24% of map empty
    uint256 public constant MINT_PRICE = 0.08 ether;

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

    // probably put this offchain?
    struct Entitty {
        EntittyType entittyType;
        Species species; // this determines the image
        uint64 id;
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

    uint64[128][128] public safariMap; // just put the id's to save space?
    mapping (uint64 => Entitty) internal idToEntitty; // then look it up here

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI
        // uint64[128][128] memory _initialMapState
        ) ERC721(_name, _symbol) {
        baseURI = _baseURI;
        // safariMap = _initialMapState;
    }

    // "and on the 69th day, he said, let there be a bunch of horny angry animals" - god, probably
    function mapGenesis() public onlySuperOwner {
        uint32 i;
        uint currId = ++currentTokenId;

        if (currId > TOTAL_SUPPLY) {
            revert MaxSupply();
        }

        // TODO: use VRF to populate different number each round
        for (i = 0; i < 5000; i++) {
            _safeMint(msg.sender, currId);

            Entitty memory wipAnimal = Entitty({
                entittyType: EntittyType.DOMESTICATED_ANIMAL,
                species: Species.ZEBRAT, // TODO: use VRF
                id: i,
                size: 1, // TODO: use VRF
                strength: 1,
                speed:1, // TODO: use VRF
                fertility: 1, // TODO: use VRF
                anxiety: 1, // TODO: use VRF
                aggression: 1, // TODO: use VRF
                libido: 1, // TODO: use VRF
                gender: true,
                position: [0, i], // TODO: use VRF
                owner: msg.sender
            });

            idToEntitty[i] = wipAnimal;
            safariMap[wipAnimal.position[0]][wipAnimal.position[1]] = i;
        }
    }

    function move() internal returns (uint32[][] memory) {

    }

    function fight() public payable returns (bool) {}
    function fuck() public payable returns (bool) {}
    function flee() public payable returns (bool) {}

    function omfgAnAsteroidOhNo() public returns (bool) {
        
    }

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
}