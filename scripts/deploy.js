// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

async function main() {

  const UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
  const uppercentNFTPass = await upgrades.deployProxy(UppercentNFTPass, [
    "0x9c760302031d1122b214c5869E526bFD57f04cF1", // owner
    10, // admin earning
    "testURI", // URI
    500, // maxSupply
    2, // mintPrice
    10, // per user mint limit
    160 // reservedSupply (previous course holders)
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
