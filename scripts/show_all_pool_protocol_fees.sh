#!/user/bin/env sh

show_pool_fees()
{
    desc="$1"
    gyroconfig_address="$2"
    pool_address="$3"
    pool_type="$4"
    network="$5"
    echo "-------------------------------------------------------------"
    echo "$desc = $pool_address\n"
    brownie run scripts/read_gyroconfig_pool_params.py main "$gyroconfig_address" "$pool_address" "$pool_type" --network="$network"
    echo
}

show_pool_fees "Mainnet ECLP R / sDAI" 0xaC89cc9d78BBAd7EB3a02601B4D65dAa1f908aA6 0x52b69d6b3eB0BD6b2b4A48a316Dfb0e1460E67E4 ECLP mainnet
show_pool_fees "Mainnnet ECLP wstETH / cbETH" 0xaC89cc9d78BBAd7EB3a02601B4D65dAa1f908aA6 0xF7A826D47c8E02835D94fb0Aa40F0cC9505cb134 ECLP mainnet
show_pool_fees "Mainnnet ECLP wstETH / WETH" 0xaC89cc9d78BBAd7EB3a02601B4D65dAa1f908aA6 0xf01b0684C98CD7aDA480BFDF6e43876422fa1Fc1 ECLP mainnet
show_pool_fees "Mainnnet ECLP wstETH / swETH" 0xaC89cc9d78BBAd7EB3a02601B4D65dAa1f908aA6 0xe0E8AC08De6708603cFd3D23B613d2f80e3b7afB ECLP mainnet
show_pool_fees "Mainnnet ECLP wstETH / swETH" 0xaC89cc9d78BBAd7EB3a02601B4D65dAa1f908aA6 0xe0E8AC08De6708603cFd3D23B613d2f80e3b7afB ECLP mainnet

show_pool_fees "Optimism ECLP wstETH / WETH" 0x32Acb44fC929339b9F16F0449525cC590D2a23F3 0x7Ca75bdEa9dEde97F8B13C6641B768650CB83782 ECLP optimism-main

show_pool_fees "Polygon ECLP WMATIC / MaticX" 0xfdc2e9e03f515804744a40d0f8d25c16e93fbe67 0xeE278d943584dd8640eaf4cc6c7a5C80c0073E85 ECLP polygon-main
show_pool_fees "Polygon 2CLP USDC / DAI" 0xfdc2e9e03f515804744a40d0f8d25c16e93fbe67 0xdAC42eeb17758Daa38CAF9A3540c808247527aE3 2CLP polygon-main
show_pool_fees "Polygon ECLP WMATIC / stMATIC" 0xfdc2e9e03f515804744a40d0f8d25c16e93fbe67 0xf0ad209e2e969EAAA8C882aac71f02D8a047d5c2 ECLP polygon-main
show_pool_fees "Polygon 3CLP USDC / BUSD / USDT" 0xfdc2e9e03f515804744a40d0f8d25c16e93fbe67 0x17f1Ef81707811eA15d9eE7c741179bbE2A63887 3CLP polygon-main
show_pool_fees "Polygon ECLP WBTC / WETH" 0xfdc2e9e03f515804744a40d0f8d25c16e93fbe67 0xFA9Ee04a5545D8e0a26B30F5cA5CbecD75eA645F ECLP polygon-main
show_pool_fees "Polygon ECLP USDC / TUSD" 0xfdc2e9e03f515804744a40d0f8d25c16e93fbe67 0x97469E6236bD467cd147065f77752b00EfadCe8a ECLP polygon-main

show_pool_fees "Arbitrum ECLP USDC / USDT" 0x9b683ca24b0e013512e2566b68704dbe9677413c 0xb6911f80B1122f41C19B299a69dCa07100452bf9 ECLP arbitrum-main

