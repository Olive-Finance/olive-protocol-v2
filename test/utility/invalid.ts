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
});