import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { toN, deployLendingPool, setupLendingPool } from "../utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Lending pool tests", function(){
    describe("Basic checks", function(){
        it("Owner check", async function(){
            const {owner, pool} = await setupLendingPool();
            expect(await pool.getOwner()).to.equal(owner.address);
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
            const {owner, u1, u2, usdc, aUSDC, pool} = await setupLendingPool();
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
            await pool.connect(u1).withdraw(toN(200));
            expect(await usdc.balanceOf(pool.address)).to.equal(toN(0));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(0));
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
            expect(await pool.getDebt(u2.address)).to.equal(ethers.utils.parseUnits('500002425804969076000', 0));
            expect(await pool.getBalance(u1.address)).to.equal(ethers.utils.parseUnits('1000001617199391171000', 0));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(1000));
            expect(await doUSDC.balanceOf(u2.address)).to.equal(toN(500));
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
            expect(await pool.getDebt(u2.address)).to.equal(ethers.utils.parseUnits('521768709221334598000', 0));
            expect(await pool.getBalance(u1.address)).to.equal(ethers.utils.parseUnits('1014205479452054793000', 0));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(1000));
            expect(await doUSDC.balanceOf(u2.address)).to.equal(toN(500));
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
            expect(await pool.getDebt(u2.address)).to.equal(ethers.utils.parseUnits('521768709221334598000', 0));
            expect(await pool.getBalance(u1.address)).to.equal(ethers.utils.parseUnits('1014205479452054793000', 0));
            expect(await aUSDC.balanceOf(u1.address)).to.equal(toN(1000));
            expect(await doUSDC.balanceOf(u2.address)).to.equal(toN(500));
            await usdc.connect(owner).mint(u2.address, toN(30));
            await pool.connect(u2).repay(u2.address, u2.address, ethers.utils.parseUnits('521768709221334598000', 0));
            expect(await doUSDC.balanceOf(u2.address)).to.equal(ethers.utils.parseUnits('1347649496660', 0));
            await time.increase(366*24*3600); // should not generate interest
            expect(await pool.getBalance(u1.address)).to.equal(ethers.utils.parseUnits('1014205480436311369000', 0));
        });
    });
});