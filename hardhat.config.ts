import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-web3";
import { utils } from "ethers";
require("hardhat-contract-sizer");
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
  const pool = await LPUSDC.deploy(aUSDC.address, doUSDC.address, usdc.address, rcl.address);
  await pool.deployed();
  console.log("lpUSDC: ", pool.address);

  // Vault tokens
  const OToken = await ethers.getContractFactory("OToken");
  const oGLP = await OToken.deploy('OGLP Token', 'oGLP');
  await oGLP.deployed();
  console.log("oGLP: ", oGLP.address);

  const soGLP = await AUSDC.deploy('SOGLP Token', 'soGLP');
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
  const strategy = await Strategy.deploy(glp.address, soGLP.address, owner.address);
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
  await glpVault.setGLPManager(glpMock.address);
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

  // Write file
  fs.writeFileSync('./.wallet', owner.address);
});

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  settings: { optimizer: { enabled: true, runs: 500 } },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    polygon: {
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
