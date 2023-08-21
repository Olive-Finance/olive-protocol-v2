import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { toN, deployGLPVault } from "../utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("VaultManager checks", function(){

    describe("Basic checks", function(){
        it("Owner check", async function(){
            const {owner, glpVault, oGlp} = await loadFixture(deployGLPVault);
            expect(await glpVault.ownerAddr()).to.equal(owner.address);
            expect(await oGlp.ownerAddr()).to.equal(owner.address);
        });
    });

    describe("Deposit checks", function(){
        it("Deposit 1000GLP, no leverage", async function(){
            const {owner, glp, u1, vaultManager, oGlp} = await loadFixture(deployGLPVault);
            await vaultManager.connect(u1).deposit(toN(1000), toN(1), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(1000));
            expect(await glp.balanceOf(u1.address)).to.equal(toN(0));
        });

        it("Deposit 1000GLP, with leverage", async function(){
            const {owner, glp, u1, doUSDC, vaultManager, oGlp} = await loadFixture(deployGLPVault);
            await vaultManager.connect(u1).deposit(toN(1000), toN(2), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(2000));
            expect(await doUSDC.balanceOf(u1.address)).to.equal(999999999); 
        });


        it("Deposit 1000GLP, with leverage and deleverage", async function(){
            const {owner, glp, u1, doUSDC, vaultManager, oGlp} = await loadFixture(deployGLPVault);
            await vaultManager.connect(u1).deposit(toN(1000), toN(2), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(2000));
            expect(await doUSDC.balanceOf(u1.address)).to.equal(999999999); 
            await vaultManager.connect(u1).deleverage(toN(1), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(1000));
            expect(await doUSDC.balanceOf(u1.address)).to.equal(1); 
        });

        it("Deposit 1000GLP, with leverage and deleverage withdraw max", async function(){
            const {owner, glp, u1, doUSDC, vaultManager, oGlp} = await loadFixture(deployGLPVault);
            await vaultManager.connect(u1).deposit(toN(1000), toN(2), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(2000));
            expect(await doUSDC.balanceOf(u1.address)).to.equal(999999999); 
            await vaultManager.connect(u1).deleverage(toN(1), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(1000));
            expect(await doUSDC.balanceOf(u1.address)).to.equal(1); 
            await vaultManager.connect(u1).withdraw(vaultManager.getBurnableShares(u1.address), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(1250000000000);
            expect(await doUSDC.balanceOf(u1.address)).to.equal(1); 
        });

        it("Deposit Leverage at 2nd time", async function(){
            const {owner, glp, u1, doUSDC, vaultManager, oGlp} = await loadFixture(deployGLPVault);
            await vaultManager.connect(u1).deposit(toN(100), toN(1), 0, 0);
            await vaultManager.connect(u1).deposit(toN(100), toN(2), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(400));
            expect(await doUSDC.balanceOf(u1.address)).to.equal(199999999); 
        });
    });
})