// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "solmate/tokens/ERC20.sol";
import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "forge-std/console.sol";

import "./test/mocks/MockVRFCoordinatorV2.sol";
import "./VRFConsumerV2.sol";
import "./MultiOwnable.sol";
import "./Storage.sol";

error MintPriceNotPaid();
error MaxSupply();
error NonExistentTokenUri();
error WithdrawTransfer();

contract SafariBang is ERC721, MultiOwnable, IERC721Receiver, SafariBangStorage {
    using Strings for uint256;
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint64 s_subscriptionId,
        address s_vrfCoordinator_address,
        address link_token_contract,
        MockVRFCoordinatorV2 s_vrfCoordinator
        ) ERC721(_name, _symbol) {
        baseURI = _baseURI;

        // TODO: change to real for deployment
        vrfCoordinator = s_vrfCoordinator;
        vrfConsumer = new VRFConsumerV2(s_subscriptionId, s_vrfCoordinator_address, link_token_contract, keyHash);

        vrfConsumer.requestRandomWords();
        uint256 requestId = vrfConsumer.s_requestId();
        vrfCoordinator.fulfillRandomWords(requestId, address(vrfConsumer));

        words = getWords(requestId);
    }

    /**
        "And on the 69th day, he said, let there be a bunch of horny angry animals" - God, probably
        @dev On each destruction of the game map, this genesis function is called by the contract super owner to randomly assign new animals across the map.
     */
    function mapGenesis(uint howMany) public onlySuperOwner {
        for (uint i = 0; i < howMany; i++) {
            createEntitty(address(this));
        }
    }

    function createEntitty(address to) public returns (uint newGuyId) {
        uint256 currId = ++currentTokenId;

        // console.log("Minting => ", currId);

        if (currId > TOTAL_SUPPLY) {
            console.log("ERROR: MAX SUPPLY");
            revert MaxSupply();
        }

        _safeMint(address(this), currId);

        // if something already there, try permutation of word until out of permutations or find empty square.

        bool isEmptySquare = false;
        uint256 speciesIndex;
        uint8 row;
        uint8 col;
        uint8 modulo = NUM_ROWS;

        while(!isEmptySquare) {
            speciesIndex = words[currId % words.length] % species.length;
            row = uint8(words[currId % words.length] % modulo);
            col = uint8(words[(currId + 1) % words.length] % modulo);

            if (safariMap[row][col] == 0) {
                isEmptySquare = true;
            } else {
                modulo -= 1;
            }
        }

        Position memory position = Position({
            row: row,
            col: col,
            pendingAction: Action.None
        });

        Entitty memory wipAnimal = Entitty({
            entittyType: to == address(this) ? EntittyType
            .WILD_ANIMAL : EntittyType.DOMESTICATED_ANIMAL,
            species: species[speciesIndex],
            id: currId,
            size: words[0] % 50,
            strength: words[0] % 49,
            speed: words[0] % 48,
            fertility: words[0] % 47,
            anxiety: words[0] % 46,
            aggression: words[0] % 45,
            libido: words[0] % 44, 
            gender: words[0] % 2 == 0 ? true : false,
            position: position,
            owner: to
        });

        // only Players have quiver, WILD_ANIMALS do not belong in a quiver
        if (wipAnimal.owner != address(this)) {
            quiver[to].push(wipAnimal);    
        }
        safariMap[row][col] = currId;
        idToEntitty[currId] = wipAnimal;
        idToPosition[currId] = position;

        return wipAnimal.id;
    }

    /** 
    @dev A player must make a move on their turn. You can only move one square at a time.

    Possible cases:
        a) Empty square: just update position and that's it.
        b) Wild Animal: You need to fight, flee, or fuck. Consequences depend on the action.
        c) Domesicated Animal: You need to fight or fuck (cannot flee). Same consequences as above.
    @param direction up, down, left, or right.
    */
    function move(Direction direction) internal returns (uint8[2] memory newPosition) {
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
            b) All Domesticated Animals that are on the map are burned and taken off the map. If there is another one in the quiver, that one takes its place on the same cell.
            c) mapGenesis() again, but minus the delta of how many domesticated animals survived (were minted but in the quiver, not on the map).
     */
    function omfgAnAsteroidOhNo() public returns (bool) {

        // Take Entitty's off the map if quiver empty, else place next up on the same position.
        for (uint i = 1; i <= currentTokenId; i++) {
            Position memory position = idToPosition[i];
            console.log("can get position");
            if (!(position.row == 0 && position.col == 0)) {
                console.log("position.row: ", position.row);
                console.log("position.col: ", position.col);
                delete safariMap[position.row][position.col];

                // update the Position in Entitty itself
                Entitty memory entitty = idToEntitty[i];

                console.log("It gets this far: ", entitty.owner);
                deleteFirstEntittyFromQuiver(entitty.owner, entitty.id);
            }
        }
        
        return true;
    }

    function deleteFirstEntittyFromQuiver(address who, uint id) internal {
        // You're out of animals, remove from map and burn
        if (who == address(this) || quiver[who].length <= 1) {
            console.log("Ain't no quiver");
            delete idToEntitty[id];
            delete idToPosition[id];
            delete quiver[who];
            
            _burn(id);
        } else {
            Entitty memory deadEntitty = quiver[who][0];
            console.log("In else block");
            // delete first animal in quiver, replace with last one
            quiver[who][0] = quiver[who][quiver[who].length - 1];

            quiver[who].pop();
                    
            Entitty memory nextUp = quiver[who][0];
            nextUp.position = deadEntitty.position;
            idToPosition[nextUp.id] = nextUp.position;
            idToEntitty[nextUp.id] = nextUp;
            safariMap[nextUp.position.row][nextUp.position.col] = nextUp.id;
        }
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

        createEntitty(to);

        return currId;
    }

    function getQuiver(address who) public view returns (Entitty[] memory myQuiver){
        return quiver[who];
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

     function getWords(uint256 requestId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _words = new uint256[](vrfConsumer.s_numWords());
        for (uint256 i = 0; i < vrfConsumer.s_numWords(); i++) {
            _words[i] = uint256(keccak256(abi.encode(requestId, i)));
        }
        return _words;
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