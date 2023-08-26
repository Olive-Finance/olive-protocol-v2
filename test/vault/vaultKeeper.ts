import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { toN, deployGLPVaultKeeper } from "../utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("VaultKeeper checks", function(){

    describe("Basic checks", function(){
        it("Owner check", async function(){
            const {owner, vaultKeeper, glpVault} = await loadFixture(deployGLPVaultKeeper);
            expect(await vaultKeeper.gov()).to.equal(owner.address);
            expect(await vaultKeeper.ownerAddr()).to.equal(owner.address);
            expect(await vaultKeeper.vaultCore()).to.equal(glpVault.address);
        });

        it("Set Gov", async function(){
            const {owner, u1, vaultKeeper} = await loadFixture(deployGLPVaultKeeper);
            await vaultKeeper.setGov(u1.address);
            expect(await vaultKeeper.gov()).to.equal(u1.address);
            await expect(vaultKeeper.connect(owner).setGov(u1.address)).to.be.reverted;
        });     
        
        it("Validate the hfs based on price change", async function(){
            // u1 is depositor
            // u2 is liquidator
            const {owner, u1, u2, u3, usdc, phMock, glpMockManager, vaultKeeper, glpVault} = await loadFixture(deployGLPVaultKeeper);
            
            // USDC price fluctuations
            await glpMockManager.setPriceOfGLP(toN(1, 30));
            await phMock.setPriceOf(usdc.address, toN(1));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(1125);
            await phMock.setPriceOf(usdc.address, toN(0.5));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(2250);
            await phMock.setPriceOf(usdc.address, toN(2));
            expect(Math.floor(await glpVault.hf(u1.address)/1e15)).to.equal(562);
            await phMock.setPriceOf(usdc.address, toN(1));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(1125);
            

            // GLP price fluctuations
            await glpMockManager.setPriceOfGLP(toN(1, 30));
            await phMock.setPriceOf(usdc.address, toN(1));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(1125);
            await glpMockManager.setPriceOfGLP(toN(2, 30));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(2250);
            await glpMockManager.setPriceOfGLP(toN(0.5, 30));
            expect(Math.floor(await glpVault.hf(u1.address)/1e15)).to.equal(562);
        });
    });


    describe("Liquidation checks", function(){
        it("Liquidate 500GLP, Borrowed 400GLP - [debt = position] | unstakes", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp,  phMock, glpMockManager, vaultKeeper, glpVault} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor
            // u2 is liquidator
            await glpMockManager.setPriceOfGLP(toN(0.8, 30));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(900);
            expect(await vaultKeeper.liquidators(u2.address)).to.equal(true);
            await vaultKeeper.connect(u2).liquidation(u1.address, toN(400), false); 
            
            expect(await oGlp.balanceOf(u1.address)).to.equal(0);
            expect(await oGlp.balanceOf(u2.address)).to.equal(0);
            expect(await sGlp.balanceOf(glpVault.address)).to.equal(0);
            expect(await doUSDC.balanceOf(u1.address)).to.equal(1); // dust balance 1e-6
            expect(await glp.balanceOf(u2.address)).to.equal(toN(500));
        });

        it("Liquidate 500GLP, Borrowed 400GLP - [debt = position] | stakes", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp,  phMock, glpMockManager, vaultKeeper, glpVault} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor
            // u2 is liquidator
            await glpMockManager.setPriceOfGLP(toN(0.8, 30));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(900);
            expect(await vaultKeeper.liquidators(u2.address)).to.equal(true);

            await vaultKeeper.connect(u2).liquidation(u1.address, toN(400), true); 
            
            expect(await oGlp.balanceOf(u1.address)).to.equal(0);
            expect(await oGlp.balanceOf(u2.address)).to.equal(toN(500));
            expect(await sGlp.balanceOf(glpVault.address)).to.equal(toN(500));
            expect(await doUSDC.balanceOf(u1.address)).to.equal(1); // dust balance 1e-6
            expect(await glp.balanceOf(u2.address)).to.equal(0);
        });

        it("Liquidate 500GLP, Borrowed 400GLP - [debt < position] | unstakes", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp, phMock, glpMockManager, vaultKeeper, glpVault, fees} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor
            // u2 is liquidator
            await glpMockManager.setPriceOfGLP(toN(0.85, 30));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(956);
            expect(await vaultKeeper.liquidators(u2.address)).to.equal(true);
            await vaultKeeper.connect(u2).liquidation(u1.address, toN(400), false); 
            
            expect(Math.floor(await oGlp.balanceOf(u1.address)/1e16)).to.equal(588);
            expect(await oGlp.balanceOf(u2.address)).to.equal(0);
            expect(Math.floor(await oGlp.balanceOf(fees.getTreasury())/1e16)).to.equal(470);
            expect(Math.floor(await sGlp.balanceOf(glpVault.address)/1e16)).to.equal(1058);
            expect(await doUSDC.balanceOf(u1.address)).to.equal(1); // dust balance 1e-6
            expect(Math.floor(await glp.balanceOf(u2.address)/1e18)).to.equal(489);
        });
    
        it("Liquidate 500GLP, Borrowed 400GLP - [debt < position] | stakes", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp,  phMock, glpMockManager, vaultKeeper, glpVault, fees} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor
            // u2 is liquidator
            await glpMockManager.setPriceOfGLP(toN(0.85, 30));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(956);
            expect(await vaultKeeper.liquidators(u2.address)).to.equal(true);

            await vaultKeeper.connect(u2).liquidation(u1.address, toN(400), true); 

            expect(Math.floor(await oGlp.balanceOf(u1.address)/1e16)).to.equal(588);
            expect(Math.floor(await oGlp.balanceOf(u2.address)/1e18)).to.equal(489);
            expect(Math.floor(await oGlp.balanceOf(fees.getTreasury())/1e16)).to.equal(470);
            expect(Math.floor(await sGlp.balanceOf(glpVault.address)/1e18)).to.equal(500);
            expect(await doUSDC.balanceOf(u1.address)).to.equal(1); // dust balance 1e-6
            expect(Math.floor(await glp.balanceOf(u2.address)/1e18)).to.equal(0);
        });


        it("Liquidate 500GLP, Borrowed 400GLP - [debt < position] | unstakes", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp, phMock, glpMockManager, vaultKeeper, glpVault, fees} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor
            // u2 is liquidator
            await glpMockManager.setPriceOfGLP(toN(0.83, 30));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(934);
            expect(await vaultKeeper.liquidators(u2.address)).to.equal(true);
            await vaultKeeper.connect(u2).liquidation(u1.address, toN(400), false); 
            
            expect(Math.floor(await oGlp.balanceOf(u1.address)/1e16)).to.equal(0);
            expect(await oGlp.balanceOf(u2.address)).to.equal(0);
            expect(Math.floor(await oGlp.balanceOf(fees.getTreasury())/1e16)).to.equal(361);
            expect(Math.floor(await sGlp.balanceOf(glpVault.address)/1e16)).to.equal(361);
            expect(await doUSDC.balanceOf(u1.address)).to.equal(1); // dust balance 1e-6
            expect(Math.floor(await glp.balanceOf(u2.address)/1e18)).to.equal(496);
        });
    });
});