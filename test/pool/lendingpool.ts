import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { toN, deployLendingPool, setupLendingPool } from "../utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { fees } from "../../typechain-types/contracts";

describe("Lending pool tests", function(){
    describe("Basic checks", function(){
        it("Owner check", async function(){
            const {owner, pool} = await setupLendingPool();
            expect(await pool.ownerAddr()).to.equal(owner.address);
        });
    });

    describe("Funding checks", function (){
        it("U1 - Funds 1000USDC token", async function(){
            const {owner, u1, u2, usdc, aUSDC, pool} = await setupLendingPool();
            expect(await usdc.balanceOf(pool.address)).to.equal(0);
            await pool.connect(u1).supply(toN(1000));
            expect(await usdc.balanceOf(pool.address)).to.equal(toN(1000));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(1000));
            
        });

        it("U1 - Funds 1000 + 200, No borrow, no interest", async function(){
            const {owner, u1, u2, usdc, aUSDC, pool} = await setupLendingPool();
            expect(await usdc.balanceOf(pool.address)).to.equal(0);
            await pool.connect(u1).supply(toN(1000));
            await time.increase(3600);
            await pool.connect(u1).supply(toN(200));
            expect(await usdc.balanceOf(pool.address)).to.equal(toN(1200));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(1200));
        });

        it("U1 - Get all amount back, 1000 USDC + 200 USDC - no borrow", async function(){
            const {owner, u1, u2, usdc, aUSDC, pool, doUSDC} = await setupLendingPool();
            expect(await usdc.balanceOf(pool.address)).to.equal(0);

            await pool.connect(u1).supply(toN(1000));
            await time.increase(3600);
            await pool.connect(u1).supply(toN(200));
            expect(await usdc.balanceOf(pool.address)).to.equal(toN(1200));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(1200));
            await time.increase(3600);
            expect(await pool.utilization()).to.equal(0);
            expect(await pool.getBalance(u1.address)).to.equal(toN(1200));

            await pool.connect(u1).withdraw(toN(1000));
            expect(await usdc.balanceOf(pool.address)).to.equal(toN(200));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(200));
            expect(await usdc.balanceOf(u1.address)).to.equal(toN(1800)); // use has been originally minted with 2000 tokens

            await pool.connect(u1).withdraw(toN(200));
            expect(await usdc.balanceOf(pool.address)).to.equal(toN(0));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(0));
            expect(await usdc.balanceOf(u1.address)).to.equal(toN(2000)); // use has been 
        });
    });

    describe("Funding checks", function (){
        it("U1 - Funds 1000USDC(t0) and U2 borrows 500USDC (t1), interest(t2)", async function(){
            const {owner, u1, u2, usdc, aUSDC, doUSDC, pool} = await setupLendingPool();
            expect(await usdc.balanceOf(pool.address)).to.equal(0);
            await pool.connect(u1).supply(toN(1000));
            await time.increase(3600);
            await pool.connect(u2).borrow(u2.address, u2.address, toN(500));
            expect(await usdc.balanceOf(pool.address)).to.equal(toN(500));
            expect(await usdc.balanceOf(u2.address)).to.equal(toN(500));
            await time.increase(3600); 
            expect(await pool.getDebt(u2.address)).to.equal(ethers.utils.parseUnits('500002782541986559789', 0));
            expect(await pool.getBalance(u1.address)).to.equal(ethers.utils.parseUnits('1000002782534246575000', 0));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(1000));
            expect(await doUSDC.balanceOf(u2.address)).to.equal(ethers.utils.parseUnits('499998287198521430909', 0));
        });

        it("U1 - Funds 1000USDC(t0) and U2 borrows 500USDC (t1), interest(t2)", async function(){
            const {owner, u1, u2, usdc, aUSDC, doUSDC, pool} = await setupLendingPool();
            expect(await usdc.balanceOf(pool.address)).to.equal(0);
            await pool.connect(u1).supply(toN(1000));
            await time.increase(24*3600);
            await pool.connect(u2).borrow(u2.address, u2.address, toN(500));
            expect(await usdc.balanceOf(pool.address)).to.equal(toN(500));
            expect(await usdc.balanceOf(u2.address)).to.equal(toN(500));
            await time.increase(366*24*3600); 
            expect(await pool.getDebt(u2.address)).to.equal(ethers.utils.parseUnits('525048915805549827185', 0));
            expect(await pool.getBalance(u1.address)).to.equal(ethers.utils.parseUnits('1024441780821917808000', 0));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(1000));
            expect(await doUSDC.balanceOf(u2.address)).to.equal(ethers.utils.parseUnits('499958905322848897865', 0)); 
        });

        it("U1 - Funds 1000USDC(t0) and U2 borrows 500USDC (t1), pays full at(t2)", async function(){
            const {owner, u1, u2, usdc, aUSDC, doUSDC, pool} = await setupLendingPool();
            expect(await usdc.balanceOf(pool.address)).to.equal(0);
            await pool.connect(u1).supply(toN(1000));
            await time.increase(24*3600);
            await pool.connect(u2).borrow(u2.address, u2.address, toN(500));
            expect(await usdc.balanceOf(pool.address)).to.equal(toN(500));
            expect(await usdc.balanceOf(u2.address)).to.equal(toN(500));
            await time.increase(366*24*3600); 
            expect(await pool.getDebt(u2.address)).to.equal(ethers.utils.parseUnits('525048915805549827185', 0));
            expect(await pool.getBalance(u1.address)).to.equal(ethers.utils.parseUnits('1024441780821917808000', 0));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(1000));
            expect(await doUSDC.balanceOf(u2.address)).to.equal(ethers.utils.parseUnits('499958905322848897865', 0));
            await usdc.connect(owner).mint(u2.address, toN(30));
            await pool.connect(u2).repay(u2.address, u2.address, u2.address, ethers.utils.parseUnits('525048915805549827185', 0));
            expect(await doUSDC.balanceOf(u2.address)).to.equal(ethers.utils.parseUnits('1545696645367', 0));
            await time.increase(366*24*3600); // should not generate interest
            expect(await pool.getBalance(u1.address)).to.equal(ethers.utils.parseUnits('1024441782416601568000', 0));
        });

        it("u1, u2, u3, u5 - Round Tripping - Scenarion", async function(){
            const {owner, u1, u2,u3, u5, treasury, usdc, aUSDC, doUSDC, pool} = await setupLendingPool();
            await usdc.mint(u1.address, toN(1000, 6));
            await usdc.connect(u1).approve(pool.address, toN(1000, 6));
            await time.increase(15);
            await usdc.mint(u2.address, toN(1000, 6));
            await usdc.connect(u2).approve(pool.address, toN(1000, 6));
            await time.increase(15);
            await usdc.mint(u3.address, toN(1000, 6));
            await usdc.connect(u3).approve(pool.address, toN(1000, 6));
            await time.increase(15);

            await pool.grantRole(u5.address);

            await pool.connect(u1).supply(toN(1000, 6));
            await pool.connect(u2).supply(toN(1000, 6));
            await pool.connect(u3).supply(toN(1000, 6));

            console.log(await usdc.balanceOf(pool.address)/1e6);

            await time.increase(15);
            await pool.connect(u5).borrow(u5.address, u5.address, toN(2200, 6));
            console.log(await usdc.balanceOf(pool.address)/1e6);

            await time.increase(24 * 3600);
            expect('u1: ', await pool.getBalance(u1.address)/1e6);
            console.log('u2: ', await pool.getBalance(u2.address)/1e6);
            console.log('u3: ', await pool.getBalance(u3.address)/1e6);
    
            console.log('u5: ', await pool.getDebt(u5.address)/1e6);
            console.log('fees: ', await pool.totalFees());
            await time.increase(24 * 3600);
            await usdc.mint(u1.address, toN(1, 6));
            await usdc.connect(u1).approve(pool.address, toN(1, 6));
            await pool.connect(u1).supply(toN(1, 6));
            console.log('fees: ', await pool.totalFees());
            await time.increase(24 * 3600);
            await usdc.mint(u1.address, toN(1, 6));
            await usdc.connect(u1).approve(pool.address, toN(1, 6));
            await pool.connect(u1).supply(toN(1, 6));
            console.log('fees: ', await pool.totalFees());

            console.log('0-----0')
            console.log('u1: ', await pool.getBalance(u1.address)/1e6);
            console.log('u2: ', await pool.getBalance(u2.address)/1e6);
            console.log('u3: ', await pool.getBalance(u3.address)/1e6);
            console.log('u5: ', await pool.getDebt(u5.address)/1e6);
            await time.increase(365* 24 * 3600);
            await usdc.mint(u5.address, toN(2331, 6));
            await usdc.connect(u5).approve(pool.address, toN(2331, 6));
            await pool.connect(u5).repay(u5.address, u5.address, u5.address, toN(2331, 6));
            console.log('0-----1')
            console.log('u1: ', await pool.getBalance(u1.address)/1e6);
            console.log('u2: ', await pool.getBalance(u2.address)/1e6);
            console.log('u3: ', await pool.getBalance(u3.address)/1e6);
            console.log('u5: ', await pool.getDebt(u5.address)/1e6);
            console.log('fees: ', await pool.totalFees());
            
            console.log('U1: ', await aUSDC.balanceOf(u1.address));
            console.log(await pool._available());
            console.log('Balance:' , await usdc.balanceOf(pool.address));
            await pool.connect(u1).withdraw(await aUSDC.balanceOf(u1.address));
            console.log('U2: ', await aUSDC.balanceOf(u2.address));
            console.log(await pool._available());
            console.log('Balance:' , await usdc.balanceOf(pool.address));
            await pool.connect(u2).withdraw(await aUSDC.balanceOf(u2.address));
            console.log('U3: ', await aUSDC.balanceOf(u3.address));
            console.log(await pool._available());
            console.log('Balance:' , await usdc.balanceOf(pool.address));
            await pool.connect(u3).withdraw(await aUSDC.balanceOf(u3.address));

            console.log('0-----2')
            console.log('u1: ', await pool.getBalance(u1.address)/1e6);
            console.log('u2: ', await pool.getBalance(u2.address)/1e6);
            console.log('u3: ', await pool.getBalance(u3.address)/1e6);
            console.log('u5: ', await pool.getDebt(u5.address)/1e6);

            console.log('fees: ', await pool.totalFees()/1e6);
            await pool.mintFees();
            console.log('Balance: ', await pool.getBalance(treasury.address)/1e6);
            console.log('Pending balance', await usdc.balanceOf(pool.address)/1e6);
        });


        it("u1, u2, u3, u5 - Bad Debt", async function(){
            const {owner, u1, u2,u3, u5, treasury, usdc, aUSDC, doUSDC, pool, fees} = await setupLendingPool();
            console.log("u1: ", await usdc.balanceOf(u1.address)/1e6);
            await usdc.mint(u1.address, toN(1000, 6));
            await usdc.connect(u1).approve(pool.address, toN(1000, 6));
            await time.increase(15);
            await usdc.mint(u2.address, toN(1000, 6));
            await usdc.connect(u2).approve(pool.address, toN(1000, 6));
            await time.increase(15);
            await usdc.mint(u3.address, toN(1000, 6));
            await usdc.connect(u3).approve(pool.address, toN(1000, 6));
            await time.increase(15);

            await pool.grantRole(u5.address);

            await pool.connect(u1).supply(toN(1000, 6));
            await pool.connect(u2).supply(toN(1000, 6));
            await pool.connect(u3).supply(toN(1000, 6));

            console.log(await usdc.balanceOf(pool.address)/1e6);

            await time.increase(15);
            await pool.connect(u5).borrow(u5.address, u5.address, toN(2200, 6));
            console.log(await usdc.balanceOf(pool.address)/1e6);

            await time.increase(24 * 3600);
            console.log('u1: ', await pool.getBalance(u1.address)/1e6);
            console.log('u2: ', await pool.getBalance(u2.address)/1e6);
            console.log('u3: ', await pool.getBalance(u3.address)/1e6);
            

            console.log('u5: ', await pool.getDebt(u5.address)/1e6);
            console.log('fees: ', await pool.totalFees());
            await time.increase(24 * 3600);
            await usdc.mint(u1.address, toN(1, 6));
            await usdc.connect(u1).approve(pool.address, toN(1, 6));
            await pool.connect(u1).supply(toN(1, 6));
            console.log('fees: ', await pool.totalFees());
            await time.increase(24 * 3600);
            await usdc.mint(u1.address, toN(1, 6));
            await usdc.connect(u1).approve(pool.address, toN(1, 6));
            await pool.connect(u1).supply(toN(1, 6));
            console.log('fees: ', await pool.totalFees());

            console.log('0-----0')
            console.log('u1: ', await pool.getBalance(u1.address)/1e6);
            console.log('u2: ', await pool.getBalance(u2.address)/1e6);
            console.log('u3: ', await pool.getBalance(u3.address)/1e6);
            console.log('u5: ', await pool.getDebt(u5.address)/1e6);
            await time.increase(365* 24 * 3600);
            await usdc.mint(u5.address, toN(2331, 6));
            await usdc.connect(u5).approve(pool.address, toN(2331, 6));
            console.log('bd-1: ', await doUSDC.balanceOf(treasury.address)/1e6);
            await pool.connect(u5).repayWithSettle(u5.address, u5.address, u5.address, toN(2000, 6), toN(1));
            console.log('bd0: ', await doUSDC.balanceOf(treasury.address)/1e6);
            console.log('0-----0')
            console.log('u1: ', await pool.getBalance(u1.address)/1e6);
            console.log('u2: ', await pool.getBalance(u2.address)/1e6);
            console.log('u3: ', await pool.getBalance(u3.address)/1e6);
            console.log('u5: ', await doUSDC.balanceOf(treasury.address)/1e6);
            console.log('fees: ', await pool.totalFees());
            
            //await pool.connect(u1).withdraw(await aUSDC.balanceOf(u1.address)); // todo validate withdraw amount
    
            //await pool.connect(u2).withdraw(await aUSDC.balanceOf(u2.address)); // todo validate withdraw amount

            //await pool.connect(u3).withdraw(await aUSDC.balanceOf(u3.address)); // todo validate withdraw amount
            
            await pool.mintFees();
            console.log('bd4: ', await doUSDC.balanceOf(treasury.address)/1e6);
            console.log('fees treasury:' , await doUSDC.balanceOf(await fees.getTreasury())/1e6);

            expect(Math.round(await doUSDC.balanceOf(treasury.address)/1e6)).to.equal(313);

            console.log('0-----0')
            console.log('u1: ', await pool.getBalance(u1.address)/1e6);
            console.log('u2: ', await pool.getBalance(u2.address)/1e6);
            console.log('u3: ', await pool.getBalance(u3.address)/1e6);

            console.log('u5: ', await pool.getDebt(u5.address)/1e6);

            console.log('fees: ', await pool.totalFees()/1e6);
            
            console.log('Balance: ', await pool.getBalance(treasury.address)/1e6);
            console.log('Pending balance', await usdc.balanceOf(pool.address)/1e6);

            console.log("u1 : ", await usdc.balanceOf(u1.address)/1e6);
            console.log("u2 : ", await usdc.balanceOf(u2.address)/1e6);
            console.log("u3 : ", await usdc.balanceOf(u3.address)/1e6);
            
            console.log("u1 1: ", await aUSDC.balanceOf(u1.address)/1e6);
            console.log("u2 1: ", await aUSDC.balanceOf(u2.address)/1e6);
            console.log("u3 1: ", await aUSDC.balanceOf(u3.address)/1e6);

        });


        it("u1, u2, u3, u5 - Fees Test", async function(){
            const {owner, u1, u2,u3, u5, treasury, usdc, aUSDC, doUSDC, pool, limit} = await setupLendingPool();
            console.log("u1: ", await usdc.balanceOf(u1.address)/1e6);
            // Supply
            await usdc.mint(u1.address, toN(2, 12)); // a million to supply
            await usdc.connect(u1).approve(pool.address, toN(1, 24));
            await pool.connect(u1).supply(toN(1, 12));
            console.log("Fee value post supply: ", await pool.totalFees());
            console.log("Reserve1: ", await pool.reserve());

            // Borrow
            await limit.setLimit(u5.address, toN(1, 12));
            await pool.grantRole(u5.address);
            await pool.connect(u5).borrow(u5.address, u5.address, toN(0.5, 12)); // borrow half a million
            console.log("Fee value post borrow: ", await pool.totalFees());
            console.log("Reserve2: ", await pool.reserve());
            

            await time.increase(24 * 3600 * 365);

            await pool.connect(u1).supply(10); // supply a 1e-6 for calculating the fees
            console.log("Reserve3: ", await pool.reserve());
            console.log("Fee value: ", await pool.totalFees());


        });

    });
});