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

//npx hardhat deploy --account tests --network sepolia
//npx hardhat verify --network sepolia --constructor-args arguments.js 0x8849Db5A8046f8AaFCEE172Af231B0f229187843

//npx hardhat deploy --account testt --network localhost
//npx hardhat contribute --crowdfunding testtt --network localhost

//The addres that I've already deployed the contract with the "deploy task"
//npx hardhat contribute2 --crowdfunding 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 --network localhost