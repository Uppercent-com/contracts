// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

async function main() {

  const UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
  const uppercentNFTPass = await upgrades.deployProxy(UppercentNFTPass, [
    "0xB47FbC5E6996F6766C4860b360e883dD22Cd4f9a", // owner
    "0x55B12b8F15AD19655426A9F619C3C7672B32644A", // creator
    5, // admin earning
    5, // creator earning
    "ipfs://bafkreibxocxxlakbmd2nrllnpszhfzcwzry5jwdplfljpfeyjgeptnujlm", // URI
    10000, // maxSupply
    4000000000000000000n, // mintPrice
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
