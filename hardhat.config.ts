import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-web3";
const fs = require("fs");

task('accounts', "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  console.log("An universal lover");
  for (const account of accounts) {
    console.log(account.address);
  }
});

task("deploy", "Deploys contract, get wallets, and outputs files", async (taskArgs, hre) => {
  const ethers = hre.ethers;
  const toN = (n: any)=>{return ethers.utils.parseUnits(n.toString(), 18)};

  //ASSET - GLP
  const GLP = await ethers.getContractFactory("Token");
  const glp = await GLP.deploy('USDC Token', 'USDC');
  await glp.deployed();
  console.log("GLP: ", glp.address);

  // Following are the asset tokens which each of the pools use
  // USDC
  const USDC = await ethers.getContractFactory("Token");
  const usdc = await USDC.deploy('USDC Token', 'USDC');
  await usdc.deployed();
  console.log("USDC: ", usdc.address);

  // Debt Ledger tokens
  //Debt Token for USDC
  const DOUSDC = await ethers.getContractFactory("DToken");
  const doUSDC = await DOUSDC.deploy('DOUSDC Token', 'doUSDC');
  await doUSDC.deployed();
  console.log("doUSDC: ", doUSDC.address);

  // Fund Ledger tokens
  //Fund Token for USDC
  const AUSDC = await ethers.getContractFactory("AToken");
  const aUSDC = await AUSDC.deploy('AUSDC Token', 'aUSDC');
  await aUSDC.deployed();
  console.log("aUSDC: ", aUSDC.address);

  // Rate Calculator 
  const RCL = await hre.ethers.getContractFactory("RateCalculator");
  const rcl = await RCL.deploy(toN(0.03), toN(0.03), toN(0.03), toN(0.8));
  await rcl.deployed();
  console.log("rcl: ", rcl.address);

  // Lending pool definitions
  // USDC Lending pool
  const LPUSDC = await ethers.getContractFactory("LendingPool");
  const pool = await LPUSDC.deploy(usdc.address, aUSDC.address, doUSDC.address, rcl.address);
  await pool.deployed();
  console.log("lpUSDC: ", pool.address);
 

  // Get generated signer wallets
  const accounts = await hre.ethers.getSigners();

  // Get the first wallet address
  const walletAddress = accounts[0].address;

  // Write file
  fs.writeFileSync('./.wallet', walletAddress);
});

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  settings: { optimizer: { enabled: true, runs: 500, }, },
  networks: {
    hardhat: {
      chainId: 1337
    }
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    noColors: false
  }
};

export default config;
