const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTMarketplace", function () {
  //Тук ще сетнем предварително един firstUser глобално за да го ползваме на долу в тестовете
  let marketplaceFirstUser, deployer, firstUser, secondUser;

  this.beforeAll(async function () {
    //Взимаме първите два(вече три със secondUser) адреса от дефолтните на хардхет
    //signer-a е цял обект, та ако ни трябва само адреса secondUser.address !
    [deployer, firstUser, secondUser] = await ethers.getSigners();
    const { marketplace } = await loadFixture(deployAndMint);
    marketplaceFirstUser = getFirstUserMarketplace(marketplace, firstUser);
  });
  //До тук

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployAndMint() {
    // Contracts are deployed using the first signer/account by default

    //Правим факторито  NFTMarketplace идва от артефактите на този контракт (source name) като компилираме
    //и signer който е deployer
    const MarketplaceFactory = await ethers.getContractFactory(
      "NFTMarketplace",
      deployer
    );
    //Диплойваме контракта
    const marketplace = await MarketplaceFactory.deploy();

    //Свързваме нашия адрес firstUser да интерактва с контракта
    const _marketplaceFirstUser = marketplace.connect(firstUser);

    //И минтваме с него НФТ с някакъв тест URI(fake)
    await _marketplaceFirstUser.createNFT("testURI");

    return { marketplace, deployer, firstUser };
  }

  async function list() {
    const { marketplace } = await loadFixture(deployAndMint);
    const price = ethers.utils.parseEther("1");
    await marketplaceFirstUser.approve(marketplace.address, 0);
    await marketplaceFirstUser.listNFTForSale(marketplace.address, 0, price);

    return marketplace;
  }

  describe("Listing", function () {
    it("It reverts when price == 0", async function () {
      const { marketplace, deployer } = await loadFixture(deployAndMint);

      await expect(
        marketplace.listNFTForSale(marketplace.address, 0, 0)
      ).to.be.revertedWith("Price must be > 0");
    });

    it("reverts when already listed", async function () {
      const { marketplace, deployer } = await loadFixture(deployAndMint);

      const price = ethers.utils.parseEther("1");
      await marketplaceFirstUser.approve(marketplace.address, 0);
      await marketplaceFirstUser.listNFTForSale(marketplace.address, 0, price);

      await expect(
        marketplaceFirstUser.listNFTForSale(marketplace.address, 0, price)
      ).to.be.revertedWith("NFT is already listed for sale");
    });

    it("should succeed", async function () {
      const { marketplace } = await loadFixture(deployAndMint);

      const price = ethers.utils.parseEther("1");
      await marketplaceFirstUser.approve(marketplace.address, 0);

      await expect(
        marketplaceFirstUser.listNFTForSale(marketplace.address, 0, price)
      )
        .to.emit(marketplaceFirstUser, "NFTListed")
        .withArgs(marketplace.address, 0, price);
    });
  });

  describe("Purchase", function () {
    it("It reverts when not listed", async function () {
      const { marketplace } = await loadFixture(deployAndMint);

      await expect(
        marketplace.purchaseNFT(marketplace.address, 0, secondUser.address)
      ).to.be.revertedWith("NFT NOT FOR SALE");
    });

    it("It reverts when price is incorrect", async function () {
      const marketplace = await loadFixture(list);
      const wrongPrice = ethers.utils.parseEther("0.1");

      await expect(
        marketplace.purchaseNFT(marketplace.address, 0, secondUser.address, {
          value: wrongPrice,
        })
      ).to.be.revertedWith("Incorrect price");
    });

    it("succeed", async function () {
      const marketplace = await loadFixture(list);
      const price = ethers.utils.parseEther("1");

      await marketplace.purchaseNFT(marketplace.address, 0, secondUser.address, {
          value: price,
        });

        expect((await marketplace.nftSales(marketplace.address,0)).price).to.equal(0);
        expect(await marketplace.ownerOf(0)).to.equal(secondUser.address);
    });

  });
});

function getFirstUserMarketplace(marketplace, firstUser) {
  //Свързваме нашия адрес firstUser да интерактва с контракта
  return marketplace.connect(firstUser);
}
