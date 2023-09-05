import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, web3 } from "hardhat";
import { toN, deployGLPVaultKeeper } from "../utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Reality checks", function(){
    it("10% APY - Target PPS : ~1.07", async function(){
        const {owner, u1, usdc, glp, wETH, phMock, pool, 
             vaultKeeper, vaultManager, glpVault, fees, stgy, glpMockRouter} = await loadFixture(deployGLPVaultKeeper);

            // deposit 10000 tokens at 5x leverage
            await glp.approve(vaultManager.address, toN(9900));
            await glp.mint(u1.address, toN(9900));
            await vaultManager.connect(u1).deposit(toN(1900), toN(5), 0, 0);
            
            // 10% APY 
            time.increaseTo(365 * 24 * 3600); // After one year
            console.log(await usdc.balanceOf(pool.address)/1e6);
            await phMock.setPriceOf(wETH.address, toN(1));
            console.log(await glp.balanceOf(stgy.address)/1e18);
            await glpMockRouter.setFeesToClaim(toN(1000)); // 10% yield

            

            let pps = (await glpVault.pps()/1e16);
            await time.increase(365 * 24 * 3600);
            await vaultKeeper.connect(u1).harvest();
            expect(pps <= (await glpVault.pps()/1e16)).to.equal(true);
            expect(Math.round(await glp.balanceOf(stgy.address)/1e18)).to.equal(505)
            expect(Math.round(await fees.getAccumulatedFee()/1e18)).to.equal(6);
    });
});