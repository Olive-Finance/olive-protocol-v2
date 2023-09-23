import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, tasks, web3 } from "hardhat";
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
        
            let pps = (await glpVault.getPPS()/1e16);
            time.increase(365 * 24 * 3600); // After one year

            console.log(await fees.getMFee()/1e18);
            console.log(await fees.getPFee()/1e18);

            await vaultKeeper.connect(u1).harvest();
            console.log(await glpVault.getPPS()/1e16);

            expect(pps <= (await glpVault.getPPS()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(10700)
            expect(Math.round(await wETH.balanceOf(fees.getTreasury())/1e18)).to.equal(280);
            expect(Math.round(await wETH.balanceOf(oliveManager.address)/1e18)).to.equal(20);
            expect(Math.round(await oliveManager.earned(u3.address))/1e18).to.equal(20);
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(0);
            expect(Math.round(await glpVault.getPPS()/1e16)).to.equal(107); // PPS = 1.07 post first harvest
            expect(Math.round(await stgy.pps()/1e16)).to.equal(107); // PPS = 1.07 post harvest at strategy

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

            pps = (await glpVault.getPPS()/1e16);
            time.increase(365 * 24 * 3600); // After one year
            await vaultKeeper.connect(u1).harvest();
            
            expect(pps <= (await glpVault.getPPS()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(22086)
            expect(Math.round(await wETH.balanceOf(fees.getTreasury())/1e18)).to.equal(854);
            expect(Math.round(await wETH.balanceOf(oliveManager.address)/1e18)).to.equal(60);
            expect(Math.round(await oliveManager.earned(u3.address))/1e18).to.equal(60);
            await expect(await oliveManager.connect(u3).getReward()).not.to.be.reverted;
            expect(Math.round(await wETH.balanceOf(u3.address)/1e18)).to.equal(60);
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(0);
            expect(Math.round(await glpVault.getPPS()/1e16)).to.equal(114); // PPS = 1.14 post first harvest
            expect(Math.round(await stgy.pps()/1e16)).to.equal(114); // PPS = 1.14 post harvest at strategy

            // Close user1 position
            expect(Math.round(await glpVault.getPosition(u1.address)/1e18)).to.equal(11416); //11416.43549926885
            expect(Math.round(await glpVault.getDebt(u1.address)/1e18)).to.equal(8495); //8494.692708
            expect(Math.round(await vaultManager.getBurnableShares(u1.address)/1e18)).to.equal(699); //699.053285916824196
            await vaultManager.connect(u1).deleverage(toN(1), 0, 0);
            expect(Math.round(await glpVault.getDebt(u1.address)/1e18)).to.equal(0);
            expect(Math.round(await vaultManager.getBurnableShares(u1.address)/1e18)).to.equal(2559); //2559.2427715362
            expect(Math.round(await oGlp.balanceOf(u1.address)/1e16)).to.equal(255924); //oGLP balance
            await vaultManager.connect(u1).withdraw(toN(2559.24, 18), 0, 0);
            expect(Math.round(await oGlp.balanceOf(u1.address)/1e14)).to.equal(28);
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
            await vaultManager.connect(u2).withdraw(toN(2124.94, 18), 0, 0);
            expect(Math.round(await oGlp.balanceOf(u2.address)/1e14)).to.equal(46);
            console.log('hf: ', await glpVault.hf(u2.address)/1e18);

            expect(Math.round(await glp.balanceOf(stgy.address)/1e15)).to.equal(8); // Everything is withdrawn nothing pending in strategy expect dust balance
    });


    it("12% APY - Target PPS : ~1.088", async function(){
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
            await glpMockRouter.setFeesToClaim(toN(1200)); // 12% yield
        
            let pps = (await glpVault.getPPS()/1e16);
            time.increase(365 * 24 * 3600); // After one year

            console.log(await fees.getMFee()/1e18);
            console.log(await fees.getPFee()/1e18);

            await vaultKeeper.connect(u1).harvest();
            console.log(await glpVault.getPPS()/1e16);

            expect(pps <= (await glpVault.getPPS()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(10880)
            expect(Math.round(await wETH.balanceOf(fees.getTreasury())/1e18)).to.equal(296);
            expect(Math.round(await wETH.balanceOf(oliveManager.address)/1e18)).to.equal(24);
            expect(Math.round(await oliveManager.earned(u3.address))/1e18).to.equal(24);
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(0);
            expect(Math.round(await glpVault.getPPS()/1e16)).to.equal(109); // PPS = 1.088 post first harvest
            expect(Math.round(await stgy.pps()/1e16)).to.equal(109); // PPS = 1.088 post harvest at strategy

            expect(Math.round(await oGlp.balanceOf(u1.address)/1e18)).to.equal(10000);

            // Close user position
            console.log('-- user1 --');
            console.log('Postion: ', await glpVault.getPosition(u1.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u1.address)/1e18);

            // Continued testing where u2 deposits

            // deposit 100 tokens at 5x leverage
            await glp.connect(u2).approve(vaultManager.address, toN(9900));
            await glp.mint(u2.address, toN(2000));
            await vaultManager.connect(u2).deposit(toN(100), toN(5), 0, 0);

            expect(Math.round(await oGlp.balanceOf(u2.address)/1e16)).to.equal(45956);
            expect(Math.round(await glpVault.getPosition(u2.address)/1e18)).to.equal(500);

            await glpMockRouter.setFeesToClaim(toN(2048.4)); // 18% yield

            pps = (await glpVault.getPPS()/1e16);
            time.increase(365 * 24 * 3600); // After one year
            await vaultKeeper.connect(u1).harvest();
            
            expect(pps <= (await glpVault.getPPS()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(12996)
            expect(Math.round(await wETH.balanceOf(fees.getTreasury())/1e18)).to.equal(687);
            expect(Math.round(await wETH.balanceOf(oliveManager.address)/1e15)).to.equal(64968);
            expect(Math.round(await oliveManager.earned(u3.address))/1e15).to.equal(64968);
            await expect(await oliveManager.connect(u3).getReward()).not.to.be.reverted;
            expect(Math.round(await wETH.balanceOf(u3.address)/1e18)).to.equal(65);
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(0);
            expect(Math.round(await glpVault.getPPS()/1e16)).to.equal(124); // PPS = 1.24 post first harvest
            expect(Math.round(await stgy.pps()/1e16)).to.equal(124); // PPS = 1.24 post harvest at strategy

            // Close user1 position
            expect(Math.round(await glpVault.getPosition(u1.address)/1e18)).to.equal(12425); 
            expect(Math.round(await glpVault.getDebt(u1.address)/1e18)).to.equal(8495); //8494.692708
            expect(Math.round(await vaultManager.getBurnableShares(u1.address)/1e18)).to.equal(1454); 
            await vaultManager.connect(u1).deleverage(toN(1), 0, 0);
            expect(Math.round(await glpVault.getDebt(u1.address)/1e18)).to.equal(0);
            expect(Math.round(await vaultManager.getBurnableShares(u1.address)/1e18)).to.equal(3163);
            expect(Math.round(Math.round(await oGlp.balanceOf(u1.address)/1e18))).to.equal(3163); //oGLP balance
            await vaultManager.connect(u1).withdraw(toN(3163.20, 18), 0, 0);
            expect(Math.round(await oGlp.balanceOf(u1.address)/1e14)).to.equal(38);
            console.log('hf: ', await glpVault.hf(u1.address)/1e18);
            console.log('-- ***** --');

            // close user2 position
            console.log('-- user2 --');
            console.log('Postion: ', await glpVault.getPosition(u2.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u2.address)/1e18);
            console.log('Debt', await vaultManager.getLeverage(u2.address)/1e18);

            // Close user2 position
            expect(Math.round(await glpVault.getPosition(u2.address)/1e18)).to.equal(571); 
            expect(Math.round(await glpVault.getDebt(u2.address)/1e18)).to.equal(412); 
            expect(Math.round(await vaultManager.getBurnableShares(u2.address)/1e18)).to.equal(45); 
            await vaultManager.connect(u2).deleverage(toN(1), 0, 0);
            expect(Math.round(await glpVault.getDebt(u2.address)/1e18)).to.equal(0);
            console.log('burnable: ', await vaultManager.getBurnableShares(u2.address)/1e18);
            expect(Math.round(await vaultManager.getBurnableShares(u2.address)/1e18)).to.equal(128); //127.82189521
            expect(Math.round(await oGlp.balanceOf(u2.address)/1e18)).to.equal(128); //oGLP balance 
            await vaultManager.connect(u2).withdraw(toN(127.82, 18), 0, 0);
            expect(Math.round(await oGlp.balanceOf(u2.address)/1e14)).to.equal(19);
            console.log('hf: ', await glpVault.hf(u2.address)/1e18);

            expect(Math.round(await glp.balanceOf(stgy.address)/1e14)).to.equal(71); // Everything is withdrawn nothing pending in strategy expect dust balance
    });


    it("10% APY - Target PPS : ~1.07 | Liquidation | Stakes | Excess", async function(){
        const {owner, u1, u2, u3, usdc, glp, wETH, phMock, pool, oGlp,
             vaultKeeper, vaultManager, glpVault, fees, stgy, glpMockRouter, glpMockManager, oliveManager} = await loadFixture(deployGLPVaultKeeper);

            // deposit 10000 tokens at 5x leverage
            await glp.approve(vaultManager.address, toN(9900));
            await glp.mint(u1.address, toN(9900));
            await vaultManager.connect(u1).deposit(toN(1900), toN(5), 0, 0);
            
            // 10% APY 
            await phMock.setPriceOf(wETH.address, toN(1));
            await glpMockRouter.setFeesToClaim(toN(1000)); // 10% yield
            let pps = (await glpVault.getPPS()/1e16);
            time.increase(365 * 24 * 3600); // After one year
            await vaultKeeper.connect(u1).harvest();
            console.log(await glpVault.getPPS()/1e16);

            
            // Close user position
            console.log('-- user1 --');
            console.log('Postion: ', await glpVault.getPosition(u1.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u1.address)/1e18);

            // deposit 100 Tokens, his position would be liquidated
            await glp.connect(u2).approve(vaultManager.address, toN(10000));
            await glp.mint(u2.address, toN(100));
            await vaultManager.connect(u2).deposit(toN(100), toN(5), 0, 0);

            expect(Math.round(await oGlp.balanceOf(u2.address)/1e16)).to.equal(46729);
            expect(Math.round(await glpVault.getPosition(u2.address)/1e18)).to.equal(500);

            time.increase(365 * 24 * 3600); // After one year
            await glpMockManager.setPriceOfGLP(toN(0.9, 30));
            console.log('\n\n-- user1 --');
            console.log('Postion: ', await glpVault.getPosition(u2.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u2.address)/1e18);
            console.log('Hf', await glpVault.hf(u2.address)/1e18);

            await usdc.mint(owner.address, toN(500, 6));
            await vaultKeeper.setLiquidator(owner.address, true);
            await usdc.approve(pool.address, toN(415, 6));
            await vaultKeeper.liquidation(u2.address, toN(415, 6), true);

            console.log('oGLP : ', await oGlp.balanceOf(u2.address)/1e18);
            console.log('Postion: ', await glpVault.getPosition(u2.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u2.address)/1e18);
            console.log('Hf', await glpVault.hf(u2.address)/1e18);

            console.log('\n\n-- liquidator --');
            console.log('oGLP : ', await oGlp.balanceOf(owner.address)/1e18);
            console.log('Postion: ', await glpVault.getPosition(owner.address)/1e18);
            console.log('Debt', await glpVault.getDebt(owner.address)/1e18);
            console.log('Hf', await glpVault.hf(owner.address)/1e18);

            console.log('\n\n-- treasury --');
            let ta = await fees.getTreasury();
            console.log('oGLP : ', await oGlp.balanceOf(ta)/1e18);
            console.log('Postion: ', await glpVault.getPosition(ta)/1e18);
            console.log('Debt', await glpVault.getDebt(ta)/1e18);
            console.log('Hf', await glpVault.hf(ta)/1e18);

            // -- user1 --
            // Postion:  500
            // Debt 457.9797766666667
            // Hf 0.982576137477628
            // want allowance: 415000000
            // toPayInAsset: 412181800
            // oGLP :  17.870311685201887
            // Postion:  19.121233333333333
            // Debt 0.000001111111111111
            // Hf 15488199.000001548


            // -- liquidator --
            // oGLP :  445.13922721432135
            // Postion:  476.2989688888889
            // Debt 0
            // Hf 1.157920892373162e+59


            // -- treasury --
            // oGLP :  4.280184877060782
            // Postion:  4.579797777777777
            // Debt 0
            // Hf 1.157920892373162e+59
            
            expect(Math.round(await oGlp.balanceOf(u2.address)/1e18)).to.equal(18);
            expect(Math.round(await oGlp.balanceOf(owner.address)/1e18)).to.equal(445);
            expect(Math.round(await oGlp.balanceOf(ta)/1e18)).to.equal(4);
    });


    it("10% APY - Target PPS : ~1.07 | Liquidation | UnStakes | Excess", async function(){
        const {owner, u1, u2, usdc, glp, wETH, phMock, pool, oGlp,
             vaultKeeper, vaultManager, glpVault, fees, glpMockRouter, glpMockManager} = await loadFixture(deployGLPVaultKeeper);

            // deposit 10000 tokens at 5x leverage
            await glp.approve(vaultManager.address, toN(9900));
            await glp.mint(u1.address, toN(9900));
            await vaultManager.connect(u1).deposit(toN(1900), toN(5), 0, 0);
            
            // 10% APY 
            await phMock.setPriceOf(wETH.address, toN(1));
            await glpMockRouter.setFeesToClaim(toN(1000)); // 10% yield
            let pps = (await glpVault.getPPS()/1e16);
            time.increase(365 * 24 * 3600); // After one year
            await vaultKeeper.connect(u1).harvest();
            console.log(await glpVault.getPPS()/1e16);

            
            // Close user position
            console.log('-- user1 --');
            console.log('Postion: ', await glpVault.getPosition(u1.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u1.address)/1e18);

            // deposit 100 Tokens, his position would be liquidated
            await glp.connect(u2).approve(vaultManager.address, toN(10000));
            await glp.mint(u2.address, toN(100));
            await vaultManager.connect(u2).deposit(toN(100), toN(5), 0, 0);

            expect(Math.round(await oGlp.balanceOf(u2.address)/1e16)).to.equal(46729);
            expect(Math.round(await glpVault.getPosition(u2.address)/1e18)).to.equal(500);

            time.increase(365 * 24 * 3600); // After one year
            await glpMockManager.setPriceOfGLP(toN(0.9, 30));
            console.log('\n\n-- user1 --');
            console.log('Postion: ', await glpVault.getPosition(u2.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u2.address)/1e18);
            console.log('Hf', await glpVault.hf(u2.address)/1e18);

            await usdc.mint(owner.address, toN(500, 6));
            await vaultKeeper.setLiquidator(owner.address, true);
            await usdc.approve(pool.address, toN(415, 6));
            await vaultKeeper.liquidation(u2.address, toN(415, 6), false);

            console.log('oGLP : ', await oGlp.balanceOf(u2.address)/1e18);
            console.log('Postion: ', await glpVault.getPosition(u2.address)/1e18);
            console.log('Debt', await glpVault.getDebt(u2.address)/1e18);
            console.log('Hf', await glpVault.hf(u2.address)/1e18);

            console.log('\n\n-- liquidator --');
            console.log('oGLP : ', await oGlp.balanceOf(owner.address)/1e18);
            console.log('Postion: ', await glpVault.getPosition(owner.address)/1e18);
            console.log('Debt', await glpVault.getDebt(owner.address)/1e18);
            console.log('Hf', await glpVault.hf(owner.address)/1e18);

            console.log('\n\n-- treasury --');
            let ta = await fees.getTreasury();
            console.log('oGLP : ', await oGlp.balanceOf(ta)/1e18);
            console.log('Postion: ', await glpVault.getPosition(ta)/1e18);
            console.log('Debt', await glpVault.getDebt(ta)/1e18);
            console.log('Hf', await glpVault.hf(ta)/1e18);

            // -- user1 --
            // Postion:  500
            // Debt 457.9797766666667
            // Hf 0.982576137477628
            // want allowance: 415000000
            // toPayInAsset: 412181800
            // oGLP :  17.870311685201887
            // Postion:  19.121233333333333
            // Debt 0.000001111111111111
            // Hf 15488199.000001548


            // -- liquidator --
            // oGLP :  445.13922721432135
            // Postion:  476.2989688888889
            // Debt 0
            // Hf 1.157920892373162e+59


            // -- treasury --
            // oGLP :  4.280184877060782
            // Postion:  4.579797777777777
            // Debt 0
            // Hf 1.157920892373162e+59
            
            expect(Math.round(await oGlp.balanceOf(u2.address)/1e18)).to.equal(18);
            expect(Math.round(await oGlp.balanceOf(owner.address)/1e18)).to.equal(0);
            expect(Math.round(await glp.balanceOf(owner.address)/1e18)).to.equal(476);
            expect(Math.round(await oGlp.balanceOf(ta)/1e18)).to.equal(4);
    });
});