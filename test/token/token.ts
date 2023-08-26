import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { toN, deployGLPVault } from "../utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Token checks", function(){

    it("D token checks", async function(){
        const {u1, u2, doUSDC, vaultManager} = await loadFixture(deployGLPVault);
        expect(await doUSDC.name()).to.equal("DOUSDC Token");
        expect(await doUSDC.symbol()).to.equal("doUSDC");
        expect(await doUSDC.decimals()).to.equal(6);
        expect (await doUSDC.totalSupply()).to.equal(0);

        await vaultManager.connect(u1).deposit(toN(100), toN(5), 0, 0);
        expect (Math.ceil(await doUSDC.balanceOf(u1.address)/1e6)).to.equal(400);

        // debt tokens are non transferable
        await expect(doUSDC.connect(u1).transfer(u2.address, toN(100))).to.be.reverted;

    });

    it("A token checks", async function(){
        const {u1, u2, usdc, pool, aUSDC} = await loadFixture(deployGLPVault);
        expect(await aUSDC.name()).to.equal("AUSDC Token");
        expect(await aUSDC.symbol()).to.equal("aUSDC");
        expect(await aUSDC.decimals()).to.equal(6);
        expect(await usdc.decimals()).to.equal(6);
        await usdc.mint(u1.address, toN(100, 6));
        await usdc.connect(u1).approve(pool.address, toN(100, 6));
        await pool.connect(u1).supply(toN(100, 6));
        expect(Math.ceil(await aUSDC.balanceOf(u1.address)/1e6)).to.equal(100, 6);
        await expect(aUSDC.connect(u1).transfer(u2.address, toN(50, 6))).not.to.be.reverted;
    });

    it("O Token checks", async function(){
        const {u1, u2, u3,  oGlp, vaultManager, glpVault} = await loadFixture(deployGLPVault);
        await oGlp.setVaultCore(glpVault.address);

        expect(await oGlp.name()).to.equal("oGLP Token");
        expect(await oGlp.symbol()).to.equal("oGLP");
        expect(await oGlp.decimals()).to.equal(18);
        expect (await oGlp.totalSupply()).to.equal(0);

        await vaultManager.connect(u1).deposit(toN(100), toN(5), 0, 0);

        await expect(oGlp.connect(u1).transfer(u2.address, toN(100))).to.be.reverted; // hf check
        expect (await oGlp.balanceOf(u2.address)).to.equal(toN(0));
        expect (await oGlp.balanceOf(u1.address)).to.equal(toN(500));
        await expect(oGlp.connect(u1).transfer(u2.address, toN(1))).not.to.be.reverted; // hf check holds
        expect (await oGlp.balanceOf(u2.address)).to.equal(toN(1));
        expect (await oGlp.balanceOf(u1.address)).to.equal(toN(499));

        await oGlp.connect(u1).approve(u3.address, toN(100));
        await expect(oGlp.connect(u3).transferFrom(u1.address, u2.address, toN(100))).to.be.reverted; 
        expect (await oGlp.balanceOf(u2.address)).to.equal(toN(1));
        expect (await oGlp.balanceOf(u1.address)).to.equal(toN(499));
        console.log(oGlp.allowance(u1.address, u3.address).toString());
        await expect(oGlp.connect(u3).transferFrom(u1.address, u2.address, toN(1))).not.to.be.reverted;
        expect (await oGlp.balanceOf(u2.address)).to.equal(toN(2));
        expect (await oGlp.balanceOf(u1.address)).to.equal(toN(498));
    });


});