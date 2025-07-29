require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks:{
  sepolia: {
  url: "https://sepolia.infura.io/v3/My_First_Key",
  accounts: [
    process.env.PRIVATE_KEY
  ],
  chainId: 1337,
 }
  }
};
