-include .env

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install smartcontractkit/chainlink-brownie-contracts && forge install OpenZeppelin/openzeppelin-contracts && forge install rari-capital/solmate && forge install foundry-rs/forge-std

# Update Dependencies
update:; forge update

build:; forge build --via-ir --optimize

test :; forge test 

snapshot :; forge snapshot

slither :; slither ./src 

format :; npx prettier --write src/**/*.sol && prettier --write src/*.sol

# solhint should be installed globally
lint :; solhint src/**/*.sol && solhint src/*.sol

anvil :; anvil -m 'test test test test test test test test test test test junk'

# use the "@" to hide the command from your shell 
deploy-rinkeby :; @forge script script/${contract}.s.sol:Deploy${contract} --rpc-url ${RINKEBY_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-polygon :; @forge script script/${contract}.s.sol:Deploy${contract} --rpc-url ${POLYGON_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${POLYGONSCAN_API_KEY}  -vvvv

deploy-mumbai :; @forge script script/${contract}.s.sol:Deploy${contract} --via-ir --rpc-url ${MUMBAI_RPC_URL} --private-key ${PRIVATE_KEY} --gas-limit=7500000 --broadcast --verify --optimize --optimizer-runs 200 --use 0.8.16 --etherscan-api-key ${POLYGONSCAN_API_KEY} -vvvv

# This is the private key of account from the mnemonic from the "make anvil" command
deploy-anvil :; @forge script script/${contract}.s.sol:Deploy${contract} --rpc-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast 

deploy-all :; make deploy-${network} contract=APIConsumer && make deploy-${network} contract=KeepersCounter && make deploy-${network} contract=PriceFeedConsumer && make deploy-${network} contract=VRFConsumerV2

rand-mumbai :; @cast send ${contract} --rpc-url ${MUMBAI_RPC_URL} --private-key=${PRIVATE_KEY} "getRandomWords()"

genesis-mumbai :; @cast send ${contract} --rpc-url ${MUMBAI_RPC_URL} --private-key=${PRIVATE_KEY} --gas-limit=5000000 "mapGenesis(uint256)" 10

mintTo-mumbai :; @cast send ${contract} --value=0.08ether --rpc-url ${MUMBAI_RPC_URL} --private-key=${SECONDARY_PRIVATE_KEY} "mintTo(address)" 0xB53e858cdBB8bd45FC0b647C6D84C8DE30c40Ff0 --gas-limit=1000000

whereami-mumbai :; @cast call ${contract} --rpc-url ${MUMBAI_RPC_URL}  "playerToPosition(address)" ${player}