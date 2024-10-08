const {vars} = require("hardhat/config");

const API_URL = vars.get("API_URL");
const WALLET_KEY = vars.get("WALLET_KEY");
const CONTRACT_ADDRESS = "0xF57e07f9265a1e46440BCd7c5Cd73D92978EF699";

const contract = require("../artifacts/contracts/UppercentNFTPass.sol/UppercentNFTPass.json");

console.log(JSON.stringify(contract.abi));
const ethers = require("ethers");
const alchemyProvider = new ethers.JsonRpcProvider(API_URL);
const signer = new ethers.Wallet(WALLET_KEY, alchemyProvider);
const uppercentERC1155 = new ethers.Contract(CONTRACT_ADDRESS, contract.abi, signer);

async function main() {
	const result = await uppercentERC1155.createPresale(1, 1727959200, 1728122400);
	console.log("Presale created: ", result);
}
main();
