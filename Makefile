-include .env

.PHONY: all test clean deploy

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install Cyfrin/foundry-devops@0.0.11 --no-commit && forge install https://github.com/smartcontractkit/chainlink.git --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# Network Config
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network bsctest,$(ARGS)),--network bsctest)
	NETWORK_ARGS := --rpc-url $(RPC_BSC_TEST) --private-key $(TESTNET_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(BSCSCAN_KEY) -vvvv
endif


# deployment
deploy: 
	@forge script script/DeployLottery.s.sol:DeployLottery $(NETWORK_ARGS)

deploy-testnet :; @forge script script/DeployLottery.s.sol:DeployLottery --rpc-url ${network}  --account Testing --sender 0x7Bb8be3D9015682d7AC0Ea377dC0c92B0ba152eF --broadcast --verify --etherscan-api-key ${network} --watch
deploy-mainnet :; @forge script script/DeployLottery.s.sol:DeployLottery --rpc-url ${network}  --account ${account} --sender ${sender} --broadcast --verify --etherscan-api-key ${network}  --watch -vvvv

slither :; slither ./src 


-include ${FCT_PLUGIN_PATH}/makefile-external