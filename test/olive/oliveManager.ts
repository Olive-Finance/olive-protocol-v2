import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { toN, deployOliveManager } from "../utils";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("oliveManager checks", function () {
  describe("Deployment checks", function () {
    it("Deployment checks", async function () {
      const { owner, oliveManager } = await loadFixture(deployOliveManager);
      expect(await oliveManager.ownerAddr()).to.equal(owner.address);
    });

    it("Only Owner can checks - u1 not owner ", async function () {
      const { owner, u1, oliveManager, esOlive, olive} =
        await loadFixture(deployOliveManager);
      await expect(oliveManager.connect(u1).setMinVestingPeriod(5 * 24 * 3600)).to.be.reverted;
      await expect(oliveManager.connect(u1).setMaxVestingPeriod(30 * 24 * 3600)).to.be.reverted;
      await expect(oliveManager.connect(u1).setTokens(olive.address, esOlive.address)).to.be.reverted;
      await expect(oliveManager.connect(u1).setFees(owner.address)).to.be.reverted;
      await expect(oliveManager.connect(u1).setRewardToken(owner.address)).to.be.reverted;
    });

    it("Only Owner can checks - u1 is owner ", async function () {
      const { owner, u1, oliveManager, olive, esOlive} = await loadFixture(deployOliveManager);
      await oliveManager.setOwner(u1.address);
      await expect(oliveManager.connect(u1).setMinVestingPeriod(5 * 24 * 3600)).not.to.be.reverted;
      await expect(oliveManager.connect(u1).setMaxVestingPeriod(30 * 24 * 3600)).not.to.be.reverted;
      await expect(oliveManager.connect(u1).setTokens(olive.address, esOlive.address)).not.to.be.reverted;
      await expect(oliveManager.connect(u1).setFees(owner.address)).not.to.be.reverted;
      await expect(oliveManager.connect(u1).setRewardToken(owner.address)).not.to.be.reverted;
    });

    it("Invalid input checks ", async function () {
      const { owner, u1, oliveManager, olive, esOlive} = await loadFixture(deployOliveManager);
      await oliveManager.setOwner(u1.address);
      await expect(oliveManager.connect(u1).setMinVestingPeriod(3600)).to.be.reverted;
      await expect(oliveManager.connect(u1).setMaxVestingPeriod(3600)).to.be.reverted;
      await expect(oliveManager.connect(u1).setRewardToken(ethers.constants.AddressZero)).to.be.reverted;
      await expect(oliveManager.connect(u1).setTokens(ethers.constants.AddressZero, ethers.constants.AddressZero)).to.be.reverted;
      await expect(oliveManager.connect(u1).setRewardToken(ethers.constants.AddressZero)).to.be.reverted;
      await expect(oliveManager.connect(u1).setRewardToken(oliveManager.address)).to.be.reverted;
      await expect(oliveManager.connect(u1).setTokens(ethers.constants.AddressZero, esOlive.address)).to.be.reverted;
      await expect(oliveManager.connect(u1).setTokens(olive.address, ethers.constants.AddressZero)).to.be.reverted;
      await expect(oliveManager.connect(u1).setTokens(ethers.constants.AddressZero, ethers.constants.AddressZero)).to.be.reverted;
    });

    it("Happy path sanity checks", async function () {
      const { u1, oliveManager, esOlive, olive , owner} = await loadFixture(deployOliveManager);
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(100);
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(0);
      await oliveManager.connect(u1).unstake(toN(100), 60);
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(0);
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(0);
      await time.increase(65 * 24 * 3600);
      await oliveManager.connect(u1).withdraw();
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(100);
      await oliveManager.connect(u1).stake(await olive.balanceOf(u1.address));
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(100);
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(0);
      expect(await oliveManager.connect(u1).getClaimable(u1.address)).to.equal(0); // there are no rewards in the system
    });
  });

  describe("Vesting checks", function () {
    it("stake 100esOlive, Unvest and wait till 60days", async function () {
      const { u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(100), 60);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(61 * 24 * 3600);
      // 19290123456790 * 60 * 24 * 3600/ 1e18 =~ 100
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '19290123456790123456790123456790'
      );
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        100
      );
    });

    it("stake 100esOlive, Unvest and wait till 30days", async function () {
      const { u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(100), 60);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '19290123456790123456790123456790'
      );
      await time.increase(30 * 24 * 3600 + 5);
      await oliveManager.connect(u1).withdraw();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        50
      );
    });

    it("stake 100esOlive, Unvest and wait till 45days", async function () {
      const { u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(100), 45);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(45 * 24 * 3600);
      // 21862139917695 * 45 * 24 * 3600/ 1e18 =~ 85
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '21862139917695473251028806584362'
      );
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        85
      );
    });

    it("stake 100esOlive, Unvest and wait till 10days", async function () {
      const { u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(100), 10);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(45 * 24 * 3600);
      // 57870370370370 * 10 * 24 * 3600/ 1e18 =~ 50
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '57870370370370370370370370370370'
      );
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        50
      );
    });

    // Changing the exit days from 10 - 60 > 5 - 30
    it("stake 100esOlive, Unvest and wait till 30days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(owner).setMinVestingPeriod(5 * 24 * 3600);
      await oliveManager.connect(owner).setMaxVestingPeriod(30 * 24 * 3600);
      await oliveManager.connect(u1).unstake(toN(100), 30);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(30 * 24 * 3600);
      // 38580246913580 * 30 * 24 * 3600/ 1e18 =~ 100
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '38580246913580246913580246913580'
      );
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        100
      );
    });

    it("stake 100esOlive, Unvest and wait till 5days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(owner).setMinVestingPeriod(5 * 24 * 3600);
      await oliveManager.connect(owner).setMaxVestingPeriod(30 * 24 * 3600);
      await oliveManager.connect(u1).unstake(toN(100), 5);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(30 * 24 * 3600);
      // 115740740740740 * 5 * 24 * 3600/ 1e18 =~ 50
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '115740740740740740740740740740740'
      );
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        50
      );
    });

    it("stake 100esOlive, Unvest and wait till 10days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(owner).setMinVestingPeriod(5 * 24 * 3600);
      await oliveManager.connect(owner).setMaxVestingPeriod(30 * 24 * 3600);
      await oliveManager.connect(u1).unstake(toN(100), 10);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(30 * 24 * 3600);
      // 69444444444444 * 10 * 24 * 3600/ 1e18 =~ 60
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '69444444444444444444444444444444'
      );
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        60
      );
    });

    it("stake 100esOlive, Unvest and wait till 20days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(owner).setMinVestingPeriod(5 * 24 * 3600);
      await oliveManager.connect(owner).setMaxVestingPeriod(30 * 24 * 3600);
      await oliveManager.connect(u1).unstake(toN(100), 20);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(30 * 24 * 3600);
      // 46296296296296 * 20 * 24 * 3600/ 1e18 =~ 80
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '46296296296296296296296296296296'
      );
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        80
      );
    });

    // Changing the exit days from 10 - 60 > 15 - 90
    it("stake 100esOlive, Unvest and wait till 90days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(owner).setMinVestingPeriod(15 * 24 * 3600);
      await oliveManager.connect(owner).setMaxVestingPeriod(90 * 24 * 3600);
      await oliveManager.connect(u1).unstake(toN(100), 90);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(90 * 24 * 3600);
      // 12731481481481 * 90 * 24 * 3600/ 1e18 =~ 99
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '12731481481481481481481481481481'
      );
      await oliveManager.connect(u1).withdraw();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        99
      ); // precision loss
    });

    it("stake 100esOlive, Unvest and wait till 15days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(owner).setMinVestingPeriod(15 * 24 * 3600);
      await oliveManager.connect(owner).setMaxVestingPeriod(90 * 24 * 3600);
      await oliveManager.connect(u1).unstake(toN(100), 15);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(90 * 24 * 3600);
      // 38580246913580 * 15 * 24 * 3600/ 1e18 =~ 50
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '38580246913580246913580246913580'
      );
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        50
      );
    });

    it("stake 100esOlive, Unvest and wait till 45days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(owner).setMinVestingPeriod(15 * 24 * 3600);
      await oliveManager.connect(owner).setMaxVestingPeriod(90 * 24 * 3600);
      await oliveManager.connect(u1).unstake(toN(100), 45);
      expect(await esOlive.balanceOf(u1.address)).to.equal(0);
      await time.increase(90 * 24 * 3600);
      // 17746913580246 * 45 * 24 * 3600/ 1e18 =~ 69
      expect((await oliveManager.unstakeRate(u1.address)).toString()).to.equal(
        '17746913580246913580246913580246'
      );
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        69
      ); //precision loss
    });
  });

  describe("Unstake - Unstake checks", function () {
    it("30days Vesting, immediate unstake more but increase vesting to 60 days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(10), 30);
      await oliveManager.connect(u1).unstake(toN(90), 60);
      await time.increase(60 * 24 * 3600);
      await oliveManager.connect(u1).withdraw();

      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        100
      );
    });

    it("30days Vesting after 15 day unstake more but increase vesting to 60 days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(50), 30);
      await time.increase(15 * 24 * 3600);
      await oliveManager.connect(u1).unstake(toN(50), 60);
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        18
      ); // ~17.5
      await time.increase(75 * 24 * 3600);
      await oliveManager.connect(u1).withdraw();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        92
      ); // ~75 + 17.5
    });

    it("30days Vesting after 15 day unstake more but increase vesting to 60 days", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(50), 30);
      await time.increase(30 * 24 * 3600);
      await oliveManager.connect(u1).unstake(toN(50), 60);
      await time.increase(90 * 24 * 3600);
      await oliveManager.connect(u1).withdraw();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        85
      );
    });
  });

  describe("Unstake - reStake checks", function () {
    it("Unstake restake at 28days- no-loss", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(100), 30);
      await time.increase(28 * 24 * 3600);
      await oliveManager.connect(u1).reStake();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        100
      );
      await oliveManager.connect(u1).unstake(await esOlive.balanceOf(u1.address), 60); // due to loss caused by precision
      await time.increase(60 * 24 * 3600);
      await oliveManager.connect(u1).withdraw();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        100
      );
    });

    it("Unstake restake 1day- no-loss", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(100), 30);
      await time.increase(1 * 24 * 3600);
      await oliveManager.connect(u1).reStake();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        100
      );
      await oliveManager.connect(u1).unstake(await esOlive.balanceOf(u1.address), 60);
      await time.increase(60 * 24 * 3600);
      await oliveManager.connect(u1).withdraw();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        100
      );
    });

    it("Unstake restake 60day- no-loss", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(100), 30);
      await time.increase(60 * 24 * 3600);
      await oliveManager.connect(u1).reStake();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        100
      );
      await oliveManager.connect(u1).unstake(await esOlive.balanceOf(u1.address), 60);
      await time.increase(60 * 24 * 3600);
      await oliveManager.connect(u1).withdraw();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        100
      );
    });

    it("Unstake restake 30 days - withdraw,  nothing to restake", async function () {
      const { owner, u1, oliveManager, esOlive, olive } = await loadFixture(
        deployOliveManager
      );
      await oliveManager.connect(u1).unstake(toN(100), 30);
      await time.increase(60 * 24 * 3600);
      await oliveManager.connect(u1).withdraw();
      await oliveManager.connect(u1).reStake();
      expect(Math.round((await esOlive.balanceOf(u1.address)) / 1e18)).to.equal(
        0
      );
      expect(Math.round((await olive.balanceOf(u1.address)) / 1e18)).to.equal(
        70
      );
    });
  });

  describe("Rewards check", function () {
    it("Rewards sanity check - Users already minted 100 esOlive each", async function () {
      const { owner, u1, u2, oliveManager, esOlive, wETH} =
      await loadFixture(deployOliveManager);
      await esOlive.mint(u2.address, toN(100));
      await wETH.connect(owner).transfer(oliveManager.address, toN(100));
      await oliveManager.grantRole(u1.address);
      await oliveManager.connect(u1).notifyRewardAmount(toN(100));
      // End of test case preparation

      expect(await oliveManager.earned(u1.address)).to.equal(toN(50)); // Should be 50 wETH
      await oliveManager.connect(u1).getReward();
      expect(await wETH.balanceOf(u1.address)).to.equal(toN(50));

      expect(await oliveManager.earned(u2.address)).to.equal(toN(50)); // Should be 50 wETH
      await oliveManager.connect(u2).getReward();
      expect(await wETH.balanceOf(u2.address)).to.equal(toN(50));
    });

    it("Rewards sanity check - No esOlive at all - unclaimed rewards to treasury", async function () {
      const { owner, u1, u2, oliveManager, esOlive, olive, wETH, treasury } = await loadFixture(deployOliveManager);

      // Unstake all the esOlive
      await esOlive.mint(u2.address, toN(100));
      await oliveManager.connect(u1).unstake(toN(100), 10);
      await oliveManager.connect(u2).unstake(toN(100), 10);
      await wETH.connect(owner).transfer(oliveManager.address, toN(100));
      await oliveManager.grantRole(u1.address);
      await oliveManager.connect(u1).notifyRewardAmount(toN(100));
      // End of test case preparation

      expect(await oliveManager.earned(u1.address)).to.equal(toN(0)); 
      expect(await oliveManager.earned(u1.address)).to.equal(toN(0)); 

      await oliveManager.connect(owner).withdrawToTreasury();
      expect(await wETH.balanceOf(treasury.address)).to.equal(toN(100));
    });

    it("Rewards sanity check - Cycle of rewards", async function () {
      const { owner, u1, u2, oliveManager, esOlive, olive, wETH } = await loadFixture(deployOliveManager);
      await oliveManager.grantRole(u1.address);

      // Start of test cases preparation - Set the rewards
      await esOlive.mint(u2.address, toN(100));
      await wETH.connect(owner).transfer(oliveManager.address, toN(100));
      await oliveManager.connect(u1).notifyRewardAmount(toN(100));
      // End of test cases preparation 

      await esOlive.connect(owner).mint(u1.address, toN(100)); // This minting would not have affected on the rewards

      expect(await oliveManager.earned(u1.address)).to.equal(toN(50)); // Should be 50 wETH
      expect(await oliveManager.earned(u1.address)).to.equal(toN(50)); // Should be 50 wETH
      
      
      // Start of test cases preparation - Set the rewards
      await wETH.mint(owner.address, toN(100));
      await wETH.connect(owner).transfer(oliveManager.address, toN(100));
      await oliveManager.connect(u1).notifyRewardAmount(toN(100));
      // End of test cases preparation
      
      // u1 balance - 200, u2 balance is 100
      // old + new rewards
      expect(Math.round((await oliveManager.earned(u1.address)) / 1e18)).to.equal(117 ); // Should be 50 wETH + 66.66 wETH
      expect(Math.round((await oliveManager.earned(u2.address)) / 1e18)).to.equal(83); // Should be 50 wETH + 33.33 wETH
      
      await oliveManager.connect(u1).getReward();
      expect(Math.round((await wETH.balanceOf(u1.address)) / 1e18)).to.equal(117);


      await time.increase(60 * 24 * 3600); // In these rewards time has no play

      // U1 withdrew the rewards - U2 did not
      // Start of test cases preparation - Set the rewards
      await wETH.mint(owner.address, toN(300));
      await wETH.connect(owner).transfer(oliveManager.address, toN(300));
      await oliveManager.connect(u1).notifyRewardAmount(toN(300));
      // End of test cases preparation

      // u1 balance - 200, u2 balance is 100
      // old + new rewards
      expect(Math.round((await oliveManager.earned(u1.address)) / 1e18)).to.equal(200); // Should be 200 wETH from latest rewards
      expect(Math.round((await oliveManager.earned(u2.address)) / 1e18)).to.equal(183); // Should be 50 wETH + 33.33 MUSD + 100 wETH

      await time.increase(365 * 24 * 3600); // In these rewards time has no play

      expect(Math.round((await oliveManager.earned(u1.address)) / 1e18)).to.equal(200); // Should be 200 wETH from latest rewards
      expect(Math.round((await oliveManager.earned(u2.address)) / 1e18)).to.equal(183); // Should be 50 wETH + 33.33 wETH + 100 wETH

      await time.increase(30 * 24 * 3600); // In these rewards time has no play

      // All users withdraw the amounts
      await oliveManager.connect(u1).getReward();
      await oliveManager.connect(u2).getReward();

      expect(Math.round((await oliveManager.earned(u1.address)) / 1e18)).to.equal(0); // Should be 200mUSD from latest rewards
      expect(Math.round((await oliveManager.earned(u2.address)) / 1e18)).to.equal(0); // Should be 50 wETH + 33.33 MUSD + 100 mUSD

      expect(Math.round((await wETH.balanceOf(u1.address)) / 1e18)).to.equal(
        317
      );
      expect(Math.round((await wETH.balanceOf(u2.address)) / 1e18)).to.equal(
        183
      );

      // All users withdraw the amounts
      await oliveManager.connect(u1).getReward();
      await oliveManager.connect(u2).getReward();

      expect(Math.round((await wETH.balanceOf(u1.address)) / 1e18)).to.equal(
        317
      );
      expect(Math.round((await wETH.balanceOf(u2.address)) / 1e18)).to.equal(
        183
      );
    });
  });

  describe("Sanity checks", function () {
    it("Owner/Previlage checks", async function () {
      const { owner, u1, u2, oliveManager, esOlive, wETH} = await loadFixture(deployOliveManager);
      await expect(oliveManager.connect(u1).withdrawToTreasury()).to.be.reverted;
      await expect(oliveManager.connect(u1).notifyRewardAmount(toN(100))).to.be
        .reverted;
    });

    it("Owner can checkts", async function () {
      const { owner, u1, u2, oliveManager, esOlive, wETH} = await loadFixture(deployOliveManager);
      await oliveManager.connect(owner).setOwner(u1.address); // Giving u1 the permissions
      await oliveManager.connect(u1).grantRole(u1.address);

      // Unstake all the esOlive
      await oliveManager.connect(u1).unstake(toN(100), 10);
      await esOlive.mint(u2.address, toN(100));
      await oliveManager.connect(u2).unstake(toN(100), 10);


      await wETH.connect(owner).transfer(oliveManager.address, toN(10));
      await oliveManager.connect(u1).notifyRewardAmount(toN(10));
      // End of test cases preparation - oliveManager has 10 wETH rewards

      await expect(oliveManager.connect(u1).withdrawToTreasury()).not.to.be.reverted;
      await wETH.connect(owner).transfer(oliveManager.address, toN(10));
      await expect(oliveManager.connect(u1).notifyRewardAmount(toN(10))).not.to.be.reverted;

      await expect(oliveManager.connect(u1).withdrawToTreasury()).not.to.be.reverted;
      await expect(oliveManager.connect(u1).withdrawToTreasury()).to.be.reverted;
  
      await oliveManager.connect(u1).setOwner(u2.address);
      await oliveManager.connect(u1).reStake();
      await expect(oliveManager.connect(u1).notifyRewardAmount(toN(0))).to.be.reverted;
      // No uncliamed rewards test

      await expect(oliveManager.connect(u1).withdrawToTreasury()).to.be.reverted;
    });

    it("Invalid input checks", async function () {
      const { owner, u1, u2, oliveManager, esOlive } = await loadFixture(deployOliveManager);
      await expect(oliveManager.connect(u1).unstake(toN(100), 5)).to.be.reverted; // min is 10 max is 60 days
      await expect(oliveManager.connect(u1).unstake(toN(100), 75)).to.be.reverted; // min is 10 max is 60 days
    });
  });
});
