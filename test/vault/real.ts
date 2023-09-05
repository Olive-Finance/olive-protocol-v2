import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { toN, deployGLPVaultKeeper } from "../utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Reality checks", function(){
    it("10% APY - Target PPS : ~1.07", async function(){
        const {owner, u1, u2, u3, usdc, glp, wETH, phMock, pool, oGlp,
             vaultKeeper, vaultManager, glpVault, fees, stgy, glpMockRouter, oliveManager} = await loadFixture(deployGLPVaultKeeper);

            // deposit 10000 tokens at 5x leverage
            await glp.approve(vaultManager.address, toN(9900));
            await glp.mint(u1.address, toN(9900));
            await vaultManager.connect(u1).deposit(toN(1900), toN(5), 0, 0);
            
            // 10% APY 
            console.log(await usdc.balanceOf(pool.address)/1e6);
            await phMock.setPriceOf(wETH.address, toN(1));
            console.log(await glp.balanceOf(stgy.address)/1e18);
            await glpMockRouter.setFeesToClaim(toN(1000)); // 10% yield
        
            let pps = (await glpVault.pps()/1e16);
            time.increase(365 * 24 * 3600); // After one year

            console.log(await fees.getMFee()/1e18);
            console.log(await fees.getPFee()/1e18);

            await vaultKeeper.connect(u1).harvest();
            console.log(await glpVault.pps()/1e16);

            expect(pps <= (await glpVault.pps()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(10700)
            expect(Math.round(await wETH.balanceOf(fees.getTreasury())/1e18)).to.equal(280);
            expect(Math.round(await wETH.balanceOf(oliveManager.address)/1e18)).to.equal(20);
            expect(Math.round(await oliveManager.earned(u3.address))/1e18).to.equal(20);
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(0);
            expect(Math.round(await glpVault.pps()/1e16)).to.equal(107); // PPS = 1.07 post first harvest

            expect(Math.round(await oGlp.balanceOf(u1.address)/1e18)).to.equal(10000);

            // Close user position
            console.log('-- user1 --');
            console.log('Postion: ', await glpVault.getPosition(u1.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u1.address)/1e18);

            // Continued testing where u2 deposits

            // deposit 10000 tokens at 5x leverage
            await glp.connect(u2).approve(vaultManager.address, toN(9900));
            await glp.mint(u2.address, toN(2000));
            await vaultManager.connect(u2).deposit(toN(2000), toN(5), 0, 0);

            expect(Math.round(await oGlp.balanceOf(u2.address)/1e16)).to.equal(934579);
            expect(Math.round(await glpVault.getPosition(u2.address)/1e18)).to.equal(10000);

            await glpMockRouter.setFeesToClaim(toN(2000)); // 10% yield

            pps = (await glpVault.pps()/1e16);
            time.increase(365 * 24 * 3600); // After one year
            await vaultKeeper.connect(u1).harvest();
            
            expect(pps <= (await glpVault.pps()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(22086)
            expect(Math.round(await wETH.balanceOf(fees.getTreasury())/1e18)).to.equal(854);
            expect(Math.round(await wETH.balanceOf(oliveManager.address)/1e18)).to.equal(60);
            expect(Math.round(await oliveManager.earned(u3.address))/1e18).to.equal(60);
            await expect(await oliveManager.connect(u3).getReward()).not.to.be.reverted;
            expect(Math.round(await wETH.balanceOf(u3.address)/1e18)).to.equal(60);
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(0);
            expect(Math.round(await glpVault.pps()/1e16)).to.equal(114); // PPS = 1.07 post first harvest

            // Close user1 position
            expect(Math.round(await glpVault.getPosition(u1.address)/1e18)).to.equal(11416); //11416.43549926885
            expect(Math.round(await glpVault.getDebt(u1.address)/1e18)).to.equal(8495); //8494.692708
            expect(Math.round(await vaultManager.getBurnableShares(u1.address)/1e18)).to.equal(699); //699.053285916824196
            await vaultManager.connect(u1).deleverage(toN(1), 0, 0);
            expect(Math.round(await glpVault.getDebt(u1.address)/1e18)).to.equal(0);
            expect(Math.round(await vaultManager.getBurnableShares(u1.address)/1e8)).to.equal(25592427726311);
            expect(Math.round(await oGlp.balanceOf(u1.address)/1e8)).to.equal(25592427737260); //oGLP balance
            await vaultManager.connect(u1).withdraw(toN(25592427726311, 8), 0, 0);
            expect(Math.round(await oGlp.balanceOf(u1.address)/1e10)).to.equal(109);
            console.log('hf: ', await glpVault.hf(u1.address)/1e18);
            console.log('-- ***** --');

            // close user2 position
            console.log('-- user2 --');
            console.log('Postion: ', await glpVault.getPosition(u2.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u2.address)/1e18);
            console.log('Debt', await vaultManager.getLeverage(u2.address)/1e18);

            // Close user2 position
            expect(Math.round(await glpVault.getPosition(u2.address)/1e18)).to.equal(10670); //10669.565171046104
            expect(Math.round(await glpVault.getDebt(u2.address)/1e18)).to.equal(8244); //8243.636043
            expect(Math.round(await vaultManager.getBurnableShares(u2.address)/1e18)).to.equal(320); //319.732148498549440000
            await vaultManager.connect(u2).deleverage(toN(1), 0, 0);
            expect(Math.round(await glpVault.getDebt(u2.address)/1e18)).to.equal(0);
            console.log('burnable: ', await vaultManager.getBurnableShares(u2.address)/1e18);
            expect(Math.round(await vaultManager.getBurnableShares(u2.address)/1e18)).to.equal(2125); // 2124.944605802821
            expect(Math.round(await oGlp.balanceOf(u2.address)/1e18)).to.equal(2125); //oGLP balance // 2124.944606897734
            await vaultManager.connect(u2).withdraw(toN(2124.944605802821, 18), 0, 0);
            expect(Math.round(await oGlp.balanceOf(u2.address)/1e10)).to.equal(109);
            console.log('hf: ', await glpVault.hf(u2.address)/1e18);

            expect(Math.round(await glp.balanceOf(stgy.address)/1e10)).to.equal(250); // Everything is withdrawn nothing pending in strategy expect dust balance
    });
});