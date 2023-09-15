require("@nomicfoundation/hardhat-toolbox");
require("./tasks")
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks:{
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/kXCc0f--1HJ0NTmpPgY47WjTo7vX7roO",
      accounts: ["0fafc43dcbfccc6eae280c2988cad6066c2021f0f344c3f6b72c17a6c3a87a93"]
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "318ZR9QTHRPKXSDIKSSUEAB35JU5W1M25Q"
  }
};
