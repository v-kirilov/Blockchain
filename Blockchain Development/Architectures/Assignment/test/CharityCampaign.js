//npm install @openzeppelin/contracts
const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");

describe("CharityCampaign", function () {
    let deployer, firstUser;
    this.beforeAll(async function () {
        [deployer, firstUser,secondUser] = await ethers.getSigners();
        // const { charityCamp } = await loadFixture(deploy);

        // const _firstUser = charityCamp.connect(firstUser);
    })
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deploy() {
        const goal = ethers.utils.parseEther("20");

        const CharityCampaignFactory = await ethers.getContractFactory("CharityCampaign", deployer);

        const charityCamp = await CharityCampaignFactory.deploy();

        return { charityCamp, deployer };
    }
    //Unit tests for 100% of the Donation and Successful Campaign Funds Release functionalities logic must be implemented

    describe("Create Camapaign", function () {
        it("Create campaign successfully", async function () {
            const { charityCamp, deployer } = await loadFixture(deploy);
            const _firstUser = charityCamp.connect(firstUser);

            const goal = ethers.utils.parseEther("20");

            await expect(
                _firstUser.createCampaign("First", "My first campaign", goal, 3600))
                .to.emit(_firstUser, "CampaignCreated").withArgs(firstUser.address);
        });
    });

    describe("Donation", function () {
        it("should revert", async function () {
            const { charityCamp, deployer } = await loadFixture(deploy);
            const _firstUser = charityCamp.connect(firstUser);

            const goal = ethers.utils.parseEther("20");
            const bigDonation = ethers.utils.parseEther("30");

            await _firstUser.createCampaign("First", "My first campaign", goal, 3600)

            await expect(
                _firstUser.donate(0, { value: bigDonation }))
                .to.be.revertedWith("Donation is over goal");
        });

        it("camapaign should finish", async function () {
            const { charityCamp, deployer } = await loadFixture(deploy);
            const _firstUser = charityCamp.connect(firstUser);

            const goal = ethers.utils.parseEther("20");
            const bigDonation = ethers.utils.parseEther("20");

            await _firstUser.createCampaign("First", "My first campaign", goal, 3600)
            await _firstUser.donate(0, { value: goal });
            const myCamp = await _firstUser.campaigns(0);
            
            await expect(
                myCamp.isFinished)
                .to.equal(true);
        });

        it("contributors balance should increase", async function () {
            const { charityCamp, deployer } = await loadFixture(deploy);
            const _firstUser = charityCamp.connect(firstUser);

            const goal = ethers.utils.parseEther("20");
            const bigDonation = ethers.utils.parseEther("5");

            await _firstUser.createCampaign("First", "My first campaign", goal, 3600)
            await _firstUser.donate(0, { value: bigDonation });

            const contribution = await _firstUser.contrirbutors(firstUser.address,0);
            await expect(
                contribution)
                .to.equal(bigDonation);
        });
    });

    describe("Collect funds", function () {
        it("shoud revert when not creator", async function () {
            const { charityCamp, deployer } = await loadFixture(deploy);
            const _firstUser = charityCamp.connect(firstUser);
            const _secondUser = charityCamp.connect(secondUser);

            const goal = ethers.utils.parseEther("20");
            const bigDonation = ethers.utils.parseEther("20");

            await _firstUser.createCampaign("First", "My first campaign", goal, 3600)
            await _firstUser.donate(0, { value: bigDonation });

            await expect(
                _secondUser.collectFunds(0, _secondUser.address))
                .to.be.revertedWith("Not creator");
        });

        it("shoud revert unable to send value", async function () {
            const { charityCamp, deployer } = await loadFixture(deploy);
            const _firstUser = charityCamp.connect(firstUser);
            const _secondUser = charityCamp.connect(secondUser);

            const goal = ethers.utils.parseEther("20");
            const bigDonation = ethers.utils.parseEther("20");

            await _firstUser.createCampaign("First", "My first campaign", goal, 3600)
            await _firstUser.donate(0, { value: bigDonation });

            await expect(
                _firstUser.collectFunds(0, _secondUser.address))
                .to.be.revertedWith("Address: unable to send value, recipient may have reverted");
        });

        
        it("shoud revert when not finished", async function () {
            const { charityCamp, deployer } = await loadFixture(deploy);
            const _firstUser = charityCamp.connect(firstUser);
            const _secondUser = charityCamp.connect(secondUser);

            const goal = ethers.utils.parseEther("20");
            const bigDonation = ethers.utils.parseEther("10");

            await _firstUser.createCampaign("First", "My first campaign", goal, 3600)

            await expect(
                _firstUser.collectFunds(0, _firstUser.address))
                .to.be.revertedWith("Not finished");
        });
    });

});
