const { ethers } = require("hardhat");

async function main() {
  // Get the contract factory for ComposerReceiverBlazeswap
  const ComposerReceiverBlazeswap = await ethers.getContractFactory("ComposerReceiverBlazeswap");

  // Deploy the contract with constructor arguments
  const composerReceiverBlazeswap = await ComposerReceiverBlazeswap.deploy(
    "0xe3A1b355ca63abCBC9589334B5e609583C7BAa06", // BlazeSwap router address
    "0x1a44076050125825900e736c501f859c50fE728c", // LayerZero endpoint
    ["0x8e8539e4CcD69123c623a106773F2b0cbbc58746", "0x77C71633C34C3784ede189d74223122422492a0f", "0x1C10CC06DC6D35970d1D53B2A23c76ef370d4135"]  // Stargate address
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
