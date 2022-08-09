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
            createAnimal(address(this));
        }
    }

    function createAnimal(address to) public returns (uint newGuyId) {
        uint256 currId = ++currentTokenId;

        // if you mint multiple you get more turns
        // safari gets as many moves as there are animals 
        if (movesRemaining[to] > 0) {
            movesRemaining[to] += 1;
        } else {
            movesRemaining[to] = 1;
        }

        // console.log("Create animal for ", to, " with moves remaining: ", movesRemaining[to]);

        // console.log("Minting => ", currId);

        if (currId > TOTAL_SUPPLY) {
            console.log("ERROR: MAX SUPPLY");
            revert MaxSupply();
        }

        _safeMint(to, currId);

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
            animalId: currId,
            row: row,
            col: col
        });

        Animal memory wipAnimal = Animal({
            animalType: to == address(this) ? AnimalType
            .WILD_ANIMAL : AnimalType.DOMESTICATED_ANIMAL,
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
            owner: to
        });

        // only Animals have quiver, WILD_ANIMALS do not belong in a quiver
        if (wipAnimal.owner != address(this)) {
            quiver[to].push(wipAnimal);
        }

        idToAnimal[currId] = wipAnimal;

        if (quiver[to].length <= 1) {
            safariMap[row][col] = currId;
            idToPosition[currId] = position;
            playerToPosition[to] = position;
        }

        return wipAnimal.id;
    }

    /** 
    @dev A animal can move to an empty square, but it's a pussy move. You can only move one square at a time. This is only for moving to empty squares. Otherwise must fight,  or fuck
    @param direction up, down, left, or right.
    */
    function move(Direction direction) public returns (Position memory newPosition) {
        Position memory currentPosition = playerToPosition[msg.sender];

        console.log("Moves remaining ", msg.sender, " - ", movesRemaining[msg.sender]);

        require(ownerOf(currentPosition.animalId) == msg.sender, "Only owner can move piece");
        require(movesRemaining[msg.sender] > 0, "You are out of moves");

        movesRemaining[msg.sender] -= 1;

        if (direction == Direction.Up) {
            require(safariMap[currentPosition.row - 1][currentPosition.col] == 0, "can only use move on empty square");
            
            uint8 newRow = currentPosition.row - 1 >= 0 ? currentPosition.row - 1 : NUM_ROWS;

            Position memory newPosition = Position({
                animalId: currentPosition.animalId,
                row: newRow,
                col: currentPosition.col
            });

            idToPosition[currentPosition.animalId] = newPosition;
            playerToPosition[msg.sender] = newPosition;
            safariMap[currentPosition.row][currentPosition.col] = 0;
            safariMap[newRow][currentPosition.col] = currentPosition.animalId;

            return newPosition;
        } else if (direction == Direction.Down) {
            require(safariMap[currentPosition.row + 1][currentPosition.col] == 0, "can only use move on empty square");

            uint8 newRow = 
                currentPosition.row + 1 <= NUM_ROWS 
                ? currentPosition.row + 1
                : 0;
            
            Position memory newPosition = Position({
                animalId: currentPosition.animalId,
                row: newRow,
                col: currentPosition.col
            });

            idToPosition[currentPosition.animalId] = newPosition;
            playerToPosition[msg.sender] = newPosition;
            safariMap[currentPosition.row][currentPosition.col] = 0;
            safariMap[newRow][currentPosition.col] = currentPosition.animalId;

            return newPosition;
        } else if (direction == Direction.Left) {
            require(safariMap[currentPosition.row][currentPosition.col - 1] == 0, "can only use move on empty square");
            
            uint8 newCol = 
                currentPosition.col - 1 >= 0
                ? currentPosition.col - 1
                : NUM_COLS;
            
            Position memory newPosition = currentPosition;
            newPosition.col = newCol;

            idToPosition[currentPosition.animalId] = newPosition;
            playerToPosition[msg.sender] = newPosition;
            safariMap[currentPosition.row][currentPosition.col] = 0;
            safariMap[currentPosition.row][newCol] = currentPosition.animalId;

            return newPosition;
        } else if (direction == Direction.Right) {
            require(safariMap[currentPosition.row][currentPosition.col + 1] == 0, "can only use move on empty square");
            uint8 newCol = 
                currentPosition.col + 1 <= NUM_COLS 
                ? currentPosition.col + 1
                : 0;
            
            Position memory newPosition = currentPosition;
            newPosition.col = newCol;

            idToPosition[currentPosition.animalId] = newPosition;
            playerToPosition[msg.sender] = newPosition;
            safariMap[currentPosition.row][currentPosition.col] = 0;
            safariMap[currentPosition.row][newCol] = currentPosition.animalId;

            return newPosition;
        }
    }

    /**
        @dev Dev only! place animal anywhere
     */
    function godModePlacement(address who, uint id, uint8 row, uint8 col) public {
        Position memory newPosition = Position({
            animalId: id,
            row: row,
            col: col
        });

        idToPosition[id] = newPosition;
        playerToPosition[who] = newPosition; 
        safariMap[row][col] = id;
    }

    function godModeAttributes(
            uint id,
            uint256 fertility,
            uint256 libido,
            bool gender) public {
        
        Animal memory animal = idToAnimal[id];

        animal.fertility = fertility;
        animal.libido = libido;
        animal.gender = gender;

        idToAnimal[id] = animal;
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
    function fuck(Direction direction) external returns (Position memory newPosition) {
        // load player's animal
        Animal[] memory fuckerQuiver = getQuiver(msg.sender);
        Animal memory fucker = fuckerQuiver[0];
        Position memory challengerPos = playerToPosition[msg.sender];
        uint8 rowToCheck = direction == Direction.Up ? challengerPos.row - 1 : direction == Direction.Down ? challengerPos.row + 1 : challengerPos.row;
        uint8 colToCheck = direction == Direction.Left ? challengerPos.col - 1 : direction == Direction.Right ? challengerPos.col + 1 : challengerPos.col;

        console.log("Row to check: ", rowToCheck);
        console.log("Col to check: ", colToCheck);

        // check there is a wild animal there
        require(!_checkIfEmptyCell(rowToCheck, colToCheck), "Cannot try to fuck on empty square");
        
        uint256 fuckeeId = safariMap[rowToCheck][colToCheck];
        Animal memory fuckee = idToAnimal[fuckeeId];

        // check is heterosexual
        require(fuckee.gender != fucker.gender, "Cannot impregnate same sex animal");

        emit FuckAttempt(fucker.owner, fuckee.owner);

        // VRF gen random number
        vrfConsumer.requestRandomWords();
        uint256 requestId = vrfConsumer.s_requestId();
        vrfCoordinator.fulfillRandomWords(requestId, address(vrfConsumer));

        uint256[] memory randomWords = getWords(requestId);

        // apply multiplier based on libido and fertility
        uint multiplier = fucker.libido * fuckee.fertility * randomWords[0] / 1e18;

        console.log("muliplier: ", multiplier);

        // sigmoid have baby or no?
        if (multiplier > 50) {
            // If success, move animal to fucker's quiver mint new baby and move into the space
            mintTo(fucker.owner);

            quiver[fucker.owner].push(fuckee);
            deleteFirstAnimalFromQuiver(fuckee.owner, fuckee.id);
            Position memory newPosition = move(direction);
            return newPosition;
        } else {
            // If fail, replace from quiver or burn fucker
            deleteFirstAnimalFromQuiver(fucker.owner, fucker.id);
            return challengerPos;
        }
    }

    /**
        @dev Flee an animal and maybe end up in the next square but if the square you land on has an animal on it again, then you have to fight or fuck it.
     */
    function flee() public payable returns (bool) {}

    function _checkIfEmptyCell(uint8 rowToCheck, uint8 colToCheck) internal returns(bool) {
        if (safariMap[rowToCheck][colToCheck] == 0) {
            return true;
        }
        return false;
    }

    /**
        @dev An Asteroid hits the map every interval of X blocks and we'll reset the game state:
            a) All Wild Animals are burned and taken off the map.
            b) All Domesticated Animals that are on the map are burned and taken off the map. If there is another one in the quiver, that one takes its place on the same cell.
            c) mapGenesis() again, but minus the delta of how many domesticated animals survived (were minted but in the quiver, not on the map).
     */
    function omfgAnAsteroidOhNo() public returns (bool) {

        // Take Animal's off the map if quiver empty, else place next up on the same position.
        for (uint i = 1; i <= currentTokenId; i++) {
            Position memory position = idToPosition[i];

            if (!(position.row == 0 && position.col == 0)) {
                // console.log("position.row: ", position.row);
                // console.log("position.col: ", position.col);
                delete safariMap[position.row][position.col];

                // update the Position in Animal itself
                Animal memory animal = idToAnimal[i];

                deleteFirstAnimalFromQuiver(animal.owner, animal.id);
            }
        }
        
        return true;
    }

    function deleteFirstAnimalFromQuiver(address who, uint id) internal {
        console.log("quiver[who].length ", quiver[who].length);
        console.log("who == address(this)", who == address(this));
        console.log("quiver[who].length <= 1", quiver[who].length <= 1);
        Position memory position = idToPosition[id];

        // You're out of animals, remove from map and burn
        if (who == address(this) || quiver[who].length <= 1) {
            console.log("Time to wipe and burn: ", id);
            console.log("Position of next up", position.row, position.col);

            delete idToAnimal[id];
            delete idToPosition[id];
            delete quiver[who];
            // delete ownerOf[id]; this is what _burn does
            
            console.log("Burning: ", id);
            _burn(id);
            emit AnimalBurnedAndRemovedFromCell(id, position.row, position.col);
        } else {
            console.log("Every Quiver Item: ", quiver[who][0].id, quiver[who][1].id, quiver[who][2].id);
            Animal memory deadAnimal = quiver[who][0];
            
            _burn(deadAnimal.id);

            // delete first animal in quiver, replace with last one
            quiver[who][0] = quiver[who][quiver[who].length - 1];
            quiver[who].pop();

            Animal memory nextUp = quiver[who][0];
            console.log("next up new position: ", position.row, position.col);
            idToPosition[nextUp.id] = position;
            idToAnimal[nextUp.id] = nextUp;
            safariMap[position.row][position.col] = nextUp.id;
                        
            console.log("Next up: ", nextUp.id);
            console.log("New Quiver length: ", quiver[who].length);

            emit AnimalReplacedFromQuiver(nextUp.id, position.row, position.col);
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

        createAnimal(to);

        return currentTokenId + 1;
    }

    function getQuiver(address who) public view returns (Animal[] memory myQuiver){
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