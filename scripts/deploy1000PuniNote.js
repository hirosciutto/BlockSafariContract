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
  // Logicコントラクトをデプロイ
  const Nft = await hre.ethers.getContractFactory("OneThousandPuniNote");
  const nft = await Nft.deploy();
  await nft.deployed();
  console.log("NFT deployed to:", nft.address);

  // Proxyコントラクトデプロイ
  const ERC1967Proxy = await hre.ethers.getContractFactory("ERC1967Proxy");
  const data = Nft.interface.encodeFunctionData('initialize',[
    '0xD07f287f039078ECf443f182F6c218363e143a40', // coin contract
  ]);
  const erc1967Proxy = await ERC1967Proxy.deploy(
    nft.address,
    data);
  await erc1967Proxy.deployed();

  console.log("ERC1967Proxy deployed to:", erc1967Proxy.address);

  const myContractProxy = await ethers.getContractAt(
    'OneThousandPuniNote',
    erc1967Proxy.address,
  );

  const dataPath = path.join(__dirname, 'data', 'noteDataUrlS.txt');
  const imageData = fs.readFileSync(dataPath, 'utf8');

  const chunkSize = 10240; // チャンクサイズ（バイト単位）
  const totalChunks = Math.ceil(imageData.length / chunkSize);

  for (let i = 0; i < totalChunks; i++) {
    const chunkData = imageData.slice(i * chunkSize, (i + 1) * chunkSize);
    // const chunkBytes = hre.ethers.utils.hexlify(hre.ethers.utils.toUtf8Bytes(chunkData));
    // await myContractProxy.setImageChunk(i, chunkBytes);
    console.log(chunkData);
    await myContractProxy.setImageChunk(i, chunkData);
  }

  const svg = await myContractProxy.getSVG(0);

  console.log('Image upload complete' + svg);

  const name = await myContractProxy.name();
  const owner = await myContractProxy.owner();

  console.log('name is', name.toString());
  console.log('owner is', owner.toString());
  console.log('deployed:', erc1967Proxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);

});
