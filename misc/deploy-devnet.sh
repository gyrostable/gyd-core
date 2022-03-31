#!/bin/bash

SCRIPT_NAME=deploy-devnet.sh
PORT=9545
NETWORK_ID=devnet
CHAIN_ID=1337
LIVE=false
RPC_COMMAND="npx ganache-cli --port 9545"

required_variables=(SCRIPT_NAME PORT NETWORK_ID CHAIN_ID LIVE RPC_COMMAND)
for var_name in "${required_variables[@]}"; do
    declare -n var=$var_name
    if [ -z "$var" ]; then
        echo "$var_name not set"
        exit 1
    fi
done


set -e


clean=false

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -c|--clean)
            clean=true
            shift
            ;;
        *)
            echo "unknown argument $1"
            echo "usage: ./misc/$SCRIPT_NAME.sh [--clean]"
            shift
        ;;
    esac
done


if ! type -t jq > /dev/null; then
    echo "please install jq: https://stedolan.github.io/jq/"
    exit 1
fi

if [ ! -d "scripts" ]; then
    echo "please run this from the project root"
    exit 1
fi

if ! brownie networks list | grep -q $NETWORK_ID; then
    echo -e "$NETWORK_ID not found, please create it with:\nbrownie networks add Ethereum $NETWORK_ID host=http://localhost:$PORT chainid=$CHAIN_ID"
    exit 1
fi

if ! curl -s http://localhost:$PORT/ > /dev/null; then
    echo -e "node not running on port $PORT, run it with:\n$RPC_COMMAND"
    exit 1
fi

if [ "$clean" = "true" ]; then
    echo "cleaning current deployment"
    dir=$PWD
    rm -rf $dir/build/deployments/$CHAIN_ID
    if [ -f $dir/build/deployments/map.json ]; then
        cp $dir/build/deployments/map.json $dir/build/deployments/map.json.bak
        jq 'del(."'$CHAIN_ID'")' $dir/build/deployments/map.json.bak > $dir/build/deployments/map.json
    fi
elif [ -d "build/deployments/$CHAIN_ID" ]; then
    echo "$NETWORK_ID already deployed, run with --clean to clean"
    exit 1
fi

brownie run --network $NETWORK_ID scripts/deployment/deploy_config.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_asset_registry.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_asset_registry.py initialize
brownie run --network $NETWORK_ID scripts/deployment/deploy_gyd_token.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_fee_bank.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_reserve.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_motherboard.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_lp_token_exchanger_registry.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_chainlink_price_oracle.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_chainlink_price_oracle.py set_feeds
brownie run --network $NETWORK_ID scripts/deployment/deploy_uniswap_twap_price_oracle.py
if [ "$LIVE" = "true" ]; then
    brownie run --network $NETWORK_ID scripts/deployment/deploy_uniswap_twap_price_oracle.py add_pools
fi

# oracles
brownie run --network $NETWORK_ID scripts/deployment/deploy_coinbase_oracle.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_checked_price_oracle.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_checked_price_oracle.py initialize
brownie run --network $NETWORK_ID scripts/deployment/deploy_balancer_price_oracle.py cpmm
brownie run --network $NETWORK_ID scripts/deployment/deploy_balancer_price_oracle.py cpmm_v2
brownie run --network $NETWORK_ID scripts/deployment/deploy_balancer_price_oracle.py cpmm_v3
brownie run --network $NETWORK_ID scripts/deployment/deploy_balancer_price_oracle.py cemm
brownie run --network $NETWORK_ID scripts/deployment/deploy_batch_vault_price_oracle.py 
brownie run --network $NETWORK_ID scripts/deployment/deploy_batch_vault_price_oracle.py initialize

# safety checks
brownie run --network $NETWORK_ID scripts/deployment/deploy_safety_checks.py root
brownie run --network $NETWORK_ID scripts/deployment/deploy_safety_checks.py vault_safety_mode
brownie run --network $NETWORK_ID scripts/deployment/deploy_safety_checks.py reserve_safety_manager
brownie run --network $NETWORK_ID scripts/deployment/deploy_safety_checks.py register

# vaults
brownie run --network $NETWORK_ID scripts/deployment/deploy_static_percentage_fee_handler.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_vaults.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_vaults.py set_fees
