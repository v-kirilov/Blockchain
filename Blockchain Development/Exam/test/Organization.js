const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");


describe("Organization", function () {
  let deployer, firstUser;
  this.beforeAll(async function () {
    [deployer, firstUser, secondUser] = await ethers.getSigners();
  });
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployAndCreateTreasury() {
    // Contracts are deployed using the first signer/account by default
    const TreasuryFactory = await ethers.getContractFactory(
      "Organization",
      deployer
    );
    const treasury = await TreasuryFactory.deploy();
    const _firstUser = treasury.connect(deployer);
    await _firstUser.createTreasury();
    return { treasury, deployer };
  }

  //Unit tests must be implemented for 100% of the Initiate Withdrawal and Voting functionalities logic.

  describe("initiateWithdrawal testing", function () {
    it("Should revert when amount too big", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);
      const originalUser = treasury.connect(deployer);
      const _secondUser = treasury.connect(secondUser);
      await _secondUser.storeFunds(0, { value: 1000 });

      await expect(
        originalUser.initiateWithdrawal(0, 2000, "Descr", 1686558011)
      ).to.be.revertedWith("Not enough balance");
    });

    it("Should revert when not owner", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);
      const originalUser = treasury.connect(deployer);
      const _secondUser = treasury.connect(secondUser);
      await _secondUser.storeFunds(0, { value: 1000 });

      await expect(
        _secondUser.initiateWithdrawal(0, 1000, "Descr", 1686558011)
      ).to.be.revertedWith("Not owner");
    });

    it("Should revert when no such treasury", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);
      const originalUser = treasury.connect(deployer);
      const _secondUser = treasury.connect(secondUser);
      await _secondUser.storeFunds(0, { value: 1000 });

      await expect(
        _secondUser.initiateWithdrawal(3, 1000, "Descr", 1686558011)
      ).to.be.revertedWith("No such treasury");
    });

    it("Should create a new withdrawal", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);
      const originalUser = treasury.connect(deployer);
      const _secondUser = treasury.connect(secondUser);
      await _secondUser.storeFunds(0, { value: 1000 });
      await originalUser.initiateWithdrawal(0, 1000, "Descr", 1686558011);
      const expectedValue = await _secondUser.Withdrawals(0).amount;
      await expect(_secondUser.Withdrawals(0).amount).to.equal(expectedValue);
    });
  });

  describe("Should StoreFunds", function () {
    it("Should store funds succesfully", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);

      const _secondUser = treasury.connect(secondUser);
      await _secondUser.storeFunds(0, { value: 1000 });
      const expectedValue = await _secondUser.blanaceOfTreasury[0];

      await expect(_secondUser.treasuries(0).balance).to.equal(expectedValue);
    });
  });

  describe("Vote testing", function () {
    it("Should revert when no such withdrawal exists", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);
      const originalUser = treasury.connect(deployer);
      const _secondUser = treasury.connect(secondUser);

      await expect(_secondUser.vote(5, true, 500)).to.revertedWith(
        "No such withdrawal"
      );
    });

    it("Should revert when amount is 0", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);
      const originalUser = treasury.connect(deployer);
      const _secondUser = treasury.connect(secondUser);
      await _secondUser.storeFunds(0, { value: 1000 });
      await originalUser.initiateWithdrawal(0, 1000, "Descr", 1686558011);

      await expect(_secondUser.vote(0, true, 0)).to.revertedWith(
        "Amount must be >0"
      );
    });

    it("Should revert when not nough votes", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);
      const originalUser = treasury.connect(deployer);
      const _secondUser = treasury.connect(secondUser);
      await _secondUser.storeFunds(0, { value: 1000 });
      await originalUser.initiateWithdrawal(0, 1000, "Descr", 1686558011);

      await expect(_secondUser.vote(0, true, 2000)).to.revertedWith(
        "Not enough votes"
      );
    });

    it("Should vote with no", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);
      const originalUser = treasury.connect(deployer);
      const _secondUser = treasury.connect(secondUser);
      await _secondUser.storeFunds(0, { value: 1000 });
      await originalUser.initiateWithdrawal(0, 1000, "Descr", 1686558011);
      await _secondUser.vote(0, true, 500);
      let [, , , , yes, no] = await originalUser.Withdrawals(0);
      await expect(yes).to.equal(500);
    });

    it("Should vote wthi yes", async function () {
      const { treasury, deployer } = await loadFixture(deployAndCreateTreasury);
      const originalUser = treasury.connect(deployer);
      const _secondUser = treasury.connect(secondUser);
      await _secondUser.storeFunds(0, { value: 1000 });
      await originalUser.initiateWithdrawal(0, 1000, "Descr", 1686558011);
      await _secondUser.vote(0, false, 500);
      let [, , , , yes, no] = await originalUser.Withdrawals(0);
      await expect(no).to.equal(500);
    });



  });



});
