# Uppercent ERC1155 NFT Contract

**Smart Contract Documentation**

---

## **1. Introduction**

Welcome to the technical documentation for the UppercentNFTPass smart contract! This contract is designed to offer powerful features and flexibility for managing NFT passes with ERC1155 standards. It integrates various functionalities, including Ownable, Pausable, Burnable, Supply, and UUPS upgradeability.

## **2. Installation**

To set up the development environment, follow these steps:

```bash
# Install dependencies
npm install
```

## **Smart Contract Overview**

The **`UppercentNFTPass`** contract is an ERC1155-compatible smart contract with additional features. Let's delve into its functionality:

- **Token ID:** The contract supports a single token ID, fixed at '0'.
- **Contract Parameters:**
    - `_maxSupply`: Maximum supply of the token (e.g., 10,000).
    - `_mintPrice`: Standard minting price.
    - `_creator`: Address of the creator.
    - `_admin`: Address of the admin.
    - `_adminEarning`: Admin's earnings percentage.
    - `_creatorEarning`: Creator's earnings percentage.
    - `_userMintLimit`: Maximum minting limit per user (e.g., 10).
    - `_presaleMintPrice`: Minting price during presale.
    - `_presaleStartDate`: Start date of the presale window.
    - `_presaleEndDate`: End date of the presale window.
    - `_presaleMaxSupply`: Maximum supply for the presale.
    - `_presaleTotalSupply`: Total supply minted during the presale.
    - `_presaleCreated`: A flag indicating whether the presale has been created.

## **Testing**

### **Running Tests with Hardhat**

Execute the following command to run tests:

```bash
# run unit tests
npx hardhat test
```
### Result of unit tests

![App Screenshot](/assets/tests.png?raw=true "Result of unit tests")

## **Deployment**

To deploy the smart contract, including considerations for using a proxy, follow these steps:

1. Configure your deployment settings.
2. Execute the deployment script.

```bash
# Deploy contract
# Update parameters in scripts/deploy.js file
# It deploys with proxy
npx hardhat run scripts/deploy.js --network <NETWORK_NAME>
```

During deployment, the admin is required to set the following parameters:

- **`admin`**: Address of the admin/owner (e.g., 0xbef6149...).
- **`creator`**: Address of the creator (e.g. 0xc5eCcd2...).
- **`adminEarning`**: Percentage of earnings for the admin (e.g., 5).
- **`creatorEarning`**: Percentage of earnings for the creator (e.g., 5).
- **`uri`**: URI for metadata (e.g., ipfs://bafkreibxocxxlakbmd2nrllnpszhfzcwzry5jwdplfljpfeyjgeptnujlm).
- **`maxSupply`**: Maximum supply of the token (e.g., 10,000).
- **`mintPrice`**: Standard minting price (e.g., 2,000,000,000,000,000 [0.002 ETH]).
- **`userMintLimit`**: Maximum minting limit per user (e.g., 10).

## **Usage**

The contract provides various functions for interaction, such as:

- **Minting NFTs:** Users can mint NFTs using the **`mint`** function, respecting the maximum supply and user minting limit.
- **Presale Minting:** During the presale window, users can mint NFTs using the **`presaleMint`** function, with a discounted price. The admin can create a presale with limited supply, discounted minting price, start date, and end date. The presale can be closed manually by the admin or automatically at the end date.
- **Funds Release:** The owner can release and withdraw funds using the **`releaseFunds`** function, distributing earnings to the admin and creator based on the set percentages.

## **Security Considerations**

It's crucial to consider security when using this smart contract. Key considerations include:

- Ensuring proper configuration of minting conditions.
- Verifying presale parameters for correctness and security.
- Regularly auditing the contract for potential vulnerabilities.

## **Auditing Guidelines**

When auditing the contract, focus on the following areas:

- Review the implementation of minting and presale mechanisms.
- Ensure correct configuration of contract parameters.
- Check the logic for releasing funds to the admin and creator.

## **Contact Information**

For any questions, feedback, or bug reports, please contact the project maintainers:

# - Email: [pawan@novvr.com](mailto:pawan@novvr.com)
# - Email: [laxman@novvr.com](mailto:laxman@novvr.com)

## **License**

This smart contract is released under the MIT License. See the LICENSE file for more details.