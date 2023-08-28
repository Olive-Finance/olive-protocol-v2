import { ethers } from "hardhat";
import { utils } from "ethers";

export function ethers.utils.parseUnits(n : any, d=18) {
    return utils.parseUnits(n.toString(), d);
}

async function main() {
    // Get generated signer wallets
    const accounts = await ethers.getSigners();

    // Get the first wallet address
    const owner = accounts[0];
    const u1 = accounts[1];

    //Commands to interact with contract -- to change for specific network
    const Token = await ethers.getContractFactory("Token");
    const wETH = await Token.attach('0x82aF49447D8a07e3bd95BD0d56f35241523fBab1');
    const glp = await Token.attach('0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf');
    const usdc = await Token.attach('0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8');


    //////////////////////////////////
    //// Lending pool Deployment ////
    /////////////////////////////////

    //Fund Token for USDC
    const AUSDC = await ethers.getContractFactory("Token");
    const aUSDC = await AUSDC.deploy('Olive - USDC Supply Token', 'aUSDC', 6);
    await aUSDC.deployed();
    console.log("aUSDC deployed to:", aUSDC.address);

    //Debt Token for USDC
    const DOUSDC = await ethers.getContractFactory("DToken");
    const doUSDC = await DOUSDC.deploy('Olive - USDC Debt Token', 'dUSDC', 6);
    await doUSDC.deployed();
    console.log("doUSDC deployed to:", doUSDC.address);

    // Rate Calculator 
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.deploy(ethers.utils.parseUnits ('0.03', 18), ethers.utils.parseUnits('0.03', 18), ethers.utils.parseUnits('0.03', 18), ethers.utils.parseUnits('0.8', 18));
    await rcl.deployed();

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.deploy();
    await fees.deployed();
    console.log("Fees deployed to:", fees.address);

    // USDC Lending pool
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.deploy(aUSDC.address, doUSDC.address, usdc.address, rcl.address);
    console.log("LendingPool deployed to:", pool.address);


    //////////////////////////////
    //// Strategy Deployment ////
    /////////////////////////////
    // Strategy token
    const sGlp = await Token.deploy('Olive - GLP Strategy Token', 'sGLP', 18);
    await sGlp.deployed();
    console.log("sGLP deployed to:", sGlp.address);

    // Strategy contract
    const GLPStrategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await GLPStrategy.deploy(glp.address, sGlp.address);
    await stgy.deployed();
    console.log("Strategy deployed to:", stgy.address);

    ///////////////////////////////
    //// GLP Vault Deployment ////
    //////////////////////////////

    const OToken = await ethers.getContractFactory("OToken");
    const oGlp = await OToken.deploy('Olive GLP Token', 'oGLP', 18);
    await oGlp.deployed();
    console.log("oGLP deployed to:", oGlp.address);
    
    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.deploy();
    await glpVault.deployed();
    console.log("GLPVault deployed to:", glpVault.address);

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.deploy();
    await vaultManager.deployed();
    console.log("VaultManager deployed to:", vaultManager.address);

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.deploy();
    await vaultKeeper.deployed();
    console.log("VaultKeeper deployed to:", vaultKeeper.address);

    const PriceHelper = await ethers.getContractFactory("PriceHelper");
    const priceHelper = await PriceHelper.deploy();
    await priceHelper.deployed();
    console.log("PriceHelper deployed to:", priceHelper.address);


    ///////////////////////////////////
    //// Parameters & Permissions ////
    //////////////////////////////////
    // token roles
    await oGlp.grantRole(glpVault.address);
    await sGlp.grantRole(stgy.address);
    await aUSDC.grantRole(pool.address);
    await doUSDC.grantRole(pool.address);

    // treasury
    await fees.setTreasury(owner.address);
    
    // vault
    await pool.grantRole(vaultManager.address);
    // Setting the parameters for glp vault core
    await glpVault.setRewardsRouter('0xB95DB5B167D75e6d04227CfFFA61069348d271F5');
    await glpVault.setVaultManager(vaultManager.address);
    await glpVault.setVaultKeeper(vaultKeeper.address);
    await glpVault.setLendingPool(pool.address);
    await glpVault.setLeverage(ethers.utils.parseUnits("5", 18));
    await glpVault.setPriceHelper(priceHelper.address);
    await glpVault.setTokens(glp.address, oGlp.address, sGlp.address);
    await glpVault.setStrategy(stgy.address);

    await vaultManager.setVaultCore(glpVault.address);
    await vaultManager.setFees(fees.address);

    await vaultKeeper.setVaultCore(glpVault.address);
    await vaultKeeper.setFees(fees.address);
    await vaultKeeper.setVaultManager(vaultManager.address);

    await fees.grantRole(vaultKeeper.address);
    await fees.grantRole(vaultManager.address);
    await stgy.grantRole(vaultManager.address);
    await stgy.grantRole(vaultKeeper.address);

    await stgy.setHandler(glpVault.address, vaultManager.address, true);
    await stgy.setHandler(glpVault.address, vaultKeeper.address, true);

    await stgy.setGLPRouters('0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1', '0xB95DB5B167D75e6d04227CfFFA61069348d271F5');
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });