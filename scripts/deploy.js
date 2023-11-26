// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  //const [deployer] = await ethers.getSigners();

  //console.log("Deploying contracts with the account:", deployer.address);

  const UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
  const uppercentNFTPass = await upgrades.deployProxy(UppercentNFTPass, [
    "0xbef6149880......737D38844c", // owner
    "0xc5eCcd259C......139E4c315f", // creator
    5, // admin earning
    5, // creator earning
    "ipfs://bafkreibxocxxlakbmd2nrllnpszhfzcwzry5jwdplfljpfeyjgeptnujlm", // URI
    100, // maxSupply
    2000000000000000, // mintPrice
    10 // per user mint limit
  ], { initializer: "initialize" });

  await uppercentNFTPass.waitForDeployment();
  //await uppercentNFTPass.deployed();

  console.log("UppercentNFTPass deployed to:", uppercentNFTPass.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
