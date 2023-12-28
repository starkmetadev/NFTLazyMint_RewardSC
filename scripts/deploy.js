// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
require('dotenv').config();

async function main() {

  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const IconicReward = await hre.ethers.getContractFactory("IconicReward");
  const IconicNFT = await hre.ethers.getContractFactory("IconicNFT");
  const LuxuryReward = await hre.ethers.getContractFactory("LuxuryReward");
  const LuxuryNFT = await hre.ethers.getContractFactory("LuxuryNFT");
  
  
  const IconicNFTContract = await IconicNFT.deploy();
  console.log(`IconicNFT contract bought successfully at address: ${IconicNFTContract.address}`);
  const IconicRewardContract = await IconicReward.deploy(IconicNFTContract.address);
  console.log(`IconicReward contract bought successfully at address: ${IconicRewardContract.address}`);

  const LuxuryNFTContract = await LuxuryNFT.deploy();
  console.log(`LuxuryNFT contract bought successfully at address: ${LuxuryNFTContract.address}`);
  const LuxuryRewardContract = await LuxuryReward.deploy(LuxuryNFTContract.address);
  console.log(`LuxuryReward contract bought successfully at address: ${LuxuryRewardContract.address}`);
 
  const receipt = await IconicRewardContract.deployTransaction.wait();
  const receipt1 = await IconicNFTContract.deployTransaction.wait();
  const receipt2 = await LuxuryNFTContract.deployTransaction.wait();
  const receipt3 = await LuxuryRewardContract.deployTransaction.wait();

  const gasUsed = receipt2.gasUsed;
  const gasPrice = await hre.ethers.provider.getGasPrice(); // get the current gas price from the network
  const cost = gasUsed * gasPrice;
  console.log(`Gas used: ${gasUsed}`);
  console.log(`Gas price: ${gasPrice}`);
  console.log(`Deployment cost: ${cost / (10 ** 18)}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
