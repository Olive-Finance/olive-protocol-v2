import { ethers } from "hardhat";

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

async function main() {
    // Get generated signer wallets
    const accounts = await ethers.getSigners();

    // Get the first wallet address
    const owner = accounts[0];
    const u1 = accounts[1];

    //Commands to interact with contract
    const Token = await ethers.getContractFactory("Token");
    const wETH = await Token.attach('0x82aF49447D8a07e3bd95BD0d56f35241523fBab1');
    const glp = await Token.attach('0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf');
    const usdc = await Token.attach('0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8');

    // Olive vault and strategy tokens
    const aUSDC = await Token.attach('0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9');
    const doUSDC = await Token.attach('0xa513E6E4b8f2a923D98304ec87F64353C4D5C853');
    const oGlp = await Token.attach('0x0165878A594ca255338adfa4d48449f69242Eb8F');
    const sGLP = await Token.attach('');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0x5FC8d32690cc91D4c39d9d3abcBD16989F875707');

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const strategy = await Strategy.attach('0x610178dA211FEF7D417bC0e6FeD39F05609AD788');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpCore = await GLPVault.attach('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6');
    await glp.grantRole(glpCore.address);

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0x8A791620dd6260079BF849Dc5567aDC3F2FdC318');

    const PriceHelper = await ethers.getContractFactory("PriceHelper");
    const priceHelper = await PriceHelper.attach();

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.deploy();

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });