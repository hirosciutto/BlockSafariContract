require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-gas-reporter");
require('dotenv').config();
const { mnemonic, REPORT_GAS, COINMARKETCAP_API_KEY } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  gasReporter: {
    enabled: REPORT_GAS ? true : false,
    currency: "MATIC",
    gasPriceApi:
      "https://api-testnet.polygonscan.com/api?module=proxy&action=eth_gasPrice",
    coinmarketcap: COINMARKETCAP_API_KEY,
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    }
  },
  networks: {
    hardhat: {},
    // goerli: {
    //   url: "https://eth-goerli.g.alchemy.com/v2/"+process.env.GOERLI_API_KEY,
    //   chainId: 5,
    //   accounts: { mnemonic },
    // },
    // mainnet: {
    //   url: "https://eth-mainnet.g.alchemy.com/v2/"+process.env.MAINNET_API_KEY,
    //   chainId: 1,
    //   accounts: { mnemonic }
    // },
    mumbai: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/"+process.env.GOERLI_API_KEY,
      chainId: 80001,
      accounts: { mnemonic },
    },
    polygon: {
      url: "https://polygon-mainnet.g.alchemy.com/v2/"+process.env.MAINNET_API_KEY,
      chainId: 137,
      accounts: { mnemonic }
    }
  },
  etherscan: {
    apiKey: process.env.ETHESCAN_API_KEY
  }
};