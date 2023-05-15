import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
const fs = require("fs");

task('accounts', "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  console.log("An universal lover");
  for (const account of accounts) {
    console.log(account.address);
  }
});

task("deploy", "Deploys contract, get wallets, and outputs files", async (taskArgs, hre) => {
  // ASSET
  const USDC = await hre.ethers.getContractFactory("USDC");
  const usdc = await USDC.deploy('USDC Token', 'USDC', 8);
  await usdc.deployed();
  console.log("USDC: ", usdc.address);

  //A Token for Olive valut reciepts
  const AOToken = await hre.ethers.getContractFactory("AOToken");
  const aoToken = await AOToken.deploy('AOUSDC Token', 'aoUSDC', 8);
  await aoToken.deployed();
  console.log("aoUSDC: ", aoToken.address);
  
  //D Token for ASSET
  const DOToken = await hre.ethers.getContractFactory("DOToken");
  const doToken = await DOToken.deploy('DOUSDC Token', 'dUSDC', 8);
  await doToken.deployed();
  console.log("doUSDC: ", doToken.address);

  //O Token for Olive valut deposits
  const OToken = await hre.ethers.getContractFactory("OToken");
  const oToken = await OToken.deploy('OUSDC Token', 'oUSDC', 8);
  await oToken.deployed();
  console.log("oToken: ", oToken.address);

  //A Token for Olive valut reciepts
  const AToken = await hre.ethers.getContractFactory("AToken");
  const aToken = await AToken.deploy('AUSDC Token', 'aUSDC', 8);
  await aToken.deployed();
  console.log("aToken: ", aToken.address);

  //LP Token for Olive valut reciepts
  const LPToken = await hre.ethers.getContractFactory("LPToken");
  const lpToken = await LPToken.deploy('LPUSDC Token', 'lpUSDC', 8);
  await lpToken.deployed();
  console.log("lpToken: ", lpToken.address);

  // Lending pool initialization
  const LPool = await hre.ethers.getContractFactory("Pool");
  const lpool = await LPool.deploy(
    usdc.address,
    aToken.address,
    doToken.address,
    oToken.address,
    aoToken.address,
     );
  await lpool.deployed();
  console.log("pool: ", lpool.address);

  // Strategy initialization
  const Strategy = await hre.ethers.getContractFactory("Strategy");
  const strategy = await Strategy.deploy(
    usdc.address,
    lpToken.address,
    '0x3528942Bf01874cB51A79ac32E3FC839Ae2a1367',
  );
  await strategy.deployed();
  console.log("strategy: ", strategy.address);

  // Olive initialization
  const Olive = await hre.ethers.getContractFactory("OliveV2");
  const olive = await Olive.deploy(
    usdc.address,
    oToken.address,
    strategy.address,
    lpool.address,
    aoToken.address,
    doToken.address,
  );

  await olive.deployed()
  console.log("olive: ", olive.address);

  // Get generated signer wallets
  const accounts = await hre.ethers.getSigners();

  // Get the first wallet address
  const walletAddress = accounts[0].address;

  // Write file
  fs.writeFileSync('./.wallet', walletAddress);
});

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    hardhat: {
      chainId: 1337
    },
  }
};

export default config;
