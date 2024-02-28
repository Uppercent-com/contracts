// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

async function main() {

  const UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
  const uppercentNFTPass = await upgrades.deployProxy(UppercentNFTPass, [
    "0x6d83a02868e18aE66AD5793F7DFc26d65f59c3C4", // owner
    "0x55B12b8F15AD19655426A9F619C3C7672B32644A", // creator
    90, // admin earning
    10, // creator earning
    "ipfs://bafkreieyh5wqty73xr3mjhkxev2p2yv5hifazxrki67hdess223fsxnmj4", // URI
    1000, // maxSupply
    5, // mintPrice
    10 // per user mint limit
  ], { initializer: "initialize" });

  await uppercentNFTPass.waitForDeployment();

  console.log("UppercentNFTPass deployed to:", await uppercentNFTPass.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
