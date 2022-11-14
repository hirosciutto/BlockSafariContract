require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
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
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2/"+process.env.GOERLI_API_KEY,
      chainId: 5,
      accounts: { mnemonic },
    },
    mainnet: {
      url: "https://eth-mainnet.g.alchemy.com/v2/"+process.env.MAINNET_API_KEY,
      chainId: 1,
      accounts: { mnemonic }
    }
  },
  etherscan: {
    apiKey: process.env.ETHESCAN_API_KEY
  }
};