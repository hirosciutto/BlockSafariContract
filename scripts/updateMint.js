// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const NewImplementation = await hre.ethers.getContractFactory("Mint");
  const newImplementation = await NewImplementation.deploy();
  await newImplementation.deployed();

  const Proxy = await hre.ethers.getContractFactory("Mint");
  const proxy = await Proxy.attach("0xDAc65c459A19eF2a233E5c7EEb523515126D26C2");
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
