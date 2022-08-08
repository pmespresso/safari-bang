// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "forge-std/console.sol";

import "./test/mocks/MockVRFCoordinatorV2.sol";
import "./VRFConsumerV2.sol";

contract SafariBangStorage {
    using Strings for uint256;

    event AnimalReplacedFromQuiver(uint indexed id, uint8 indexed row, uint8 indexed col);
    event AnimalBurnedAndRemovedFromCell(uint indexed id, uint8 indexed row, uint8 indexed col);
    event AsteroidDeathCount(uint indexed survivors, uint indexed dead, uint indexed timestamp);
   
    /**
        Chainlink VRF - This if for Mumbai.
        TODO: Change to Polygon Mainnet
        https://docs.chain.link/docs/vrf-contracts/#polygon-matic-mumbai-testnet
     */
    
    bytes32 keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    uint64 subId;
    VRFConsumerV2 public vrfConsumer;
    MockVRFCoordinatorV2 public vrfCoordinator;

    uint96 constant FUND_AMOUNT = 1 * 10**18;

    uint256[] internal words;

    string public baseURI;
    uint256 public currentTokenId = 0;
    uint256 public TOTAL_SUPPLY = 12_500; // map is 128 * 128 = 16384 so leave ~24% of map empty but each time asteroid happens this goes down by number of animals that were on the map.
    uint256 public constant MINT_PRICE = 0.08 ether;// TODO: is this even necessary?

    uint8 public constant NUM_ROWS = 128;
    uint8 public constant NUM_COLS = 128;

    uint32 public roundCounter; // keep track of how many rounds of asteroid destruction

    // _superOwner will always be the contract address, in order to clear state with asteroid later.
    enum AnimalType {
        DOMESTICATED_ANIMAL, // _owner is some Eth address
        WILD_ANIMAL // _owner is SafariBang contract address
    }

    enum Specie {
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
    
    struct Position {
        uint animalId;
        uint8 row;
        uint8 col;
    }

    // probably put this offchain?
    struct Animal {
        AnimalType animalType;
        Specie species; // this determines the image
        uint256 id;
        uint256 size;
        uint256 strength; // P(successfully "fight")
        uint256 speed; // P(successfully "flee")
        uint256 fertility; // P(successfully "fuck" and conceive)
        uint256 anxiety; // P(choose "flee" | isWildAnimal())
        uint256 aggression; // P(choose "fight" | isWildAnimal())
        uint256 libido; // P(choose "fuck" | isWildAnimal())
        bool gender; // animals are male or female
        Position position;
        address owner;
    }
    
    mapping (uint256 => mapping(uint256 => uint256)) public safariMap; // safariMap[row][col] => animalId
    mapping (uint256 => Position) public idToPosition;
    mapping (address => Position) public playerToPosition;
    mapping (uint256 => Animal) public idToAnimal;
    mapping (address => Animal[]) internal quiver;
    mapping (address => uint8) public movesRemaining; // Maybe you can get powerups for more moves or something.

    Specie[20] public species = [
        Specie.ZEBRAT, // Zebra with a bratty attitude
        Specie.LIONNESSY, // Lionness thinks she's a princess
        Specie.DOGGIE, // self explanatory canine slut
        Specie.PUSSYCAT, // self explanatory slut but feline
        Specie.THICCHIPPO, // fat chick
        Specie.GAZELLA, // jumpy anxious female character
        Specie.MOUSEY, // Spouse material
        Specie.WOLVERINERASS, // wolf her in her ass i dunno man
        Specie.ELEPHAT, // phat ass
        Specie.RHINOCERHOE, // always horny
        Specie.CHEETHA, // this cat ain't loyal
        Specie.BUFFALO, // hench stud
        Specie.MONKGOOSE, // zero libido just meditates
        Specie.WARTHOG, // genital warts
        Specie.BABOOB, // double D cup baboon
        Specie.WILDEBEEST, // the other stud
        Specie.IMPALA, // the inuendos just write themselves at this point
        Specie.COCKODILE, // i may need professional help
        Specie.HORNBILL, // who names these animals
        Specie.OXPECKER // this bird is hung like an ox]
    ];
}