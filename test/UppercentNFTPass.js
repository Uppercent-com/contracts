// tests/UppercentNFTPass.js
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
// "upgrades" module is used for dealing with upgradeable contracts

describe("UppercentNFTPass", function () {
  let UppercentNFTPass;
  let uppercentNFTPass;
  let owner;
  let buyer;
  let impersonatedSigner;
  const impersonatedAddress = "0x3190c12068E470691ecac2B68B26310B378E7199"; // The holder of the old NFT

  beforeEach(async function () {
    [owner, buyer] = await ethers.getSigners();

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [impersonatedAddress],
    });

    impersonatedSigner = await ethers.getSigner(impersonatedAddress);

    await owner.sendTransaction({
      to: impersonatedAddress,
      value: ethers.parseEther("10.0"), // Send 50 FLR to the impersonated account
    });

    UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
    uppercentNFTPass = await upgrades.deployProxy(
      UppercentNFTPass,
      [owner.address, 10, "testURI", 100, 2, 10, 20],
      { initializer: "initialize" }
    );
    //await uppercentNFTPass.deployed();
  });

  describe("Initialization: ", function () {
    it("Should set the right owner", async function () {
      expect(await uppercentNFTPass.owner()).to.equal(owner.address);
    });
    it("Should set the right admin share", async function () {
      expect(await uppercentNFTPass.getAdminShare()).to.equal(10);
    });
    it("Should set the right URI", async function () {
      expect(await uppercentNFTPass.uri(0)).to.equal("testURI");
    });
    it("Should set the right maximum supply", async function () {
      expect(await uppercentNFTPass.getMaxSupply()).to.equal(100);
    });
    it("Should set the right mint price", async function () {
      const mintPrice = await uppercentNFTPass.getMintPrice();
      expect(mintPrice).to.equal(2);
    });
  });

  describe("Standard Minting: ", function () {
    it("Should mint NFTs and update user's balance", async function () {
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      await uppercentNFTPass.mint(1, { value: requiredAmount });
      expect(await uppercentNFTPass.balanceOf(owner.address, 1)).to.equal(1);
    });

    it("Should not allow minting more than the maximum supply", async function () {
      UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
      uppercentNFTPass = await upgrades.deployProxy(
        UppercentNFTPass,
        [owner.address, 10, "testURI", 1, 1, 10, 0],
        { initializer: "initialize" }
      );
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      await uppercentNFTPass.mint(1, { value: requiredAmount });
      await expect(
        uppercentNFTPass.mint(1, { value: requiredAmount })
      ).to.be.revertedWith("Error: Exceeds maximum supply");
    });

    it("Should not allow minting more than the user's mint limit", async function () {
      UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
      uppercentNFTPass = await upgrades.deployProxy(
        UppercentNFTPass,
        [owner.address, 10, "testURI", 100, 1, 2, 20],
        { initializer: "initialize" }
      );
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(3);
      await expect(
        uppercentNFTPass.mint(3, { value: requiredAmount })
      ).to.be.revertedWith("Error: Exceeds per-user limit");
    });

    it("Should not allow minting with insufficient amount sent", async function () {
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      await expect(
        uppercentNFTPass.mint(1, { value: requiredAmount - 1n })
      ).to.be.revertedWith("Error: Insufficient amount sent");
    });

    it("Should pause minting", async function () {
      await uppercentNFTPass.pause();
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      await expect(
        uppercentNFTPass.connect(buyer).mint(1, { value: requiredAmount })
      ).to.be.revertedWithCustomError(uppercentNFTPass, "EnforcedPause");
    });

    it("Should unpause minting", async function () {
      await uppercentNFTPass.pause();
      await uppercentNFTPass.unpause();
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      await uppercentNFTPass.mint(1, { value: requiredAmount });
      expect(await uppercentNFTPass.balanceOf(owner.address, 1)).to.equal(1);
    });
  });

  describe("Creating Presale: ", function () {
    it("Should create a presale window and check if pre-sale is active", async function () {
      const now = await time.latest();
      const presaleStartDate = now + 100;
      const presaleEndDate = now + 3600;

      const createPresaleTx = await uppercentNFTPass.createPresale(
        1,
        presaleStartDate,
        presaleEndDate
      );
      await createPresaleTx.wait();
      await time.increase(1000);

      expect(await uppercentNFTPass.isPresaleActive()).to.equal(true);
    });

    it("Should set right presale price", async function () {
      const now = await time.latest();
      const presaleStartDate = now + 100;
      const presaleEndDate = now + 3600;

      const createPresaleTx = await uppercentNFTPass.createPresale(
        1,
        presaleStartDate,
        presaleEndDate
      );
      await createPresaleTx.wait();
      await time.increase(1000);

      expect(await uppercentNFTPass.getMintPrice()).to.equal(1);
    });

    it("Should set right presale start and end dates", async function () {
      const now = await time.latest();
      const presaleStartDate = now + 100;
      const presaleEndDate = now + 3600;

      const createPresaleTx = await uppercentNFTPass.createPresale(
        1,
        presaleStartDate,
        presaleEndDate
      );
      await createPresaleTx.wait();
      await time.increase(1000);

      expect(await uppercentNFTPass.getPresaleStartDate()).to.equal(
        presaleStartDate
      );
      expect(await uppercentNFTPass.getPresaleEndDate()).to.equal(
        presaleEndDate
      );
    });

    it("Should not allow creating a presale with invalid dates", async function () {
      const now = await time.latest();
      const presaleStartDate = now + 100;
      const presaleEndDate = now - 3600; // Invalid date (end before start)

      await expect(
        uppercentNFTPass.createPresale(1, presaleStartDate, presaleEndDate)
      ).to.be.revertedWith("Error: Invalid presale dates");
    });
  });

  describe("Presale Minting: ", function () {
    it("Should mint NFTs during pre-sale with pre-sale price", async function () {
      const now = await time.latest();
      const presaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;

      // Create a pre-sale
      await uppercentNFTPass.createPresale(
        1,
        presaleStartDate,
        preSaleEndDate
      );
      await time.increase(1000);
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      await uppercentNFTPass.mint(1, { value: requiredAmount });

      expect(await uppercentNFTPass.balanceOf(owner.address, 1)).to.equal(1);
      expect(await uppercentNFTPass.isPresaleActive()).to.be.true;
      expect(await uppercentNFTPass.getMintPrice()).to.equal(1); // Pre-sale price
    });

    it("Should not allow minting more than the unreserved amount during pre-sale", async function () {
      const now = await time.latest();
      const presaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;

      uppercentNFTPass = await upgrades.deployProxy(
        UppercentNFTPass,
        [owner.address, 10, "testURI", 100, 1, 100, 20],
        { initializer: "initialize" }
      );

      // Create a pre-sale
      await uppercentNFTPass.createPresale(
        1,
        presaleStartDate,
        preSaleEndDate
      );
      await time.increase(1000);
      let requiredAmount = await uppercentNFTPass.requiredMintAmount(80);
      await uppercentNFTPass.mint(80, { value: requiredAmount });
      requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      await expect(
        uppercentNFTPass.mint(1, { value: requiredAmount })
      ).to.be.revertedWith("Error: Exceeds available supply for Group 2 during presale");
    });

    it("Should allow Group 1 (previous buyer) to mint during presale from reserved supply", async function () {
      const now = await time.latest();
      const presaleStartDate = now + 100;
      const presaleEndDate = now + 3600;

      await uppercentNFTPass.createPresale(1, presaleStartDate, presaleEndDate);
      await time.increase(1000);

      // Impersonate and mint as the old NFT holder (Group 1)
      const requiredAmount = await uppercentNFTPass.connect(impersonatedSigner).requiredMintAmount(1);
      await uppercentNFTPass.connect(impersonatedSigner).mint(1, { value: requiredAmount });

      // Verify the minting happened successfully
      expect(await uppercentNFTPass.balanceOf(impersonatedSigner.address, 1)).to.equal(1);
    });

    it("Should allow Group 1 to mint even after Group 2 supply is exhaused", async function () {
      const now = await time.latest();
      const presaleStartDate = now + 100;
      const presaleEndDate = now + 3600;

      uppercentNFTPass = await upgrades.deployProxy(
        UppercentNFTPass,
        [owner.address, 10, "testURI", 10, 1, 10, 2],
        { initializer: "initialize" }
      );

      // Create a pre-sale
      await uppercentNFTPass.createPresale(
        1,
        presaleStartDate,
        presaleEndDate
      );
      await time.increase(1000);
      let requiredAmount = await uppercentNFTPass.requiredMintAmount(8);
      await uppercentNFTPass.mint(8, { value: requiredAmount });

      // Impersonate and mint as the old NFT holder (Group 1)
      requiredAmount = await uppercentNFTPass.connect(impersonatedSigner).requiredMintAmount(1);
      await uppercentNFTPass.connect(impersonatedSigner).mint(1, { value: requiredAmount });

      // Verify the minting happened successfully
      expect(await uppercentNFTPass.balanceOf(impersonatedSigner.address, 1)).to.equal(1);
    });

    it("Should not allow minting at pre-sale price post pre-sale window is closed", async function () {
      this.timeout(120000);
      const now = await time.latest();
      const preSaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;

      // Create a pre-sale
      await uppercentNFTPass.createPresale(
        1,
        preSaleStartDate,
        preSaleEndDate
      );
      await time.increase(1000);
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(1);

      // Wait for pre-sale to end
      await time.increase(7200);

      await expect(
        uppercentNFTPass.mint(1, { value: requiredAmount })
      ).to.be.revertedWith(
        "Error: Insufficient amount sent"
      );
    });

    it("Should allow minting unsold pre-sale tokens at standard minting price", async function () {
      this.timeout(180000);
      UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
      uppercentNFTPass = await upgrades.deployProxy(
        UppercentNFTPass,
        [owner.address, 10, "testURI", 3, 2, 3, 0],
        { initializer: "initialize" }
      );

      // mint 1 token first
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      await uppercentNFTPass.mint(1, { value: requiredAmount });

      // create pre-sale with supply 2
      const now = await time.latest();
      const preSaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;
      await uppercentNFTPass.createPresale(
        1,
        preSaleStartDate,
        preSaleEndDate
      );
      await time.increase(1000);

      // mint token during pre-sale
      await uppercentNFTPass.mint(1, { value: requiredAmount });

      // close pre-sale before the end date
      await uppercentNFTPass.closePresale();
      // Wait for pre-sale to end
      await time.increase(1000);

      // mint unsold pre-sale token at standard minting price
      await uppercentNFTPass.mint(1, { value: requiredAmount });

      expect(await uppercentNFTPass.balanceOf(owner.address, 1)).to.equal(3);
    });
  });

  describe("Admin Earning:", function () {
    it("Should release funds to admin", async function () {
      this.timeout(120000);
      const requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      await uppercentNFTPass.mint(1, { value: requiredAmount });
      const adminBalanceBefore = await ethers.provider.getBalance(
        owner.address
      );
      await uppercentNFTPass.releaseFunds();
      const adminBalanceAfter = await ethers.provider.getBalance(owner.address);
      expect(adminBalanceAfter).to.be.gt(adminBalanceBefore);
    });
    it("Should return total earning for admin", async function () {
      this.timeout(120000);
      let requiredAmount = await uppercentNFTPass.requiredMintAmount(1);
      let totalAmount = requiredAmount;
      await uppercentNFTPass.mint(1, { value: requiredAmount });
      requiredAmount = await uppercentNFTPass.requiredMintAmount(2);
      totalAmount += requiredAmount;
      await uppercentNFTPass.mint(2, { value: requiredAmount });
      await uppercentNFTPass.releaseFunds();
      expect(await uppercentNFTPass.getEarnings(owner.address)).to.equal(
        totalAmount
      );
    });
  });
});
