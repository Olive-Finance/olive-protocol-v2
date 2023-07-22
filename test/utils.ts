import { ethers } from "hardhat";
import { utils } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

export function toN(n : any) {
    return utils.parseUnits(n.toString(), 18);
}

export async function deployLendingPool() {
    const accounts = await ethers.getSigners();
    const owner = accounts[0];

    const u1 = accounts[1];
    const u2 = accounts[2];
    const u3 = accounts[3];

    // Following are the asset tokens which each of the pools use
    // USDC
    const USDC = await ethers.getContractFactory("Token");
    const usdc = await USDC.deploy('USDC Token', 'USDC');
    await usdc.deployed();

    //Debt Token for USDC
    const DOUSDC = await ethers.getContractFactory("DToken");
    const doUSDC = await DOUSDC.deploy('DOUSDC Token', 'doUSDC');
    await doUSDC.deployed();

    //Fund Token for USDC
    const AUSDC = await ethers.getContractFactory("AToken");
    const aUSDC = await AUSDC.deploy('AUSDC Token', 'aUSDC');
    await aUSDC.deployed();

    // Rate Calculator 
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.deploy(toN(0.03), toN(0.03), toN(0.03), toN(0.8));
    await rcl.deployed();

    // USDC Lending pool
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.deploy(aUSDC.address, doUSDC.address, usdc.address, rcl.address);
    await pool.deployed();

    return {owner, u1, u2, u3, usdc, aUSDC, doUSDC, rcl, pool};
}

export async function deployStategy() {
    const accounts = await ethers.getSigners();
    const owner = accounts[0];

    // Assset is GLP 
    const Token = await ethers.getContractFactory("Token");
    const glp = await Token.deploy('GLP Token', 'GLP');
    await glp.deployed();

    // Rewards token
    const wETH = await Token.deploy('WETH Token', 'Weth');
    await wETH.deployed();

    // Strategy token
    const sGlp = await Token.deploy('S Token', 'sToken');
    await sGlp.deployed();

    // Strategy contract
    const Strategy = await ethers.getContractFactory('Strategy');
    const stgy = await Strategy.deploy(glp.address, sGlp.address, owner.address);
    await stgy.deployed();

    // GLPManager
    const GLPManager = await ethers.getContractFactory('GLPManager');
    const astMgr = await GLPManager.deploy(glp.address);
    await astMgr.deployed();

    await sGlp.grantRole(stgy.address);
    await glp.grantRole(astMgr.address);

    return {glp, wETH, sGlp, stgy, astMgr};
}

export async function deployOlive() {
    const {owner, u1, u2, u3, usdc, aUSDC, doUSDC, rcl, pool} = await loadFixture(deployLendingPool);
    const {glp, wETH, sGlp, stgy, astMgr} = await loadFixture(deployStategy);

    // Assset is GLP 
    const Token = await ethers.getContractFactory("Token");
    const oGlp = await Token.deploy('oGLP Token', 'oGLP');
    await oGlp.deployed();

    // Olive address
    const Olive = await ethers.getContractFactory("OliveV2");
    const olive = await Olive.deploy(glp.address, oGlp.address,
         stgy.address, astMgr.address, pool.address, toN(1), toN(5), toN(1));
    await olive.deployed();

    await oGlp.grantRole(olive.address);
    await aUSDC.grantRole(pool.address);
    await doUSDC.grantRole(pool.address);

    await glp.connect(owner).mint(u1.address, toN(1000));
    await glp.connect(owner).mint(u2.address, toN(1000));

    await glp.connect(u1).approve(olive.address, toN(1e20)); 
    await glp.connect(u2).approve(olive.address, toN(1e20)); 

    await usdc.connect(owner).mint(u3.address, toN(1e8));
    await usdc.connect(u3).approve(pool.address, toN(1e20));
    
    await pool.connect(u3).supply(toN(10000));
    await pool.grantRole(olive.address);

    await astMgr.setPrice(usdc.address, toN(1));

    return {owner, u1, u2, u3, usdc, aUSDC, doUSDC, 
        rcl, pool, glp, wETH, sGlp, stgy, astMgr, oGlp, olive};
}

export async function setupLendingPool() {
    const {owner, u1, u2, u3, usdc, aUSDC, doUSDC, rcl, pool} = await loadFixture(deployLendingPool);
    await pool.grantRole(u1.address);
    await pool.grantRole(u2.address);
    await aUSDC.grantRole(pool.address);
    await doUSDC.grantRole(pool.address);
    
    await usdc.connect(owner).mint(u1.address, toN(1e8));
    await usdc.connect(u1).approve(pool.address, toN(1e20));
    await usdc.connect(u2).approve(pool.address, toN(1e20));
    return {owner, u1, u2, u3, usdc, aUSDC, doUSDC, rcl, pool};
}