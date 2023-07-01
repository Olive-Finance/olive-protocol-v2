import { ethers } from "hardhat";
import { utils } from "ethers";

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
    const pool = await LPUSDC.deploy(usdc.address, aUSDC.address, doUSDC.address, rcl.address);
    await pool.deployed();

    return {owner, u1, u2, u3, usdc, aUSDC, doUSDC, rcl, pool};
}