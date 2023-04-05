// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // Logicコントラクトをデプロイ
  const Methods = await hre.ethers.getContractFactory("Methods");
  const methods = await Methods.deploy();
  await methods.deployed();
  console.log("Methods deployed to:", methods.address);

  // Proxyコントラクトデプロイ
  const ERC1967Proxy = await hre.ethers.getContractFactory("BlockSafari");
  const data = Methods.interface.encodeFunctionData('initialize',[]);
  const erc1967Proxy = await ERC1967Proxy.deploy(methods.address, data);
  await erc1967Proxy.deployed();

  console.log("ERC1967Proxy deployed to:", erc1967Proxy.address);

  // 第一引数にコントラクト名
  const myContractProxy = await ethers.getContractAt(
    'Methods',
    erc1967Proxy.address,
  );
  // const name = await myContractProxy.name();
  // const implementation = await myContractProxy.implementation();
  // console.log('name is', name.toString());
  // console.log('implementation is', implementation.toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);

});
