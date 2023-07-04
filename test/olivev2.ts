import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { toN, deployLendingPool, setupLendingPool, deployOlive } from "./utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Olive checks", function(){

    describe("Basic checks", function(){
        it("Owner check", async function(){
            const {owner, olive, oGlp} = await loadFixture(deployOlive);
            expect(await olive.getOwner()).to.equal(owner.address);
            expect(await oGlp.getOwner()).to.equal(owner.address);
        });
    });

    describe("Deposit checks", function(){
        it("Deposit 1000GLP, no leverage", async function(){
            const {owner, glp, u1, olive, oGlp} = await loadFixture(deployOlive);
            await olive.connect(u1).deposit(toN(1000), toN(1), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(1000));
        });

        it("Deposit 1000GLP, with leverage", async function(){
            const {owner, glp, u1, olive, oGlp, doUSDC} = await loadFixture(deployOlive);
            await olive.connect(u1).deposit(toN(1000), toN(2), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(2000));
            expect(await doUSDC.balanceOf(u1.address)).to.equal(toN(1000));
        });

        it("Deposit 1000GLP, with leverage & leverage increment", async function(){
            const {owner, glp, u1, olive, oGlp, doUSDC, pool} = await loadFixture(deployOlive);
            await olive.connect(u1).deposit(toN(1000), toN(2), 0, 0);
            expect(await oGlp.balanceOf(u1.address)).to.equal(toN(2000));
            expect(await doUSDC.balanceOf(u1.address)).to.equal(toN(1000));
            await olive.connect(u1).leverage(toN(5), 0, 0);
            expect(await pool.getDebt(u1.address)).to.equal(ethers.utils.parseUnits('3999999995762418708243',0));
            await time.increase(365*24*3600);
            expect(await oGlp.balanceOf(u1.address)).to.equal(ethers.utils.parseUnits('4999999994703023385244',0));
            expect(await pool.getDebt(u1.address)).to.equal(ethers.utils.parseUnits('4169652510623393934315',0));
            await time.increase(365*24*3600);
            expect(await olive.hf(u1.address)).to.equal(ethers.utils.parseUnits('1150352578812794231', 0));
            expect(await pool.getDebt(u1.address)).to.equal(ethers.utils.parseUnits('4346493489729214609570',0));
            await time.increase(365*24*3600);
            expect(await olive.hf(u1.address)).to.equal(ethers.utils.parseUnits('1103555525750493141', 0));
            expect(await pool.getDebt(u1.address)).to.equal(ethers.utils.parseUnits('4530809622200642635780',0));
            await time.increase(365*24*3600);
            expect(await olive.hf(u1.address)).to.equal(ethers.utils.parseUnits('1058674357973564774', 0));
            expect(await pool.getDebt(u1.address)).to.equal(ethers.utils.parseUnits('4722887597158439898717',0));
        });
    });

    describe("Withdraw checks", function(){

    });
});