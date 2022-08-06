// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

interface ISafariBang {
    function omfgAnAsteroidOhNo() external returns(bool);
}

/**
 * @title The OMFGANASTEROID Contract
 * @notice  A keeper-compatible contract that resets game state variables at fixed time intervals
 */
contract KeepersOMFG is KeeperCompatibleInterface {
    /**
     * Public counter variable
     */
    uint256 public roundCounter;

    /**
     * Use an interval in seconds and a timestamp to slow execution of Upkeep
     */
    uint256 public immutable interval;
    uint256 public lastTimeStamp;

    ISafariBang safariBang;

    /**
     * @notice Executes once when a contract is created to initialize state variables
     *
     * @param updateInterval - Period of time between two counter increments expressed as UNIX timestamp value2
     */
    constructor(uint256 updateInterval, address _safariBang) {
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        roundCounter = 0;
        safariBang = ISafariBang(_safariBang);
    }

    /**
     * @notice Checks if the contract requires work to be done
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    /**
     * @notice Performs the work on the contract, if instructed by :checkUpkeep():
     */
    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        // add some verification
        (bool upkeepNeeded, ) = checkUpkeep("");
        require(upkeepNeeded, "Time interval not met");

        lastTimeStamp = block.timestamp;
        roundCounter = roundCounter + 1;
        // We don't use the performData in this example.
        // The performData is generated by the Keeper's call to your checkUpkeep function

        safariBang.omfgAnAsteroidOhNo();
    }
}