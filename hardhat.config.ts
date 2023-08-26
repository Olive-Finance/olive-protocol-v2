import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-web3";
import { utils } from "ethers";
import { vault } from "./typechain-types/contracts";
require("hardhat-contract-sizer");
const fs = require("fs");

task('accounts', "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    console.log(account.address);
  }
});

task("deploy", "Deploys contract, get wallets, and outputs files", async (taskArgs, hre) => {
  const ethers = hre.ethers;
  const toN = (n: any)=>{return ethers.utils.parseUnits(n.toString(), 18)};

  // Get generated signer wallets
  const accounts = await hre.ethers.getSigners();

  // Get the first wallet address
  const owner = accounts[0];
  const u1 = accounts[1];

  //ASSET - GLP
  const GLP = await ethers.getContractFactory("Token");
  const glp = await GLP.deploy('USDC Token', 'USDC', 18);
  await glp.deployed();
  console.log("GLP: ", glp.address);

  // Following are the asset tokens which each of the pools use
  // USDC
  const USDC = await ethers.getContractFactory("Token");
  const usdc = await USDC.deploy('USDC Token', 'USDC', 6);
  await usdc.deployed();
  console.log("USDC: ", usdc.address);

  // Debt Ledger tokens
  //Debt Token for USDC
  const DOUSDC = await ethers.getContractFactory("DToken");
  const doUSDC = await DOUSDC.deploy('DOUSDC Token', 'doUSDC', 6);
  await doUSDC.deployed();
  console.log("doUSDC: ", doUSDC.address);

  // Fund Ledger tokens
  //Fund Token for USDC
  const AUSDC = await ethers.getContractFactory("AToken");
  const aUSDC = await AUSDC.deploy('AUSDC Token', 'aUSDC', 6);
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
  const pool = await LPUSDC.deploy(aUSDC.address, doUSDC.address, usdc.address, rcl.address);
  await pool.deployed();
  console.log("lpUSDC: ", pool.address);

  // Vault tokens
  const OToken = await ethers.getContractFactory("OToken");
  const oGLP = await OToken.deploy('OGLP Token', 'oGLP');
  await oGLP.deployed();
  console.log("oGLP: ", oGLP.address);

  const soGLP = await AUSDC.deploy('SOGLP Token', 'soGLP', 18);
  await soGLP.deployed();
  console.log("soGLP: ", soGLP.address);

  const GLPVault = await ethers.getContractFactory("GLPVault");
  const glpVault = await GLPVault.deploy();
  await glpVault.deployed();
  console.log("GLPVault: ", glpVault.address);

  const VaultManager = await ethers.getContractFactory("VaultManager");
  const vaultManager = await VaultManager.deploy();
  await vaultManager.deployed();
  console.log("VaultManager: ", vaultManager.address);

  const Strategy = await ethers.getContractFactory("Strategy");
  const strategy = await Strategy.deploy(glp.address, soGLP.address);
  await strategy.deployed();
  console.log("Strategy: ", strategy.address);

  const GLPMock = await ethers.getContractFactory("GLPMock");
  const glpMock = await GLPMock.deploy(glp.address);
  await glpMock.deployed();
  console.log("GLPMock: ", glpMock.address);

  const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
  const phMock = await PriceHelperMock.deploy();
  await phMock.deployed();
  console.log("PriceHelperMock: ", phMock.address);

  await vaultManager.setVaultCore(glpVault.address);
  await glpVault.setRewardsRouter(glpMock.address);
  await glpVault.setVaultManager(vaultManager.address);
  await glpVault.setTreasury(owner.address);
  await glpVault.setLendingPool(pool.address);
  await glpVault.setLeverage(utils.parseUnits("5", 18));
  await glpVault.setPriceHelper(phMock.address);
  await glpVault.setTokens(glp.address, oGLP.address, soGLP.address);
  await glpVault.setStrategy(strategy.address);
  await oGLP.grantRole(glpVault.address);
  await aUSDC.grantRole(pool.address);
  await doUSDC.grantRole(pool.address);
  await pool.grantRole(vaultManager.address);
  await glp.grantRole(glpMock.address);


  await glp.mint(u1.address, ethers.utils.parseUnits('10000', 18));
  await usdc.mint(owner.address, ethers.utils.parseUnits('10000', 6));
  await usdc.connect(owner).approve(pool.address, ethers.utils.parseUnits('10000', 26));
  await pool.connect(owner).supply(ethers.utils.parseUnits('10000', 6));
  await glp.connect(u1).approve(vaultManager.address, ethers.utils.parseUnits('10000', 26));
  await strategy.connect(owner).setHandler(glpVault.address, vaultManager.address, true);

  // Write file
  fs.writeFileSync('./.wallet', owner.address);

  // Mainnet testing contract addresses
  // https://arbiscan.io/address/0xb95db5b167d75e6d04227cfffa61069348d271f5

  // Mainnet Token Addresses
  // 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 - wETH
  // 0x1aDDD80E6039594eE970E5872D247bf0414C8903 - fsGLP
  // 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8 - Bridge USDC
  // 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf - sGLP / GLP
  
  // GLP Contracts
  // 0xB95DB5B167D75e6d04227CfFFA61069348d271F5 - RewardsRouter - For buying
  // 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1 - RewardsRouter - For rewards
  // 0x3963FfC9dff443c2A94f21b129D429891E32ec18 - glpManager
  
  // Chainlink Addresses
  // 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612 - ETH/USD Price Feed
  // 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3 - USDC/USC Price Feed
  // 0xFdB631F5EE196F0ed6FAa767959853A9F217697D - Arb One sequencer
  // 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8 - ARB Sequencer

  // Deployed OliveContracts
  // 0x326dBD1595473ddE549d15D129b226382cf267Ac - PriceHelper
  // 0x6aCC55166BFAF187ca752F2739b9965A13Ce1B70 - glpVault / VaultCore
  // 0xE6d40c6f8E9C22178961776ca9a18ED075714Bf9 - Strategy
});

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  settings: { optimizer: { enabled: true, runs: 500 } },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    polytest: {
      url: "https://rpc-mumbai.maticvigil.com/",
      chainId: 80001,
    },
    arbtest: {
      url: "https://arbitrum-goerli.publicnode.com",
      chainId: 421613,
    },
    arbmain: {
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
    }
  },
  gasReporter: {
    enabled: true,
    currency: "USD", // currency to show
    noColors: false,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    unit: "kB",
  },
};

export default config;
