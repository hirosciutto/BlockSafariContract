// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const NewImplementation = await hre.ethers.getContractFactory("Animals");
  const newImplementation = await NewImplementation.deploy();
  await newImplementation.deployed();

  const Proxy = await hre.ethers.getContractFactory("Animals");
  const proxy = await Proxy.attach(
    "0x21b63e7CBcaf264e4058854506c2E8f2E2D46EA5" // mumbai
  );
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
