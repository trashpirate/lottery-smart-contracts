-include .env

.PHONY: all test clean deploy-anvil

slither :; slither ./src 

anvil :; anvil -m 'test test test test test test test test test test test junk'

anvil-mainnet :; @anvil --fork-url ${RPC_MAINNET} --fork-block-number 18810000 --fork-chain-id 1 --chain-id 123
anvil-base :; @anvil --fork-url ${RPC_BASE} --fork-block-number 8106000 --fork-chain-id 8453 --chain-id 123

# Deployment:
# contract=<contract name> 
# network=<network name> (see foundry.toml)
# account=<account name>
# sender=<deployer address>

deploy-testnet :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account Testing --sender 0x7Bb8be3D9015682d7AC0Ea377dC0c92B0ba152eF --broadcast --verify --etherscan-api-key ${network} --watch
deploy-testnet-simulate :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account Testing --sender 0x7Bb8be3D9015682d7AC0Ea377dC0c92B0ba152eF --watch

deploy-mainnet :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${account} --sender ${sender} --broadcast --verify --etherscan-api-key ${network}  --watch -vvvv
deploy-mainnet-simulate :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${account} --sender ${sender}  -vvvv

deploy-anvil :; @forge script script/DeployTurboTails.s.sol:DeployTurboTails --rpc-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast 

# Verification: 
# args=<abi encoded contructor arguments> 
# contract=<contract name> 
# network=<network name> (see foundry.toml)
# account=<account name>
# contractAddress=<deployed contract address>

verify :; @forge create --rpc-url ${network} --constructor-args ${args} --account ${account} --etherscan-api-key ${network} --verify src/${contract}.sol:${contract}
verify-base :; @forge verify-contract --chain-id 8453 --num-of-optimizations 200 --constructor-args ${args} --etherscan-api-key ${BASESCAN_KEY} ${contractAddress} src/${contract}.sol:${contract} --watch
verify-baseSepolia :; @forge verify-contract --chain-id 84532 --num-of-optimizations 200 --constructor-args ${args} --etherscan-api-key ${BASESCAN_KEY} ${contractAddress} src/${contract}.sol:${contract} --watch

abi-encode :; cast abi-encode "constructor(address)" ${args}


# Testing
test-local :; @forge test --match-test ${test} --rpc-url localhost ${output}
test-local-all :; @forge test --rpc-url localhost ${output}
test-local-fuzz :; @forge test --match-path test/fuzz/${contract}.t.sol --rpc-url localhost ${output}
test-local-unit :; @forge test --match-path test/unit/${contract}.t.sol --rpc-url localhost ${output}

integration-test-local :; @forge test --match-path test/integration/* --rpc-url localhost -vvv
integration-test-user :; @forge test --match-path test/integration/UserInteractionsTest.t.sol --rpc-url localhost -vvv
integration-test-owner :; @forge test --match-path test/integration/OwnerInteractionsTest.t.sol --rpc-url localhost -vvv



# Run scripts
run-script :; @forge script script/${script} --rpc-url ${network} --account Testing --sender 0x7Bb8be3D9015682d7AC0Ea377dC0c92B0ba152eF --broadcast


-include ${FCT_PLUGIN_PATH}/makefile-external