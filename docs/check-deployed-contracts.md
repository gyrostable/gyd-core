# How to check contract deployment parameters on-chain

We've deployed a bunch of contracts, now we want to check they are deployed with the right parameters.

# Setup and initialize
1. Go to `protocol/` repo, `deployment` branch
2. Prepare `.env` with the following content:
```
export WEB3_INFURA_PROJECT_ID=83f0fe2243ca4c6badffe8676f61786a
```
3. `$ source .env`
4. `$ brownie console --network=mainnet` (connects to mainnet and gives you a console)
5. `>>> from scripts.lib_deployment_verification import *` (import Steffen's library)

# Dealing with Proxy Contracts
For (upgradable) proxy contracts, use the following to check the correct wiring of the proxy to implementation/admin:

```python
print_proxy_data("0x..." (proxy address))
```

This behaves differently for some contracts than for others. Idk why, prob ask Daniel when he's back. (are these contracts that have been upgraded??)

## Calling into Proxy Contracts

Use
```python
c = proxied_contract("0x..." (proxy address))
```

FYI this performs a case distinction based on the above different behavior:
1. self has name `FreezableTransparentUpgradeableProxy` -> Instantiates the proxy using the abi from the implementation.
2. self has some other name (of our actual contracts) -> Just use the proxy object.

# Checking public members / view fcts

Once you've set up your proxied contract, you can just call `c.someViewFunction()`. To get all zero-argument view functions / members, use:

```python
print_all_field_views(c)
```

This is semi-useful for entries that are strings (which will be printed as bytes). You can call `.decode()` (and strip null bytes) to get these entries, e.g. for c = AssetRegistry:

```python
>>> [v.decode().rstrip('\x00') for v in c.getRegisteredAssetNames()]
["ETH", "WETH", "DAI", "WBTC", "USDC", "USDT", "USDP", "GUSD", "LUSD", "crvUSD"]
```

# Checking private/protected variables

To check private and protected members, I'm not sure what to do tbh. Their slots *can* be pulled but I'm not sure how to relate this to member variables in a reliable way.

# Checking private/protected immutable variables

Not sure either. The value is rolled into the bytecode so there wouldn't even be a slot to check.

Perhaps it's better to check constructor arguments here.
- We can get the deploying tx on etherscan but can we then take & decode that tx using the info (ABI) we have locally?