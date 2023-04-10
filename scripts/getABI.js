const { artifacts } = require("hardhat");

async function main() {
  const NftContract = artifacts.require("ERC721Wrapper");
  const nftContract = await NftContract.new();

  console.log("ERC721Wrapper:", nftContract.abi);

  const MethodsContract = artifacts.require("Methods");
  const methodsContract = await MethodsContract.new();

  console.log("Methods:", methodsContract.abi);
}

main();