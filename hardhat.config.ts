import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.19",
  networks: {
    hardhat: {
      chainId: 1337,
      accounts: {
        count: 30,
        mnemonic: process.env.MNEMONIC,
        path: "m/44'/60'/0'/0",
      },
    },
  },
};

export default config;
