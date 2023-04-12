// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // Logicコントラクトをデプロイ
  const Logic = await hre.ethers.getContractFactory("Market");
  const logicContract = await Logic.deploy();
  await logicContract.deployed();
  console.log("Market deployed to:", logicContract.address);

  // Proxyコントラクトデプロイ
  const ERC1967Proxy = await hre.ethers.getContractFactory("BlockSafariMarket");
  const data = Logic.interface.encodeFunctionData('initialize',[]);
  const erc1967Proxy = await ERC1967Proxy.deploy(logicContract.address, data);
  await erc1967Proxy.deployed();

  console.log("ERC1967Proxy deployed to:", erc1967Proxy.address);

  // 第一引数にコントラクト名
  const myContractProxy = await ethers.getContractAt(
    'Market',
    erc1967Proxy.address,
  );
  const owner = await myContractProxy.owner();
  console.log('owner is', owner.toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);

});
