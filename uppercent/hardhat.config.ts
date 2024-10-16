import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

const privateKey = vars.get("WALLET_KEY");

const config: HardhatUserConfig = {
  networks: {
    coston: {
      url: "https://coston-api.flare.network/ext/bc/C/rpc",
      accounts: [privateKey],
      chainId: 16,
    },
    coston2: {
      url: "https://coston2-api.flare.network/ext/bc/C/rpc",
      accounts: [privateKey],
      chainId: 114,
    },
    songbird: {
      url: "https://songbird-api.flare.network/ext/bc/C/rpc",
      accounts: [privateKey],
      chainId: 19,
    },
    flare: {
      url: "https://flare-api.flare.network/ext/C/rpc?x-apikey=4c56de23-853c-478b-83a6-dafb3ab0f44e",
      accounts: [privateKey],
      chainId: 14,
    },
    polygon_mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [privateKey],
    },
    hardhat: {
      forking: {
        url: "https://flare-api.flare.network/ext/C/rpc?x-apikey=4c56de23-853c-478b-83a6-dafb3ab0f44e",
      },
    },
  },
  etherscan: {
    apiKey: {
      songbird: "api-key",
      flare: "4c56de23-853c-478b-83a6-dafb3ab0f44e",
    },
    customChains: [
      {
        network: "songbird",
        chainId: 19,
        urls: {
          apiURL: "https://songbird-explorer.flare.network/api",
          browserURL: "https://songbird-explorer.flare.network/",
        },
      },
      {
        network: "flare",
        chainId: 14,
        urls: {
          apiURL: "https://flare-explorer.flare.network/api",
          browserURL: "https://flare-explorer.flare.network/",
        },
      },
    ],
  },
  sourcify: {
    enabled: true,
    apiUrl: "https://sourcify.dev/server",
    browserUrl: "https://repo.sourcify.dev",
  },
  solidity: {
    version: "0.8.20",
    settings: {
      evmVersion: "london",
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};

export default config;
