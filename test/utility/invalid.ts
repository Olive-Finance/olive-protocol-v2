import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { toN, deployGLPVaultKeeper } from "../utils";

describe ("Invalid input validations", function () {
    it ("GLPVault - Invalid input checks", async function () {
        const { glpVault, u1, u2, glp } = await loadFixture(deployGLPVaultKeeper);
        await glpVault.setOwner(u1.address);

        await expect(glpVault.connect(u1).setVaultKeeper(ethers.constants.AddressZero)).to.be.reverted;
        await expect(glpVault.connect(u1).setRewardsRouter(ethers.constants.AddressZero)).to.be.reverted;
        await expect(glpVault.connect(u1).setLendingPool(ethers.constants.AddressZero)).to.be.reverted;
        await expect(glpVault.connect(u1).setPriceHelper(ethers.constants.AddressZero)).to.be.reverted;
        await expect(glpVault.connect(u1).setTokens(ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero)).to.be.reverted;
        await expect(glpVault.connect(u1).setStrategy(ethers.constants.AddressZero)).to.be.reverted;
        await expect(glpVault.connect(u1).setLeverage(toN(0))).to.be.reverted;
        await expect(glpVault.connect(u1).setVaultManager(ethers.constants.AddressZero)).to.be.reverted;
        await expect(glpVault.connect(u1).setArbSysAddress(ethers.constants.AddressZero)).to.be.reverted;
        await expect(glpVault.connect(u1).setAllowance(glp.address, ethers.constants.AddressZero, true)).to.be.reverted;
        await expect(glpVault.connect(u1).setGLPPrecision(toN(0, 30))).to.be.reverted;
        await expect(glpVault.connect(u1).setLiquidationThreshold(toN(0.1))).to.be.reverted;
    });

    it("Pool - Invalid input checks", async function(){
        const { pool, u1, u2, aUSDC, fees } = await loadFixture(deployGLPVaultKeeper);
        const allowedRevertError: string = 'ALW: Insufficient privilages';
        await pool.grantRole(u1.address);

        await expect(pool.connect(u1).borrow(ethers.constants.AddressZero, u2.address, toN(10))).to.be.revertedWith('POL: Null address');
        await expect(pool.connect(u1).borrow(u2.address, ethers.constants.AddressZero, toN(10))).to.be.revertedWith('POL: Null address');
        await expect(pool.connect(u1).borrow(u2.address, u2.address, toN(0))).to.be.revertedWith('POL: Zero/Negative amount');
        await expect(pool.connect(u1).borrow(u2.address, u2.address, toN(10))).to.be.revertedWith('POL: Insufficient liquidity to borrow');

        await expect(pool.connect(u1).repay(u2.address, u2.address, ethers.constants.AddressZero, toN(10))).to.be.revertedWith('POL: Null address');
        await expect(pool.connect(u1).repay(u2.address, u2.address, ethers.constants.AddressZero, toN(0))).to.be.revertedWith('POL: Zero/Negative amount');

        await expect(pool.connect(u1).supply(toN(0))).to.be.revertedWith('POL: Zero/Negative amount');

        await expect(pool.connect(u1).withdraw(toN(0))).to.be.revertedWith('POL: Zero/Negative amount');
        await expect(pool.connect(u1).withdraw(toN(10))).to.be.revertedWith('POL: Not enough shares');
        await aUSDC.mint(u1.address, toN(10));
        await expect(pool.connect(u1).withdraw(toN(10))).to.be.reverted; // update reserver failes during the computation

        await expect(fees.setTreasury(ethers.constants.AddressZero)).to.be.revertedWith('FEE: Invalid treasury address');
    });

    it("Fees - Invalid input checks", async function(){
        const {u1, fees } = await loadFixture(deployGLPVaultKeeper);
        await fees.setOwner(u1.address);
        await fees.setGov(u1.address);
        const revertReason : string = 'Governable: forbidden'

        await expect(fees.connect(u1).setPFee(toN(150))).to.be.reverted;
        await expect(fees.connect(u1).setMFee(toN(150))).to.be.reverted;
        await expect(fees.connect(u1).setLiquidationFee(toN(150))).to.be.reverted;
        await expect(fees.connect(u1).setLiquidatorFee(toN(150))).to.be.reverted;
        await expect(fees.connect(u1).setRewardRateForOliveHolders(toN(150))).to.be.reverted;
        await expect(fees.connect(u1).setYieldFeeLimit(toN(150))).to.be.reverted;
    });


});