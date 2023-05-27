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
  const Proxy = await hre.ethers.getContractFactory("OneMillionPuniNote");
  const proxy = await Proxy.attach("0x2269bD05cb73809C5e3Aa0bFE3CdFF60c31B5853");

  const dataPath = path.join(__dirname, 'data', 'noteDataUrlS.txt');
  const imageData = fs.readFileSync(dataPath, 'utf8');

  const chunkSize = 10240; // チャンクサイズ（バイト単位）
  const totalChunks = Math.ceil(imageData.length / chunkSize);

  for (let i = 0; i < totalChunks; i++) {
    const chunkData = imageData.slice(i * chunkSize, (i + 1) * chunkSize);
    await proxy.setImageChunk(i, chunkData);
  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);

});
