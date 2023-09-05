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

        it("Liquidate 500GLP, Borrowed 400GLP - [debt > position] | unstakes | bad debt", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp, phMock, glpMockManager, vaultKeeper, glpVault, fees} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor
            // u2 is liquidator
            await glpMockManager.setPriceOfGLP(toN(0.6, 30));
            expect(Math.round(await glpVault.hf(u1.address)/1e15)).to.equal(675);
            expect(await vaultKeeper.liquidators(u2.address)).to.equal(true);
            await vaultKeeper.connect(u2).liquidation(u1.address, toN(400), false); 
            
            expect(Math.floor(await oGlp.balanceOf(u1.address)/1e16)).to.equal(0);
            expect(await oGlp.balanceOf(u2.address)).to.equal(0);
            expect(Math.floor(await oGlp.balanceOf(fees.getTreasury())/1e16)).to.equal(0);
            expect(Math.floor(await sGlp.balanceOf(glpVault.address)/1e16)).to.equal(0);
            expect(await doUSDC.balanceOf(u1.address)).to.equal(1); // dust balance 1e-6
            expect(Math.floor(await glp.balanceOf(u2.address)/1e18)).to.equal(500);
        });
    });

    describe("Liquidation checks", function(){
        it("Harvesting checks", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp, phMock, glpMockManager, vaultKeeper, glpVault, fees, stgy} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor 500oGLP, 400USDC Debt
            let pps = (await glpVault.getPPS()/1e16);
            await time.increase(365 * 24 * 3600);
            await vaultKeeper.connect(u1).harvest();
            expect(pps <= (await glpVault.getPPS()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(518)
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(0);
        });

        it("Harvesting checks | More yield | 20% yield", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp, wETH, phMock, glpMockManager, vaultKeeper, glpVault, fees, stgy, glpMockRouter} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor 500oGLP, 400USDC Debt
            await phMock.setPriceOf(wETH.address, toN(1));
            await glpMockRouter.setFeesToClaim(toN(100)); // 20% yield
            let pps = (await glpVault.getPPS()/1e16);
            await time.increase(365 * 24 * 3600);
            await vaultKeeper.connect(u1).harvest();
            expect(pps <= (await glpVault.getPPS()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(580)
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(0);
        });

        it("Harvesting checks | Less Yield | 10% Yield", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp, wETH, phMock, glpMockManager, vaultKeeper, glpVault, fees, stgy, glpMockRouter} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor 500oGLP, 400USDC Debt
            await phMock.setPriceOf(wETH.address, toN(1));
            await glpMockRouter.setFeesToClaim(toN(50)); // 10% yield
            let pps = (await glpVault.getPPS()/1e16);
            await time.increase(365 * 24 * 3600);
            await vaultKeeper.connect(u1).harvest();
            expect(pps <= (await glpVault.getPPS()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(535)
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(0);
        });

        it("Harvesting checks | Less Yield | 2% Yield", async function(){
            const {owner, u1, u2, u3, usdc, oGlp, doUSDC, sGlp, glp, wETH, phMock, glpMockManager, vaultKeeper, glpVault, fees, stgy, glpMockRouter} = await loadFixture(deployGLPVaultKeeper);
            // u1 is depositor 500oGLP, 400USDC Debt
            await phMock.setPriceOf(wETH.address, toN(1));
            await glpMockRouter.setFeesToClaim(toN(10)); // 2% yield
            let pps = (await glpVault.getPPS()/1e16);
            await time.increase(365 * 24 * 3600);
            await vaultKeeper.connect(u1).harvest();
            expect(pps <= (await glpVault.getPPS()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(505)
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(6);
        });
    });
});