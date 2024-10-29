const { ethers, upgrades } = require("hardhat");

async function main() {
  const PROXY_ADDRESS = "0xa22270354919793ab650639101D9563741239376";

  const UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
  const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, UppercentNFTPass);

  await upgraded.waitForDeployment();
  
  console.log("UppercentNFTPass upgraded at:", await upgraded.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
