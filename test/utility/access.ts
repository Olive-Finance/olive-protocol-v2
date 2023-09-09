import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { toN, deployGLPVaultKeeper } from "../utils";

describe ("Access validations", function () {
    const revertString : string = "ALW: Not an owner";

    describe("Owner only checks", function(){
        it ("GLPVault - Non Owner checks", async function () {
            const { glpVault, u1, u2, glp } = await loadFixture(deployGLPVaultKeeper);
            await expect(glpVault.connect(u1).setVaultKeeper(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setRewardsRouter(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setLendingPool(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setPriceHelper(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setTokens(u2.address, u2.address, u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setStrategy(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setLeverage(toN(10))).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setVaultManager(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setArbSysAddress(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setAllowance(glp.address, u2.address, true)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setGLPPrecision(toN(1, 30))).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setLiquidationThreshold(toN(0.9))).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setOwner(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).grantRole(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).revokeRole(u2.address)).to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).enable(true)).to.be.revertedWith(revertString);
        });
    
        it("VaultManager - Non Owner checks", async function () {
            const { vaultManager, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await expect(vaultManager.connect(u1).setVaultCore(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).setFees(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).setSameBlockTxnFor(u2.address, true)).to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).setOwner(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).grantRole(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).revokeRole(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).enable(true)).to.be.revertedWith(revertString);
        });
    
        it("VaultKeeper - Non Owner checks", async function () {
            const { vaultKeeper, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await expect(vaultKeeper.connect(u1).setVaultCore(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).setFees(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).setVaultManager(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).setOwner(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).grantRole(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).revokeRole(u2.address)).to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).enable(true)).to.be.revertedWith(revertString);
        });

        it("OliveManager - Non Owner checks", async function () {
            const { oliveManager, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await expect(oliveManager.connect(u1).setMinVestingPeriod(3600*24*2)).to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).setMaxVestingPeriod(3600*24*10)).to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).setFees(u2.address)).to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).setRewardToken(u2.address)).to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).setTokens(u2.address, u2.address)).to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).setOwner(u2.address)).to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).grantRole(u2.address)).to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).revokeRole(u2.address)).to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).enable(true)).to.be.revertedWith(revertString);
        });

        it("Olive - Non Owner checks", async function () {
            const { olive, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await expect(olive.connect(u1).setOliveManager(u2.address)).to.be.revertedWith(revertString);
            await expect(olive.connect(u1).setKeeper(u2.address)).to.be.revertedWith(revertString);
            await expect(olive.connect(u1).setOwner(u2.address)).to.be.revertedWith(revertString);
            await expect(olive.connect(u1).grantRole(u2.address)).to.be.revertedWith(revertString);
            await expect(olive.connect(u1).revokeRole(u2.address)).to.be.revertedWith(revertString);
            await expect(olive.connect(u1).enable(true)).to.be.revertedWith(revertString);
        });

        it("LendingPool - Non Owner checks", async function () {
            const { pool, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await expect(pool.connect(u1).mintFees()).to.be.revertedWith(revertString);
            await expect(pool.connect(u1).setFees(u2.address)).to.be.revertedWith(revertString);
            await expect(pool.connect(u1).setOwner(u2.address)).to.be.revertedWith(revertString);
            await expect(pool.connect(u1).grantRole(u2.address)).to.be.revertedWith(revertString);
            await expect(pool.connect(u1).revokeRole(u2.address)).to.be.revertedWith(revertString);
            await expect(pool.connect(u1).enable(true)).to.be.revertedWith(revertString);
        });


        it("FEEs - Non Owner checks", async function () {
            const { fees, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            const revertReason : string = 'Governable: forbidden'

            await expect(fees.connect(u1).setPFee(toN(10))).to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setMFee(toN(2))).to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setLiquidationFee(toN(10))).to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setLiquidatorFee(toN(80))).to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setRewardRateForOliveHolders(toN(10))).to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setYieldFeeLimit(toN(10))).to.be.revertedWith(revertReason);

            await expect(fees.connect(u1).setOwner(u2.address)).to.be.revertedWith(revertString);
            await expect(fees.connect(u1).grantRole(u2.address)).to.be.revertedWith(revertString);
            await expect(fees.connect(u1).revokeRole(u2.address)).to.be.revertedWith(revertString);
            await expect(fees.connect(u1).enable(true)).to.be.revertedWith(revertString);
            await expect(fees.connect(u1).setTreasury(u2.address)).to.be.revertedWith(revertString);
        });
    });


    describe("Owner only checks", function(){
        it ("GLPVault - Owner checks", async function () {
            const { glpVault, u1, u2, glp } = await loadFixture(deployGLPVaultKeeper);
            await glpVault.setOwner(u1.address);

            await expect(glpVault.connect(u1).setVaultKeeper(u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setRewardsRouter(u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setLendingPool(u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setPriceHelper(u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setTokens(u2.address, u2.address, u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setStrategy(u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setLeverage(toN(10))).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setVaultManager(u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setArbSysAddress(u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setLiquidationThreshold(toN(0.9))).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setAllowance(glp.address, u2.address, true)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).setGLPPrecision(toN(1, 30))).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).grantRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).revokeRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(glpVault.connect(u1).enable(true)).not.to.be.revertedWith(revertString);

            await expect(glpVault.connect(u1).setOwner(u2.address)).not.to.be.revertedWith(revertString);
        });
    
        it("VaultManager - Owner checks", async function () {
            const { vaultManager, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await vaultManager.setOwner(u1.address);

            await expect(vaultManager.connect(u1).setVaultCore(u2.address)).not.to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).setFees(u2.address)).not.to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).setSameBlockTxnFor(u2.address, true)).not.to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).grantRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).revokeRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(vaultManager.connect(u1).enable(true)).not.to.be.revertedWith(revertString);

            await expect(vaultManager.connect(u1).setOwner(u2.address)).not.to.be.revertedWith(revertString);
        });
    
        it("VaultKeeper - Owner checks", async function () {
            const { vaultKeeper, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await vaultKeeper.setOwner(u1.address);

            await expect(vaultKeeper.connect(u1).setVaultCore(u2.address)).not.to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).setFees(u2.address)).not.to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).setVaultManager(u2.address)).not.to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).grantRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).revokeRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(vaultKeeper.connect(u1).enable(true)).not.to.be.revertedWith(revertString);

            await expect(vaultKeeper.connect(u1).setOwner(u2.address)).not.to.be.revertedWith(revertString);
        });

        it("OliveManager - Owner checks", async function () {
            const { oliveManager, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await oliveManager.setOwner(u1.address);

            await expect(oliveManager.connect(u1).setMinVestingPeriod(3600*24*2)).not.to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).setMaxVestingPeriod(3600*24*10)).not.to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).setFees(u2.address)).not.to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).setRewardToken(u2.address)).not.to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).setTokens(u2.address, u2.address)).not.to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).grantRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).revokeRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(oliveManager.connect(u1).enable(true)).not.to.be.revertedWith(revertString);

            await expect(oliveManager.connect(u1).setOwner(u2.address)).not.to.be.revertedWith(revertString);
        });

        it("Olive - Owner checks", async function () {
            const { olive, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await olive.setOwner(u1.address);

            await expect(olive.connect(u1).setOliveManager(u2.address)).not.to.be.revertedWith(revertString);
            await expect(olive.connect(u1).setKeeper(u2.address)).not.to.be.revertedWith(revertString);
            await expect(olive.connect(u1).grantRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(olive.connect(u1).revokeRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(olive.connect(u1).enable(true)).not.to.be.revertedWith(revertString);

            await expect(olive.connect(u1).setOwner(u2.address)).not.to.be.revertedWith(revertString);
        });

        it("LendingPool - Owner checks", async function () {
            const { pool, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await pool.setOwner(u1.address);

            await expect(pool.connect(u1).mintFees()).not.to.be.revertedWith(revertString);
            await expect(pool.connect(u1).setFees(u2.address)).not.to.be.revertedWith(revertString);
            await expect(pool.connect(u1).grantRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(pool.connect(u1).revokeRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(pool.connect(u1).enable(true)).not.to.be.revertedWith(revertString);

            await expect(pool.connect(u1).setOwner(u2.address)).not.to.be.revertedWith(revertString);
        });

        it("FEEs - Owner checks", async function () {
            const { fees, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
            await fees.setOwner(u1.address);
            await fees.setGov(u1.address);
            const revertReason : string = 'Governable: forbidden'

            await expect(fees.connect(u1).setPFee(toN(10))).not.to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setMFee(toN(2))).not.to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setLiquidationFee(toN(10))).not.to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setLiquidatorFee(toN(80))).not.to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setRewardRateForOliveHolders(toN(10))).not.to.be.revertedWith(revertReason);
            await expect(fees.connect(u1).setYieldFeeLimit(toN(10))).not.to.be.revertedWith(revertReason);
            
            await expect(fees.connect(u1).grantRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(fees.connect(u1).revokeRole(u2.address)).not.to.be.revertedWith(revertString);
            await expect(fees.connect(u1).enable(true)).not.to.be.revertedWith(revertString);
            await expect(fees.connect(u1).setOwner(u2.address)).not.to.be.revertedWith(revertString);
        });
    });
    

    it("MoK only checks", async function(){
        const { glpVault, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
        const mokRevertError: string = 'VC: Not an manager / keeper';

        await expect(glpVault.connect(u1).mintShares(u2.address, toN(10))).to.be.revertedWith(mokRevertError);
        await expect(glpVault.connect(u1).burnShares(u2.address, toN(10))).to.be.revertedWith(mokRevertError);
        await expect(glpVault.connect(u1).transferAsset(u2.address, toN(2))).to.be.revertedWith(mokRevertError);
    });

    it("Pool onlyAllowed checks", async function(){
        const { pool, u1, u2 } = await loadFixture(deployGLPVaultKeeper);
        const allowedRevertError: string = 'ALW: Insufficient privilages';
        await pool.revokeRole(u1.address);
        await expect(pool.connect(u1).borrow(u2.address, u2.address, toN(10))).to.be.revertedWith(allowedRevertError);
        await expect(pool.connect(u1).repayWithSettle(u2.address, u2.address, toN(10), toN(1))).to.be.revertedWith(allowedRevertError);
    });


});