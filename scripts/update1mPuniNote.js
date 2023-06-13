// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {
  const NewImplementation = await hre.ethers.getContractFactory("OneMillionPuniNote");
  const newImplementation = await NewImplementation.deploy();
  await newImplementation.deployed();

  const Proxy = await hre.ethers.getContractFactory("OneMillionPuniNote");
  const proxy = await Proxy.attach("0xE90E33E1A3865344c174622aC93926C958249F0C");
  await proxy.upgradeTo(newImplementation.address);

  console.log('upgrade complete', newImplementation.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);

});
