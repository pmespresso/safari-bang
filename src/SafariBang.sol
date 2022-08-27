// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "forge-std/console.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "./test/mocks/MockVRFCoordinatorV2.sol";
import "./MultiOwnable.sol";
import "./Storage.sol";
import "./VRFConsumerV2.sol";

contract SafariBang is ERC721, MultiOwnable, IERC721Receiver, SafariBangStorage, VRFConsumerV2 {
    using Strings for uint256;

    event MapGenesis();
    event VRFGetWordsSuccess();
    event CreateAnimal(uint id);
    event Log(string message);
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address _vrfCoordinator,
        address _linkToken,
        uint64 _subId,
        bytes32 _keyHash
        ) ERC721(_name, _symbol) VRFConsumerV2(_subId, _vrfCoordinator, _linkToken, _keyHash) {
        baseURI = _baseURI;

        _transferSuperOwnership(msg.sender);
    }

    /**
        Set the new Minting phase
        Once the minting phase is past, mintTo closes and the isGameInPlay should be true;
     */
    function rebirth() public onlySuperOwner {
        mintingPeriodStartTime = block.timestamp;
        isGameInPlay = false;
        emit Rebirth(mintingPeriodStartTime);
    }

    /**
        "And on the 69th day, he said, let there be a bunch of horny angry animals" - God, probably
        @dev On each destruction of the game map, this genesis function is called by the contract super owner to randomly assign new animals across the map.
     */
    function mapGenesis(uint howMany) public onlySuperOwner {
        require(s_randomWords.length > 0, "Randomness should be fulfilled first.");
        emit MapGenesis();

        for (uint i = 0; i < howMany; i++) {
            createAnimal(address(this));
        }
    }

    function createAnimal(address to) public returns (uint newGuyId) {
        uint256 currId = ++currentTokenId;

        emit CreateAnimal(currId);

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

        require(s_randomWords.length > 0, "Randomness should have been fulfilled.");

        while(!isEmptySquare) {
            speciesIndex = s_randomWords[currId % s_randomWords.length] % species.length;
            row = uint8(s_randomWords[currId % s_randomWords.length] % modulo);
            col = uint8(s_randomWords[(currId + 1) % s_randomWords.length] % modulo);

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
            size: s_randomWords[0] % 50,
            strength: s_randomWords[0] % 49,
            speed: s_randomWords[0] % 48,
            fertility: s_randomWords[0] % 47,
            anxiety: s_randomWords[0] % 46,
            aggression: s_randomWords[0] % 45,
            libido: s_randomWords[0] % 44, 
            gender: s_randomWords[0] % 2 == 0 ? true : false,
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

        isPendingAction[wipAnimal.owner] = true;

        return wipAnimal.id;
    }

    /**
        After each turn, you roll an X sided die
        The corresponding animalId's owner gets to move next, if they exist and havne't gone yet.
     */
    function randPickNextPlayer() public onlyCurrentPlayer {
        require(allPlayers.length >= 2, "Needs to be at least 2 players to play.");
        address nextPlayer;

        uint256 i = 0;

        while(nextPlayer == address(0)) {
            require(s_randomWords.length > 0 && s_randomWords[i] != 0, "Randomness must be fulfilled");
            uint numerator = sqrt(s_randomWords[i]);

            console.log("randPickNextPlayer()::numerator: ", numerator);

            uint8 nextIndex = uint8(numerator % allPlayers.length);
            address potentialNextGuy = allPlayers[nextIndex];

            console.log("randPickNextPlayer()::nextIndex: ", nextIndex);

            if (potentialNextGuy != address(0) && isPendingAction[potentialNextGuy]) {
                nextPlayer = potentialNextGuy;
            } else {
                i = (i + 1) % s_randomWords.length;
            }
        }
        
        whosTurnNext = nextPlayer;
        isPendingAction[msg.sender] = false;
    }

    function getAllPlayers() public returns (address[] memory) {
        return allPlayers;
    }

    /** 
    @dev A animal can move to an empty square, but it's a pussy move. You can only move one square at a time. This is only for moving to empty squares. Otherwise must fight,  or fuck
    @param direction up, down, left, or right.
    @param howManySquares usually 1, only flee() will set it to 3
    */
    function move(Direction direction, uint8 howManySquares) onlyCurrentPlayer public returns (Position memory newPosition) {
        require(isPendingAction[msg.sender] == true, "This player has no moves left");
        require(whosTurnNext == msg.sender, "It is not your turn!");

        Position memory currentPosition = playerToPosition[msg.sender];

        console.log("Before move(): Moves remaining ", msg.sender, " - ", movesRemaining[msg.sender]);

        require(ownerOf(currentPosition.animalId) == msg.sender, "Only owner can move piece");
        require(movesRemaining[msg.sender] > 0, "You are out of moves");

        movesRemaining[msg.sender] -= 1;
        isPendingAction[msg.sender] = false;

        if (direction == Direction.Up) {
            require(safariMap[currentPosition.row - howManySquares][currentPosition.col] == 0, "can only use move on empty square");
            
            uint8 newRow = currentPosition.row - howManySquares >= 0 ? currentPosition.row - howManySquares : NUM_ROWS;

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
                currentPosition.row + howManySquares <= NUM_ROWS 
                ? currentPosition.row + howManySquares
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
            require(safariMap[currentPosition.row][currentPosition.col - howManySquares] == 0, "can only use move on empty square");
            
            uint8 newCol = 
                currentPosition.col - howManySquares >= 0
                ? currentPosition.col - howManySquares
                : NUM_COLS;
            
            Position memory newPosition = currentPosition;
            newPosition.col = newCol;

            idToPosition[currentPosition.animalId] = newPosition;
            playerToPosition[msg.sender] = newPosition;
            safariMap[currentPosition.row][currentPosition.col] = 0;
            safariMap[currentPosition.row][newCol] = currentPosition.animalId;

            return newPosition;
        } else if (direction == Direction.Right) {
            require(safariMap[currentPosition.row][currentPosition.col + howManySquares] == 0, "can only use move on empty square");
            uint8 newCol = 
                currentPosition.col + howManySquares <= NUM_COLS 
                ? currentPosition.col + howManySquares
                : 0;
            
            Position memory newPosition = currentPosition;
            newPosition.col = newCol;

            idToPosition[currentPosition.animalId] = newPosition;
            playerToPosition[msg.sender] = newPosition;
            safariMap[currentPosition.row][currentPosition.col] = 0;
            safariMap[currentPosition.row][newCol] = currentPosition.animalId;

            return newPosition;
        }
        console.log("After move(): Moves remaining ", msg.sender, " - ", movesRemaining[msg.sender]);
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
        Animal memory newAnimal = Animal({
            animalType: animal.animalType,
            species: animal.species,
            id: animal.id,
            size: animal.size,
            strength: animal.strength,
            speed: animal.speed,
            fertility: fertility,
            anxiety: animal.anxiety,
            aggression: animal.aggression,
            libido: libido, 
            gender: gender,
            owner: animal.owner
        });

        idToAnimal[id] = newAnimal;
    }

    /**
        @dev Fight the animal on the same square as you're trying to move to.
        
        If succeed, take the square and the animal goes into your quiver. 
        If fail, you lose the animal and you're forced to use the next animal in your quiver, or mint a new one if you don't have one, or wait till the next round if there are no more animals to mint.
     */
    function fight(Direction direction) external onlyCurrentPlayer returns (Position memory newPosition) {


        Animal[] memory challengerQuiver = getQuiver(msg.sender);
        console.log("challenger quiver legnth: ", challengerQuiver.length);
        Animal memory challenger = challengerQuiver[0];
        console.log("Challenger: ", challenger.id);
        Position memory challengerPos = playerToPosition[msg.sender];
        console.log("Challenger Pos: ", challengerPos.row, challengerPos.col);

        (uint8 rowToCheck, uint8 colToCheck) = _getCoordinatesToCheck(challengerPos.row, challengerPos.col, direction, 1);
        
        // check there is an animal there
        // TODO: Check that it is wild
        require(!_checkIfEmptyCell(rowToCheck, colToCheck), "Cannot try to fight on empty square");

        uint256 theGuyGettingFoughtId = safariMap[rowToCheck][colToCheck];
        Animal memory theGuyGettingFought = idToAnimal[theGuyGettingFoughtId];

        emit FightAttempt(challenger.owner, theGuyGettingFought.owner);

        // apply multiplier based on delta of aggression, speed, strength, size
        uint multiplier = (
            (challenger.aggression - theGuyGettingFought.aggression) + 
            (challenger.speed - theGuyGettingFought.speed) + 
            (challenger.strength - theGuyGettingFought.strength) + 
            (challenger.size - theGuyGettingFought.size) + 1
            ) * (s_randomWords[0] / 1e73);

        console.log("muliplier: ", multiplier);

         if (multiplier > 5000) {
            console.log("Challenger Won");
            emit ChallengerWonFight(challenger.owner, theGuyGettingFought.owner, rowToCheck, colToCheck);
            // If challenger wins the fight, challenger moves into loser's square, loser is burned
            deleteFirstAnimalFromQuiver(theGuyGettingFought.owner, theGuyGettingFought.id);
            Position memory newPosition;
            console.log("movesRemaining[challenger.owner]: ", movesRemaining[challenger.owner]);

            // Challenger won and moves into the space of the defender
            if(_checkIfEmptyCell(rowToCheck, colToCheck)) {
                console.log("move to: ", rowToCheck, colToCheck);
                newPosition = move(direction, 1);
            } else {
            // Challenger lost and he either was deleted or remains with next animal from quiver on deck
                newPosition = challengerPos;
                if (movesRemaining[challenger.owner] != 0) {
                    movesRemaining[challenger.owner] -= 1;
                }
            }
            
            return newPosition;
        } else {
            console.log("Challenger Lost");
            // If lose burn loser, nobody moves
            deleteFirstAnimalFromQuiver(challenger.owner, challenger.id);
            console.log("movesRemaining[challenger.owner]: ", movesRemaining[challenger.owner]);
            emit ChallengerLostFight(challenger.owner, theGuyGettingFought.owner, challengerPos.row, challengerPos.col);
            return challengerPos;
        }
    }

    /**
        @dev Fuck an animal and maybe you can conceive (mint) a baby animal to your quiver.
     */
    function fuck(Direction direction) external onlyCurrentPlayer returns (bool won, Position memory newPosition) {
        require(movesRemaining[msg.sender] >= 1, "You have no remaining moves");
        require(whosTurnNext == msg.sender, "It ain't your turn, guy");
        require(s_randomWords.length > 0, "Randomness must be fulfilled already.");
        // load player's animal
        Animal[] memory fuckerQuiver = getQuiver(whosTurnNext);
        Animal memory fucker = fuckerQuiver[0];
        
        console.log("fucker.id => ", fucker.id);
        console.log("fucker.owner => ", fucker.owner);

        Position memory challengerPos = playerToPosition[whosTurnNext];

        (uint8 rowToCheck, uint8 colToCheck) = _getCoordinatesToCheck(challengerPos.row, challengerPos.col, direction, 1);

        // check there is a wild animal there
        require(!_checkIfEmptyCell(rowToCheck, colToCheck), "Cannot try to fuck on empty square");

        console.log("===== Map =====");
        console.log(safariMap[challengerPos.row - 1][challengerPos.col - 1], safariMap[challengerPos.row - 1][challengerPos.col], safariMap[challengerPos.row - 1][challengerPos.col + 1]);
        console.log(safariMap[challengerPos.row][challengerPos.col - 1], safariMap[challengerPos.row][challengerPos.col], safariMap[challengerPos.row][challengerPos.col + 1]);
        console.log(safariMap[challengerPos.row + 1][challengerPos.col - 1], safariMap[challengerPos.row + 1][challengerPos.col], safariMap[challengerPos.row + 1][challengerPos.col + 1]);
        console.log("===============");
        
        uint256 fuckeeId = safariMap[rowToCheck][colToCheck];
        Animal memory fuckee = idToAnimal[fuckeeId];

        console.log("fuckee.id => ", fuckee.id);
        console.log("fuckee.owner => ", fuckee.owner);
        
        require(fucker.owner != fuckee.owner, "Can't fuck yourself, mate");
        // require(fuckee.gender != fucker.gender, "Cannot impregnate same sex animal");

        emit FuckAttempt(whosTurnNext, fuckee.owner);

        // apply multiplier based on libido and fertility
        uint multiplier = (fucker.libido * fuckee.fertility / sqrt(s_randomWords[0] / 1e73)) % 100;

        console.log("muliplier: ", multiplier);

        if (multiplier > 50) {
            // If success, move animal to fucker's quiver mint new baby and move into the space
            uint idOfNewBaby = giveBirth(fucker.owner);

            quiver[fucker.owner].push(fuckee);
            deleteFirstAnimalFromQuiver(fuckee.owner, fuckee.id);
            Position memory newPosition;
            // if that was their last animal
            if(_checkIfEmptyCell(rowToCheck, colToCheck)) {
                console.log("move to: ", rowToCheck, colToCheck);
                newPosition = move(direction, 1);
            } else {
                newPosition = challengerPos;
                movesRemaining[fucker.owner] -= 1;
            }

            emit FuckSuccess(fucker.owner, idOfNewBaby);
            
            return (true, newPosition);
        } else {
            // If fail, replace from quiver
            deleteFirstAnimalFromQuiver(fucker.owner, fucker.id);
            return (false, challengerPos);
        }
    }

    // Babylonian method same as Uniswap uses
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
        @dev Flee an animal and maybe end up in the next square but if the square you land on has an animal on it again, then you have to fight or fuck it.

        It will pick a random direction and move you 3 squares over any obstacles. If you land on an animal then you need to fuck or fight it.

        You need to be next to at least one animal to flee. Otherwise just move().
     */
    function flee() public payable returns (Position memory newPosition) {
        Position memory fleerPos = playerToPosition[msg.sender];
        // adjacent animals
        Position[4] memory adjacents = _getAdjacents(fleerPos);

        console.log('Adjacents: ', adjacents.length);

        require(adjacents.length > 0, "Need at least one adjacent to flee.");
        
        // pick a random direction
        // VRF gen random number
        getRandomWords();
        uint256 directionIndex = s_randomWords[2] % 4;
        Direction direction;
        if (directionIndex == 0) {
            direction = Direction.Up;
        } else if (directionIndex == 1) {
            direction = Direction.Down;
        } else if (directionIndex == 2) {
            direction = Direction.Left;
        } else {
            direction = Direction.Right;
        }

        console.log("Direction: ", uint(direction));
        // move them 3 squares
        (uint8 rowToCheck, uint8 colToCheck) = _getCoordinatesToCheck(fleerPos.row, fleerPos.col, direction, 3);

        if (_checkIfEmptyCell(rowToCheck, colToCheck)) {
            // if land on empty, stop
            Position memory newPosition = move(direction, 3);
            return newPosition;
        } else {
            // if land on animal, flee fails, player remains on their current cell.
            movesRemaining[msg.sender] -= 1;
            return fleerPos;
        }
    }

    function _getAdjacents(Position memory position) internal view returns (Position[4] memory adjacents) {
        uint top = safariMap[position.row - 1][position.col];
        uint down = safariMap[position.row + 1][position.col ];
        uint left = safariMap[position.row][position.col - 1];
        uint right = safariMap[position.row][position.col + 1];

        Position[4] memory result;

        if (top != 0) {
            result[0] = Position({
                animalId: top,
                row: position.row - 1,
                col: position.col
            });
        }

        if (down != 0) {
            result[1] = Position({
                animalId: down,
                row: position.row + 1,
                col: position.col
            });
        }

        if (left != 0) {
            result[2] = Position({
                animalId: left,
                row: position.row,
                col: position.col - 1
            });
        }

        if (right != 0) {
            result[3] = Position({
                animalId: right,
                row: position.row,
                col: position.col + 1
            });
        }

        return result;
    }

    function _getCoordinatesToCheck(uint8 currentRow, uint8 currentCol, Direction direction, uint8 howManySquares) internal pure returns (uint8, uint8) {
        uint8 rowToCheck = direction == Direction.Up ? currentRow - howManySquares : direction == Direction.Down ? currentRow + howManySquares : currentRow;
        uint8 colToCheck = direction == Direction.Left ? currentCol - howManySquares : direction == Direction.Right ? currentCol + howManySquares : currentCol;

        return (rowToCheck, colToCheck);
    }

    function _checkIfEmptyCell(uint8 rowToCheck, uint8 colToCheck) internal view returns(bool) {
        console.log("checkIfEmptyCell: ", safariMap[rowToCheck][colToCheck]);
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
        
        isGameInPlay = false;
        return true;
    }

    function deleteFirstAnimalFromQuiver(address who, uint id) internal {
        Position memory position = idToPosition[id];

        // You're out of animals, remove from map and burn
        if (who == address(this) || quiver[who].length <= 1) {
            delete idToAnimal[id];
            delete idToPosition[id];
            delete safariMap[position.row][position.col];
            delete playerToPosition[who];
            delete quiver[who];
            delete movesRemaining[who];

            _burn(id);
            
            emit AnimalBurnedAndRemovedFromCell(id, position.row, position.col);
        } else {
            Animal memory deadAnimal = quiver[who][0];
            
            // console.log("Burning: ", deadAnimal.id);
            _burn(deadAnimal.id);

            // delete first animal in quiver, replace with last one
            quiver[who][0] = quiver[who][quiver[who].length - 1];
            quiver[who].pop();

            Animal memory nextUp = quiver[who][0];
            // console.log("next up new position: ", position.row, position.col);
            idToPosition[nextUp.id] = position;
            idToAnimal[nextUp.id] = nextUp;
            safariMap[position.row][position.col] = nextUp.id;
                        
            // console.log("Next up: ", nextUp.id);
            // console.log("New Quiver length: ", quiver[who].length);

            emit AnimalReplacedFromQuiver(nextUp.id, position.row, position.col);
        }
    }

    function giveBirth(address to) internal returns (uint256) {
        createAnimal(to);

        return currentTokenId + 1;
    }

    /**
        @dev Mint a character for a paying customer
        @param to address of who to mint the character to
     */
    function mintTo(address to) public payable returns (uint256) {
        if (msg.value < MINT_PRICE) {
            revert MintPriceNotPaid();
        }

        if (mintingPeriodStartTime + 5 minutes <= block.timestamp) {
            isGameInPlay = true;
            
            revert MintingPeriodOver();
        }

        createAnimal(to);
        addPlayer(to);

        return currentTokenId + 1;
    }

    function addPlayer(address who) internal {
        for (uint i = 0; i < allPlayers.length; i++) {
            if (allPlayers[i] == who) {
                return;
            }
        }

        allPlayers.push(who);
        emit PlayerAdded(who, allPlayers.length);
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
    
    // VRF
    function getRandomWords() public {
        require(s_subscriptionId != 0, "Subscription ID not set");

        s_requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackGasLimit,
            s_numWords
        );
        console.log("Request Id: ", s_requestId);
    }

     function getWords(uint256 requestId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _words = new uint256[](s_numWords);
        for (uint256 i = 0; i < s_numWords; i++) {
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