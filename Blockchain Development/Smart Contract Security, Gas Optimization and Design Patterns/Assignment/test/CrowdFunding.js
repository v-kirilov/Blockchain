const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");

describe("CrowdFunding", function () {

  
  let deployer, firstUser, secondUser;

  this.beforeAll(async function () {
    [deployer, firstUser, secondUser] = await ethers.getSigners();

  })
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployAndContribute() {
    const goal = ethers.utils.parseEther("20");

    const CrowdFundingFactory = await ethers.getContractFactory("CrowdFunding", deployer);

    const crowdFunding = await CrowdFundingFactory.deploy(
      
      0,
      "MyNewCF",
      "For charity work",
      goal,
      3600);

    const cfFirstUser = crowdFunding.connect(firstUser);

    const firstContribution = ethers.utils.parseEther("1");
    await cfFirstUser.contribute({ value: firstContribution });

    return { crowdFunding, cfFirstUser, deployer };
  }

  describe("Deployment", function () {

    it("Reward Distribution should revert", async function () {
      const { crowdFunding, cfFirstUser, deployer } = await loadFixture(deployAndContribute);
      const secondContribution = ethers.utils.parseEther("4");
      const amountToDistribute = ethers.utils.parseEther("10");

      const sfSecondUser = crowdFunding.connect(secondUser);
      await sfSecondUser.contribute({value:secondContribution});

      await expect(
        crowdFunding.rewardDistribution(amountToDistribute)).to.be.revertedWith("Must be < than balance");
    });

    it("Refund should revert", async function () {
      const { crowdFunding, cfFirstUser, deployer } = await loadFixture(deployAndContribute);

      await expect(
        crowdFunding.refund()).to.be.revertedWith("Not over yet");
    });

    it("Refund revert with Nothing to refund", async function () {
      const { crowdFunding, cfFirstUser, deployer } = await loadFixture(deployAndContribute);
      const secondContribution = ethers.utils.parseEther("1");
      
      const sfSecondUser = crowdFunding.connect(secondUser);
      await sfSecondUser.contribute({value:secondContribution});
      
      await helpers.time.increase(3600);

      await expect(
        crowdFunding.refund()).to.be.revertedWith("Nothing to refund");
    });

    it("Refund revert with Funding finished", async function () {
      const { crowdFunding, cfFirstUser, deployer } = await loadFixture(deployAndContribute);
      const secondContribution = ethers.utils.parseEther("19");
      
      const sfSecondUser = crowdFunding.connect(secondUser);
      await sfSecondUser.contribute({value:secondContribution});
      
      await helpers.time.increase(3600);

      await expect(
        sfSecondUser.refund()).to.be.revertedWith("Funding finished");
    });

    it("Refund succeeds", async function () {
      const { crowdFunding, cfFirstUser, deployer } = await loadFixture(deployAndContribute);
      const totalBalance = ethers.utils.parseEther("1");

      const balance = await crowdFunding.balanceOf(crowdFunding.address);
            
      await helpers.time.increase(3600);
      await  cfFirstUser.refund();
      const contractBalance = await ethers.provider.getBalance(crowdFunding.address);

      await expect(
        await contractBalance).to.equal(totalBalance);
    });

    it("Transfer shares should revert", async function () {
      const { crowdFunding, cfFirstUser, deployer } = await loadFixture(deployAndContribute);

      await expect(
        crowdFunding.transferShares(cfFirstUser.address,1)).to.be.revertedWith("Not enough shares");
    });

  });

});
