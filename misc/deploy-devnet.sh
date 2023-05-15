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


brownie run --network $NETWORK_ID scripts/deployment/deploy_proxy_admin.py

brownie run --network $NETWORK_ID scripts/deployment/deploy_governance_proxy.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_governance_proxy.py proxy

brownie run --network $NETWORK_ID scripts/deployment/deploy_config.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_config.py proxy
brownie run --network $NETWORK_ID scripts/deployment/deploy_config.py set_initial_config

brownie run --network $NETWORK_ID scripts/deployment/deploy_cap_authentication.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_cap_authentication.py proxy

brownie run --network $NETWORK_ID scripts/deployment/deploy_vault_registry.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_vault_registry.py proxy

brownie run --network $NETWORK_ID scripts/deployment/deploy_asset_registry.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_asset_registry.py proxy
brownie run --network $NETWORK_ID scripts/deployment/deploy_asset_registry.py initialize

brownie run --network $NETWORK_ID scripts/deployment/deploy_reserve.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_reserve.py proxy

# does not hold any state so no need for proxy, `setAddress` is enough
brownie run --network $NETWORK_ID scripts/deployment/deploy_reserve_manager.py

# does not hold any state so no need for proxy, `setAddress` is enough
brownie run --network $NETWORK_ID scripts/deployment/deploy_pamm.py

brownie run --network $NETWORK_ID scripts/deployment/deploy_gyd_token.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_gyd_token.py proxy

if [ "$LIVE" != "true" ]; then
    brownie run --network $NETWORK_ID scripts/deployment/deploy_mock_price_oracle.py
fi

# oracles can be replaced without needing to be upgraded
brownie run --network $NETWORK_ID scripts/deployment/deploy_chainlink_price_oracle.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_chainlink_price_oracle.py set_feeds

# oracles
brownie run --network $NETWORK_ID scripts/deployment/deploy_coinbase_oracle.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_checked_price_oracle.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_checked_price_oracle.py initialize
brownie run --network $NETWORK_ID scripts/deployment/deploy_vault_price_oracle.py generic
brownie run --network $NETWORK_ID scripts/deployment/deploy_vault_price_oracle.py cpmm
brownie run --network $NETWORK_ID scripts/deployment/deploy_vault_price_oracle.py g2clp
brownie run --network $NETWORK_ID scripts/deployment/deploy_vault_price_oracle.py g3clp
brownie run --network $NETWORK_ID scripts/deployment/deploy_vault_price_oracle.py eclp
brownie run --network $NETWORK_ID scripts/deployment/deploy_batch_vault_price_oracle.py 
brownie run --network $NETWORK_ID scripts/deployment/deploy_batch_vault_price_oracle.py initialize

# safety checks
brownie run --network $NETWORK_ID scripts/deployment/deploy_safety_checks.py root
brownie run --network $NETWORK_ID scripts/deployment/deploy_safety_checks.py vault_safety_mode
brownie run --network $NETWORK_ID scripts/deployment/deploy_safety_checks.py reserve_safety_manager
brownie run --network $NETWORK_ID scripts/deployment/deploy_safety_checks.py register

# vaults
brownie run --network $NETWORK_ID scripts/deployment/deploy_static_percentage_fee_handler.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_test_vaults.py
brownie run --network $NETWORK_ID scripts/deployment/deploy_test_vaults.py set_fees
brownie run --network $NETWORK_ID scripts/deployment/deploy_test_vaults.py register_vaults

# motherboard
brownie run --network $NETWORK_ID scripts/deployment/deploy_motherboard.py
