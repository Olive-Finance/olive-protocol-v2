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