// SPDX-License-Identifier: CC0
pragma solidity 0.8.16;

import "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "forge-std/console.sol";

import "./test/mocks/LinkToken.sol";
import "./test/mocks/MockVRFCoordinatorV2.sol";

contract SafariBangStorage {
    using Strings for uint256;

    error MintingPeriodOver();
    error MintPriceNotPaid();
    error MaxSupply();
    error NonExistentTokenUri();
    error WithdrawTransfer();
    
    event MoveToEmptySquare(address whoMoved, uint8 newRow, uint8 newCol);
    event FightAttempt(address fighter, address fightee);
    event FuckAttempt(address fucker, address fuckee);
    event FuckSuccess(address fucker, uint newlyMinted);
    event ChallengerWonFight(address victor, address loser, uint8 newChallengerRow, uint8 newChallengerCol);
    event ChallengerLostFight(address victor, address loser, uint8 newChallengerRow, uint8 newChallengerCol);
    event AnimalReplacedFromQuiver(uint indexed id, address indexed owner, uint8 row, uint8  col);
    event AnimalBurnedAndRemovedFromCell(uint indexed id, address indexed owner, uint8  row, uint8 col);
    event AsteroidDeathCount(uint indexed survivors, uint indexed dead, uint indexed timestamp);
    event Rebirth(uint256 newMintingPeriodStartTime);
    event PlayerAdded(address who, uint totalPlayersCount);
    event PlayerRemoved(address who, uint totalPlayersCount);

    modifier onlyCurrentPlayer() {
        require(msg.sender == whosTurnNext || whosTurnNext == address(0), "Only current player can call this, unless the next player has not been decided yet.");
        _;
    }

    string public baseURI;
    uint256 public currentTokenId = 0;
    uint256 public TOTAL_SUPPLY = 3000; // map is 64 * 64 = 4096 so leave ~25% of map empty but each time asteroid happens this goes down by number of animals that were on the map.
    uint256 public constant MINT_PRICE = 0.08 ether;// TODO: is this even necessary?

    uint8 public constant NUM_ROWS = 64;
    uint8 public constant NUM_COLS = 64;

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
        THICCAPOTAMUS, // fat chick
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
        address owner;
    }

    /**
        The Map
     */
    mapping (uint256 => mapping(uint256 => uint256)) public safariMap; // safariMap[row][col] => animalId
    mapping (uint256 => Position) public idToPosition;
    mapping (address => Position) public playerToPosition;
    mapping (uint256 => Animal) public idToAnimal;
    mapping (address => Animal[]) public quiver;

    /**
        Gameplay
    */
    mapping (address => uint8) public movesRemaining; // Maybe you can get powerups for more moves or something.
    mapping (address => bool) public isPendingAction; // who still can move this turn?
    address[] public allPlayers;
    address public whosTurnNext;
    bool public isGameInPlay = false;

    uint256 public mintingPeriod = 5 minutes; // change to hours for Mainnet
    uint256 public mintingPeriodStartTime;

    Specie[20] public species = [
        Specie.ZEBRAT, // Zebra with a bratty attitude
        Specie.LIONNESSY, // Lionness thinks she's a princess
        Specie.DOGGIE, // self explanatory canine slut
        Specie.PUSSYCAT, // self explanatory slut but feline
        Specie.THICCAPOTAMUS, // fat chick
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