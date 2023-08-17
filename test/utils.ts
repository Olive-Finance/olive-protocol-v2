import { ethers } from "hardhat";
import { utils } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

export function toN(n : any, d=18) {
    return utils.parseUnits(n.toString(), d);
}

export async function deployLendingPool() {
    const accounts = await ethers.getSigners();
    const owner = accounts[0];

    const u1 = accounts[1];
    const u2 = accounts[2];
    const u3 = accounts[3];
    const treasury = accounts[4];

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
    const AUSDC = await ethers.getContractFactory("AToken");
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

    return {owner, u1, u2, u3, usdc, aUSDC, doUSDC, rcl, pool, fees, treasury};
}

export async function deployStategy() {
    const accounts = await ethers.getSigners();
    const owner = accounts[0];

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
    const Strategy = await ethers.getContractFactory('Strategy');
    const stgy = await Strategy.deploy(glp.address, sGlp.address);
    await stgy.deployed();


    await sGlp.grantRole(stgy.address);

    return {glp, wETH, sGlp, stgy};
}

export async function deployGLPVault() {
    const {owner, u1, u2, u3, usdc, aUSDC, doUSDC, rcl, pool, fees} = await loadFixture(deployLendingPool);
    await loadFixture(setupLendingPool);
    const {glp, wETH, sGlp, stgy} = await loadFixture(deployStategy);

    stgy.setFees(fees.address);

    // Assset is GLP 
    const Token = await ethers.getContractFactory("Token");
    const oGlp = await Token.deploy('oGLP Token', 'oGLP', 18);
    await oGlp.deployed();

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.deploy();
    await glpVault.deployed();

    const GLPManager = await ethers.getContractFactory("GLPMockManager");
    const glpMockManager = await GLPManager.deploy(glp.address);
    await glpMockManager.deployed();
    glp.grantRole(glpMockManager.address);

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

    await vaultManager.setVaultCore(glpVault.address);
    await glpVault.setRewardsRouter(glpMockRouter.address);
    await glpVault.setVaultManager(vaultManager.address);
    await glpVault.setTreasury(owner.address);
    await glpVault.setLendingPool(pool.address);
    await glpVault.setLeverage(utils.parseUnits("5", 18));
    await glpVault.setPriceHelper(phMock.address);
    await glpVault.setTokens(glp.address, oGlp.address, sGlp.address);
    await glpVault.setStrategy(stgy.address);
    await oGlp.grantRole(glpVault.address);

    await stgy.setGLPRouters(glpMockRouter.address, glpMockRouter.address);
    await phMock.setPriceOf(usdc.address, toN(1));
    await phMock.setPriceOf(wETH.address, toN(1000));

    await pool.grantRole(vaultManager.address);

    await vaultManager.setFees(fees.address);
    await vaultKeeper.setFees(fees.address);

    await fees.grantRole(vaultKeeper.address);
    await fees.grantRole(vaultManager.address);
    await stgy.grantRole(vaultManager.address);
    await stgy.grantRole(vaultKeeper.address);

    await stgy.setHandler(glpVault.address, vaultManager.address, true);

    await glp.mint(u1.address, toN(1000));
    await glp.connect(u1).approve(vaultManager.address, toN(10000000));

    await usdc.mint(u3.address, toN(100));
    await usdc.connect(u3).approve(pool.address, toN(10000000000));
    await pool.connect(u3).supply(toN(1));

    return {owner, u1, u2, u3, usdc, aUSDC, doUSDC, 
        rcl, pool, glp, wETH, sGlp, stgy, oGlp, glpVault, vaultManager, vaultKeeper};
}

export async function setupLendingPool() {
    const {owner, u1, u2, u3, usdc, aUSDC, doUSDC, rcl, pool, fees, treasury} = await loadFixture(deployLendingPool);
    await pool.grantRole(u1.address);
    await pool.grantRole(u2.address);
    await aUSDC.grantRole(pool.address);
    await doUSDC.grantRole(pool.address);
    
    await usdc.connect(owner).mint(u1.address, toN(2000));
    await usdc.connect(u1).approve(pool.address, toN(1e20));
    await usdc.connect(u2).approve(pool.address, toN(1e20));

    await pool.setFees(fees.address);
    return {owner, u1, u2, u3, usdc, aUSDC, doUSDC, rcl, pool};
}