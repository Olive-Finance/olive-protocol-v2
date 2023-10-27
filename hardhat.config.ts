import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-web3";
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
  const toN = (n, d=18)=>{return ethers.utils.parseUnits(n.toString(), d)};

  const accounts = await ethers.getSigners();
    const owner = accounts[0];

    const u1 = accounts[1];
    const u2 = accounts[2];
    const u3 = accounts[3];
    const treasury = accounts[4];

    const u5 = '0xebb83B26f452a328bc6C4e3aa458AE3F2DF844C4';

    // Following are the asset tokens which each of the pools use
    // USDC
    const USDC = await ethers.getContractFactory("Token");
    const usdc = await USDC.deploy('USDC Token', 'USDC', 6);
    await usdc.deployed();

    //Debt Token for USDC
    const DOUSDC = await ethers.getContractFactory("DToken");
    const doUSDC = await DOUSDC.deploy('DOUSDC Token', 'doUSDC', 6);
    await doUSDC.deployed();

    //Fund Token for USDC
    const AUSDC = await ethers.getContractFactory("Token");
    const aUSDC = await AUSDC.deploy('AUSDC Token', 'aUSDC', 6);
    await aUSDC.deployed();

    // Rate Calculator 
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.deploy(toN(0.03), toN(0.03), toN(0.03), toN(0.8));
    await rcl.deployed();

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.deploy();
    await fees.deployed();
    await fees.setTreasury(treasury.address);


    // USDC Lending pool
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.deploy(aUSDC.address, doUSDC.address, usdc.address, rcl.address);
    
    await pool.deployed();

  // Assset is GLP 
  const Token = await ethers.getContractFactory("Token");
  const glp = await Token.deploy('GLP Token', 'GLP', 18);
  await glp.deployed();

  // Rewards token
  const wETH = await Token.deploy('WETH Token', 'Weth', 18);
  await wETH.deployed();

  // Strategy token
  const sGlp = await Token.deploy('S Token', 'sToken', 18);
  await sGlp.deployed();

  // Strategy contract
  const Strategy = await ethers.getContractFactory('GLPStrategy');
  const stgy = await Strategy.deploy(glp.address, sGlp.address);
  await stgy.deployed();

  await aUSDC.grantRole(pool.address);
  await doUSDC.grantRole(pool.address);
  await sGlp.grantRole(stgy.address);
  await pool.setFees(fees.address);

  // Assset is GLP 
  const OToken = await ethers.getContractFactory("OToken");
  const oGlp = await OToken.deploy('oGLP Token', 'oGLP', 18);
  await oGlp.deployed();

  const GLPVault = await ethers.getContractFactory("GLPVault");
  const glpVault = await GLPVault.deploy();
  await glpVault.deployed();

  const GLPManager = await ethers.getContractFactory("GLPMockManager");
  const glpMockManager = await GLPManager.deploy(glp.address);
  await glpMockManager.deployed();
  await glp.grantRole(glpMockManager.address);
  await usdc.grantRole(glpMockManager.address);


  const GLPMockRouter = await ethers.getContractFactory("GLPMock");
  const glpMockRouter = await GLPMockRouter.deploy(glpMockManager.address);
  await glpMockRouter.deployed();

  const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
  const phMock = await PriceHelperMock.deploy();
  await phMock.deployed();

  // setting up the GLP core

  const VaultManager = await ethers.getContractFactory("VaultManager");
  const vaultManager = await VaultManager.deploy();
  await vaultManager.deployed();

  const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
  const vaultKeeper = await VaultKeeper.deploy();
  await vaultKeeper.deployed();

  await stgy.setFees(fees.address);

  // Setting the parameters for glp vault core
  await glpVault.setRewardsRouter(glpMockRouter.address);
  await glpVault.setVaultManager(vaultManager.address);
  await glpVault.setVaultKeeper(vaultKeeper.address);
  await glpVault.setLendingPool(pool.address);
  await glpVault.setLeverage(ethers.utils.parseUnits("5", 18));
  await glpVault.setPriceHelper(phMock.address);
  await glpVault.setTokens(glp.address, oGlp.address, sGlp.address);
  await glpVault.setStrategy(stgy.address);
  
  await oGlp.grantRole(glpVault.address);

  await stgy.setGLPRouters(glpMockRouter.address, glpMockRouter.address);
  await phMock.setPriceOf(usdc.address, ethers.utils.parseUnits('1', 18));
  await phMock.setPriceOf(wETH.address, ethers.utils.parseUnits('1000', 18));

  await pool.grantRole(vaultManager.address);

  // Setting the vault manager addresses
  await vaultManager.setVaultCore(glpVault.address);
  await vaultManager.setFees(fees.address);
  
  // Setting the vault keeper addresses
  await vaultKeeper.setVaultCore(glpVault.address);
  await vaultKeeper.setFees(fees.address);
  await vaultKeeper.setVaultManager(vaultManager.address);

  await fees.grantRole(vaultKeeper.address);
  await fees.grantRole(vaultManager.address);
  await stgy.grantRole(vaultManager.address);
  await stgy.grantRole(vaultKeeper.address);

  await stgy.setHandler(glpVault.address, vaultManager.address, true);
  await stgy.setHandler(glpVault.address, vaultKeeper.address, true);

  await vaultManager.connect(owner).setWhitelist([owner.address, u2.address, u3.address], true);   

  await stgy.setKeeper(vaultKeeper.address);

    await glpMockRouter.setRewardsToken(wETH.address);
    await wETH.grantRole(glpMockRouter.address);
    await glpMockRouter.setFeesToClaim(toN(20));
    
    await stgy.setVaultCore(glpVault.address);
    await stgy.setRewardsToken(wETH.address);
    await stgy.setFees(fees.address);

    await fees.grantRole(vaultKeeper.address);
    await fees.grantRole(stgy.address);

    const OliveManager = await ethers.getContractFactory("OliveManager");
    const oliveManager = await OliveManager.deploy();
    await oliveManager.deployed();

    const ESOlive = await ethers.getContractFactory("ESOlive");
    const esOlive = await ESOlive.deploy(oliveManager.address);
    await esOlive.deployed();

    const Olive = await ethers.getContractFactory("Olive");
    const olive = await Olive.deploy(oliveManager.address);
    await olive.deployed();

    await oliveManager.setRewardToken(wETH.address);
    await oliveManager.setTokens(olive.address, esOlive.address);
    await oliveManager.setFees(fees.address);

    await stgy.setRewardManager(oliveManager.address);
    await oliveManager.grantRole(stgy.address);  

  await usdc.mint(owner.address, toN(10000, 6))
  await usdc.approve(pool.address, toN(10000, 6))
  await pool.supply(toN(10000, 6))
  await glp.mint(u5, toN(10000))
  await usdc.mint(u5, toN(10000, 6))

  await glp.mint(owner.address, toN(10000));
  await glp.approve(vaultManager.address, toN(10000000));
  
  await vaultManager.deposit(toN(2), toN(3), toN(6), toN(0.01));
  console.log(await vaultManager.getLeverage(owner.address));
  await vaultManager.deposit(toN(5), toN(5), toN(25), toN(0.01));

  await owner.sendTransaction({
    to: faucet.address,
    value: ethers.utils.parseEther("10.0"), // Sends exactly 5.0 ether
  });

  console.log("usdc: ", usdc.address);
  console.log("glp: ", glp.address);
  console.log("oGlp: ", oGlp.address);
  console.log("sGlp: ", sGlp.address);
  console.log("aUSDC: ", aUSDC.address);
  console.log("doUSDC: ", doUSDC.address);
  console.log("glpVault: ", glpVault.address);
  console.log("manager: ", vaultManager.address);
  console.log("keeper: ", vaultKeeper.address);
  console.log("fees: ", fees.address);
  console.log("pool: ", pool.address);
});

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  settings: { optimizer: { enabled: true, runs: 500 } },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    polytest: {
      url: "https://rpc.ankr.com/polygon_mumbai",
      chainId: 80001,
    },
    arbtest: {
      url: "https://arbitrum-goerli.publicnode.com",
      chainId: 421613,
    },
    mtltest: {
      url: "https://rpc.testnet.mantle.xyz/​",
      chainId: 5001,
    },
    arbmain: {
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
    },
    zetatest: {
      url: "https://zetachain-athens-evm.blockpi.network/v1/rpc/public",
      chainId: 7001,
    }
  },
  gas: 800000000,
  gasPrice: 800000000,
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