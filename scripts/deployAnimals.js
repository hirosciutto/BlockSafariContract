// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  // Logicコントラクトをデプロイ
  const Sales = await hre.ethers.getContractFactory("Sales");
  const sales = await Sales.deploy();
  await sales.deployed();
  console.log("Sales deployed to:", sales.address);

  // Proxyコントラクトデプロイ
  const ERC1967Proxy = await hre.ethers.getContractFactory("BlockSafari");
  const data = Sales.interface.encodeFunctionData('initialize',[
    'ANIMALS',
    'ANIMALS',
    'https://blocksafari.online/img/data/ANIMALS'
  ]);
  const erc1967Proxy = await ERC1967Proxy.deploy(
    sales.address,
    data);
  await erc1967Proxy.deployed();

  console.log("ERC1967Proxy deployed to:", erc1967Proxy.address);

  const myContractProxy = await ethers.getContractAt(
    'Sales',
    erc1967Proxy.address,
  );
  const name = await myContractProxy.name();
  console.log('name is', name.toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);

});
