require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

const { infuraKey, privateKey } = require('./credentials.json');

module.exports = {
  networks: {
    coston: {
      url: "https://coston-api.flare.network/ext/bc/C/rpc",
      accounts: [privateKey],
      chainId: 16
    },
    songbird: {
      url: "https://songbird-api.flare.network/ext/bc/C/rpc",
      accounts: [privateKey],
      chainId: 19
    },
    flare: {
      url: "https://flare-api.flare.network/ext/bc/C/rpc",
      accounts: [privateKey],
      chainId: 14,
    },
    polygon_mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [privateKey]
    }
  },
  solidity: {
    version: "0.8.20",
    settings: {
      evmVersion: "london",
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
};