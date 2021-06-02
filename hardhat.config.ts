import "@nomiclabs/hardhat-waffle";
import "hardhat-deploy";
import "hardhat-typechain";
import { HardhatUserConfig } from "hardhat/config";

require("dotenv").config();

export const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID;
export const INFURA_PROJECT_SECRET = process.env.INFURA_PROJECT_SECRET;
const KOVAN_PRIVATE_KEY = process.env.KOVAN_PRIVATE_KEY;

export const KOVAN_INFURA_PROJECT_ID = process.env.KOVAN_INFURA_PROJECT_ID;
export const KOVAN_INFURA_PROJECT_SECRET = process.env.KOVAN_INFURA_PROJECT_SECRET;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      evmVersion: "istanbul",
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    kovan: {
      url: `https://:${KOVAN_INFURA_PROJECT_SECRET}@kovan.infura.io/v3/${KOVAN_INFURA_PROJECT_ID}`,
      accounts: KOVAN_PRIVATE_KEY ? [KOVAN_PRIVATE_KEY] : [],
      live: true,
    },
  },
};
export default config;
