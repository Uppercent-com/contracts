const {vars} = require("hardhat/config");

const API_URL = vars.get("API_URL");
const WALLET_KEY = vars.get("WALLET_KEY");
const CONTRACT_ADDRESS = "0xdC30eB044Dc9C7C367Dc82D1291Aa02ad114C2b6";

const contract = require("../artifacts/contracts/ComposerReceiverBlazeswap.sol/ComposerReceiverBlazeswap.json");

console.log(JSON.stringify(contract.abi));
const ethers = require("ethers");
const alchemyProvider = new ethers.providers.JsonRpcProvider(API_URL);
const signer = new ethers.Wallet(WALLET_KEY, alchemyProvider);
const composerReceiverBlazeswap = new ethers.Contract(CONTRACT_ADDRESS, contract.abi, signer);

async function main() {
	const result = await composerReceiverBlazeswap.adminWithdrawTokens("0xFbDa5F676cB37624f28265A144A48B0d6e87d3b6", 1000000);
	console.log("Funds released: ", result);
}
main();
