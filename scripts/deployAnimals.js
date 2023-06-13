// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // Logicコントラクトをデプロイ
  const Nft = await hre.ethers.getContractFactory("Animals");
  const nft = await Nft.deploy();
  await nft.deployed();
  console.log("NFT deployed to:", nft.address);

  // Proxyコントラクトデプロイ
  const ERC1967Proxy = await hre.ethers.getContractFactory("ERC1967Proxy");
  const data = Nft.interface.encodeFunctionData('initialize',[
    'ANIMALS',
    'ANIMALS',
    // 'https://dev.blocksafari.org/storage/data/'
    'http://localhost:8092/storage/data/'
  ]);
  const erc1967Proxy = await ERC1967Proxy.deploy(
    nft.address,
    data);
  await erc1967Proxy.deployed();

  console.log("ERC1967Proxy deployed to:", erc1967Proxy.address);

  const myContractProxy = await ethers.getContractAt(
    'Animals',
    erc1967Proxy.address,
  );
  const name = await myContractProxy.name();
  const owner = await myContractProxy.owner();
  console.log('name is', name.toString());
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
