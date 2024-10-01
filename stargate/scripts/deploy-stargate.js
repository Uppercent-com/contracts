const { ethers } = require("hardhat");

async function main() {
  // Get the contract factory for ComposerReceiverBlazeswap
  const ComposerReceiverBlazeswap = await ethers.getContractFactory("ComposerReceiverBlazeswap");

  // Deploy the contract with constructor arguments
  const composerReceiverBlazeswap = await ComposerReceiverBlazeswap.deploy(
    "0xe3A1b355ca63abCBC9589334B5e609583C7BAa06", // BlazeSwap router address
    "0x1a44076050125825900e736c501f859c50fE728c", // LayerZero endpoint
    "0x45d417612e177672958dC0537C45a8f8d754Ac2E"  // Stargate address
  );

  // Wait for the deployment to be mined
  await composerReceiverBlazeswap.waitForDeployment();

  // Log the deployed contract address
  console.log("ComposerReceiverBlazeswap deployed to:", await composerReceiverBlazeswap.getAddress());
}

// Execute the deploy script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
