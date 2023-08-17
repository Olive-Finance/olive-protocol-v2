import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { toN, deployLendingPool } from "../utils";

describe ("Rate Calculator Tests", function(){

    describe("Basic checks", function(){
        it("set slopes - user has permissions", async function(){
            const {rcl, owner, u1} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setGov(u1.address);
            await rcl.connect(u1).setSlopes(toN(0.04), toN(0.04), toN(0.04));
            expect(await rcl._r0()).to.equal(toN(0.04));
            expect(await rcl._r1()).to.equal(toN(0.04));
            expect(await rcl._r2()).to.equal(toN(0.04));
        });

        it("set slopes - user don't have permissions", async function(){
            const {rcl, owner, u1} = await loadFixture(deployLendingPool);
            await expect(rcl.connect(u1).setSlopes(toN(0.04), toN(0.04), toN(0.04))).to.be.reverted;
            expect(await rcl._r0()).to.equal(toN(0.03));
            expect(await rcl._r1()).to.equal(toN(0.03));
            expect(await rcl._r2()).to.equal(toN(0.03));
        });

        it("set uo - user has permissions", async function(){
            const {rcl, owner, u1} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setGov(u1.address);
            await rcl.connect(u1).setUOpt(toN(0.04));
            expect(await rcl._uo()).to.equal(toN(0.04));

        });

        it("set uo - user don't have permissions", async function(){
            const {rcl, owner, u1} = await loadFixture(deployLendingPool);
            await expect(rcl.connect(u1).setUOpt(toN(0.04))).to.be.reverted;
            expect(await rcl._uo()).to.equal(toN(0.8));
        });
    });

    describe("Rate calculations", function(){
        // Borrow Rate Checks
        it("Borrow rate  - utilization = 0%", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setSlopes(toN(0.03), toN(0.06), toN(0.08));
            await rcl.connect(owner).setUOpt(toN(0.9));

            expect(await rcl.borrowRate(0)).to.equal(toN(0.03));
        });

        it("Borrow rate  - utilization = 45%", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setSlopes(toN(0.03), toN(0.06), toN(0.08));
            await rcl.connect(owner).setUOpt(toN(0.9));

            expect(await rcl.borrowRate(toN(0.45))).to.equal(toN(0.06));
        });

        it("Borrow rate  - utilization = 60%", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setSlopes(toN(0.03), toN(0.06), toN(0.08));
            await rcl.connect(owner).setUOpt(toN(0.9));

            expect(await rcl.borrowRate(toN(0.6))).to.equal(toN(0.07));
        });

        it("Borrow rate  - utilization = 90%", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setSlopes(toN(0.03), toN(0.06), toN(0.08));
            await rcl.connect(owner).setUOpt(toN(0.9));

            expect(await rcl.borrowRate(toN(0.9))).to.equal(toN(0.09));
        });

        it("Borrow rate  - utilization = 100%", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setSlopes(toN(0.03), toN(0.06), toN(0.08));
            await rcl.connect(owner).setUOpt(toN(0.9));

            expect(await rcl.borrowRate(toN(1))).to.equal(toN(0.17));
        });

        // Supply rate checks
        it("Supply rate  - utilization = 0%", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setSlopes(toN(0.03), toN(0.06), toN(0.08));
            await rcl.connect(owner).setUOpt(toN(0.9));

            expect(await rcl.supplyRate(0)).to.equal(0);
        });

        it("Supply rate  - utilization = 45%", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setSlopes(toN(0.03), toN(0.06), toN(0.08));
            await rcl.connect(owner).setUOpt(toN(0.9));

            expect(await rcl.supplyRate(toN(0.45))).to.equal(toN(0.027));
        });

        it("Supply rate  - utilization = 60%", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setSlopes(toN(0.03), toN(0.06), toN(0.08));
            await rcl.connect(owner).setUOpt(toN(0.9));

            expect(await rcl.supplyRate(toN(0.6))).to.equal(toN(0.042));
        });

        it("Supply rate  - utilization = 100%", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await rcl.connect(owner).setSlopes(toN(0.03), toN(0.06), toN(0.08));
            await rcl.connect(owner).setUOpt(toN(0.9));

            expect(await rcl.supplyRate(toN(1))).to.equal(toN(0.17));
        });
    });

    describe("Simple & Compound Checks", function(){
        // Simple Interest
        it("Simple Interest - 1 year", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            expect(await rcl.simpleInterest(toN(0.03), 0, 365*24*3600)).to.equal(toN(1.03));
        });

        it("Simple interest - 0 secs", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            expect(await rcl.simpleInterest(toN(0.03), 0, 0)).to.equal(toN(1));
        });

        it("Simple interest - failure, invalid time", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await expect(rcl.simpleInterest(toN(0.03), 1, 0)).to.be.reverted;
        });

        // Compound Interest
        it("Compund Interest - 1 year", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            expect(await rcl.compoundInterest(toN(0.03), 0, 365*24*3600))
            .to.equal(ethers.utils.parseUnits('1030454499968633952', 0));
        });

        it("Compund interest - 0 secs", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            expect(await rcl.compoundInterest(toN(0.03), 0, 0)).to.equal(toN(1));
        });

        it("Compund interest - failure, invalid time", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            await expect(rcl.compoundInterest(toN(0.03), 1, 0)).to.be.reverted;
        });

        // Incremental test
        it("Simple interest - Incremental time 2 secs", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            expect(await rcl.simpleInterest(toN(0.03), 0, 100)).to.equal(ethers.utils.parseUnits('1000000095129375951', 0));
            expect(await rcl.compoundInterest(toN(0.03), 0, 100)).to.equal(ethers.utils.parseUnits('1000000095129380379', 0));;
        });

        it("Simple interest - Incremental time 100 secs", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            expect(await rcl.simpleInterest(toN(0.03), 0, 2)).to.equal(ethers.utils.parseUnits('1000000001902587519', 0));
            expect(await rcl.compoundInterest(toN(0.03), 0, 2)).to.equal(ethers.utils.parseUnits('1000000001902587518', 0));
        });

        it("Simple interest - Incremental time, 1 day", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            expect(await rcl.simpleInterest(toN(0.03), 0, 24*3600)).to.equal(ethers.utils.parseUnits('1000082191780821917', 0));
            expect(await rcl.compoundInterest(toN(0.03), 0, 24*3600)).to.equal(ethers.utils.parseUnits('1000082195158575457', 0));
        });

        it("Simple interest - Incremental time, 100 days", async function(){
            const {owner, rcl} = await loadFixture(deployLendingPool);
            expect(await rcl.simpleInterest(toN(0.03), 0, 100*24*3600)).to.equal(ethers.utils.parseUnits('1008219178082191780', 0));
            expect(await rcl.compoundInterest(toN(0.03), 0, 100*24*3600)).to.equal(ethers.utils.parseUnits('1008253048058898197', 0));
        });
    });
});