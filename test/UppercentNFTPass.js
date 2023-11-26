// tests/UppercentNFTPass.js
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
// "upgrades" module is used for dealing with upgradeable contracts

describe("UppercentNFTPass", function () {
  let UppercentNFTPass;
  let uppercentNFTPass;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
    uppercentNFTPass = await upgrades.deployProxy(UppercentNFTPass, [owner.address, addr1.address, 10, 20, "testURI", 100, 2000000000000000000n, 10], { initializer: 'initialize' });
    //await uppercentNFTPass.deployed();
  });

  describe("Deployment: ", function () {
    it("Should set the right owner", async function () {
      expect(await uppercentNFTPass.owner()).to.equal(owner.address);
    });
    it("Should set the right creator", async function () {
        expect(await uppercentNFTPass.getCreator()).to.equal(addr1.address);
    });
    it("Should set the right admin share", async function () {
        expect(await uppercentNFTPass.getAdminShare()).to.equal(10);
    });
    it("Should set the right creator share", async function () {
        expect(await uppercentNFTPass.getCreatorShare()).to.equal(20);
    });
    it("Should set the right URI", async function () {
        expect(await uppercentNFTPass.uri(0)).to.equal("testURI");
    });
    it("Should set the right maximum supply", async function () {
        expect(await uppercentNFTPass.getMaxSupply()).to.equal(100);
    });
    it("Should set the right mint price", async function () {
        const mintPrice = await uppercentNFTPass.getMintPrice();
        expect(mintPrice).to.equal(2000000000000000000n);
    });
  });

  describe("Standard Minting: ", function () {
    it("Should mint NFTs and update user's balance", async function () {
        await uppercentNFTPass.mint(1, { value: 2000000000000000000n });
        expect(await uppercentNFTPass.balanceOf(owner.address, 0)).to.equal(1);
    });

    it("Should not allow minting more than the maximum supply", async function () {
        UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
        uppercentNFTPass = await upgrades.deployProxy(UppercentNFTPass, [owner.address, addr1.address, 10, 20, "testURI", 1, 1000000000000000000n, 10], { initializer: 'initialize' });
        await uppercentNFTPass.mint(1, { value: 1000000000000000000n });
        await expect(uppercentNFTPass.mint(1, { value: 1000000000000000000n })).to.be.revertedWith(
            "Error: Exceeds maximum supply"
        );
    });

    it("Should not allow minting more than the user's mint limit", async function () {
        UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
        uppercentNFTPass = await upgrades.deployProxy(UppercentNFTPass, [owner.address, addr1.address, 10, 20, "testURI", 100, 1000000000000000000n, 2], { initializer: 'initialize' });
        await expect(uppercentNFTPass.mint(3, { value: 3000000000000000000n })).to.be.revertedWith(
            "Error: Exceeds per-user limit"
        );
    });

    it("Should not allow minting with insufficient amount sent", async function () {
      await expect(uppercentNFTPass.mint(1, { value: 1999999999999999999n })).to.be.revertedWith(
        "Error: Insufficient amount sent"
      );
    });
  });

  describe("Create Presale: ", function () {
    it("Should create a presale window and check if pre-sale is active", async function () {
        const now = Math.floor(Date.now() / 1000);
        const presaleEndDate = now + 3600;
        
        const createPresaleTx = await uppercentNFTPass.createPresale(50, 1000000000000000000n, now, presaleEndDate);
        await createPresaleTx.wait();

        expect(await uppercentNFTPass.isPresaleActive()).to.equal(true);
    });

    it("Should set right presale supply", async function () {
        const now = Math.floor(Date.now() / 1000);
        const presaleEndDate = now + 3600;
        
        const createPresaleTx = await uppercentNFTPass.createPresale(50, 1000000000000000000n, now, presaleEndDate);
        await createPresaleTx.wait();

        expect(await uppercentNFTPass.getPresaleMaxSupply()).to.equal(50);
    });

    it("Should set right presale price", async function () {
        const now = Math.floor(Date.now() / 1000);
        const presaleEndDate = now + 3600;
        
        const createPresaleTx = await uppercentNFTPass.createPresale(50, 1000000000000000000n, now, presaleEndDate);
        await createPresaleTx.wait();

        expect(await uppercentNFTPass.getMintPrice()).to.equal(1000000000000000000n);
    });

    it("Should set right presale start and end dates", async function () {
        const now = Math.floor(Date.now() / 1000);
        const presaleEndDate = now + 3600;
        
        const createPresaleTx = await uppercentNFTPass.createPresale(50, 1000000000000000000n, now, presaleEndDate);
        await createPresaleTx.wait();

        expect(await uppercentNFTPass.getPresaleStartDate()).to.equal(now);
        expect(await uppercentNFTPass.getPresaleEndDate()).to.equal(presaleEndDate);
    });

    it("Should not allow creating a presale with invalid dates", async function () {
      const now = Math.floor(Date.now() / 1000);
      const presaleEndDate = now - 3600; // Invalid date (end before start)

      await expect(
        uppercentNFTPass.createPresale(50, 1000000000000000000n, now, presaleEndDate)
      ).to.be.revertedWith("Error: Invalid presale dates");
    });

    it("Should not allow creating a presale with supply exceeding maximum supply", async function () {
        const now = Math.floor(Date.now() / 1000);
        const preSaleEndDate = now + 3600;
        const supply = 101; // exceeds the maximum supply

      await expect(
        uppercentNFTPass.createPresale(supply, 1000000000000000000n, now, preSaleEndDate)
      ).to.be.revertedWith("Error: Presale supply exceeds max supply");
    });
  });

  describe("Presale Minting: ", function () {
    it("Should mint NFTs during pre-sale with pre-sale price", async function () {
        const now = Math.floor(Date.now() / 1000);
        const preSaleEndDate = now + 3600;
  
        // Create a pre-sale
        await uppercentNFTPass.createPresale(50, 1000000000000000000n, now, preSaleEndDate);
        await uppercentNFTPass.presaleMint(1, { value: 1000000000000000000n });
  
        expect(await uppercentNFTPass.balanceOf(owner.address, 0)).to.equal(1);
        expect(await uppercentNFTPass.isPresaleActive()).to.be.true;
        expect(await uppercentNFTPass.getMintPrice()).to.equal(1000000000000000000n); // Pre-sale price
      });
  
      it("Should not allow minting more than the pre-sale max supply", async function () {
        const now = Math.floor(Date.now() / 1000);
        const preSaleEndDate = now + 3600;
  
        // Create a pre-sale
        await uppercentNFTPass.createPresale(2, 1000000000000000000n, now, preSaleEndDate);
  
        await uppercentNFTPass.presaleMint(2, { value: 2000000000000000000n });
  
        await expect(uppercentNFTPass.presaleMint(1, { value: 1000000000000000000n })).to.be.revertedWith(
          "Error: Exceeds pre-sale supply"
        );
      });

      it("Should not start pre-sale before the pre-sale start date", async function () {
        const now = Math.floor(Date.now() / 1000);
        const preSaleStartDate = now + 3600;
        const preSaleEndDate = preSaleStartDate + 3600;
  
        // Create a pre-sale
        await uppercentNFTPass.createPresale(50, 1000000000000000000n, preSaleStartDate, preSaleEndDate);
  
        await expect(uppercentNFTPass.presaleMint(1, { value: 1000000000000000000n })).to.be.revertedWith(
          "Error: No active pre-sale"
        );
      });

      it("Should not allow standard minting during pre-sale window is active", async function () {
        const now = Math.floor(Date.now() / 1000);
        const preSaleEndDate = now + 3600;
  
        // Create a pre-sale
        await uppercentNFTPass.createPresale(50, 1000000000000000000n, now, preSaleEndDate);
  
        await expect(uppercentNFTPass.mint(1, { value: 2000000000000000000n })).to.be.revertedWith(
          "Error: Pre-sale in Progress"
        );
      });
  
      it("Should not allow minting at pre-sale price post pre-sale window is closed", async function () {
        const now = Math.floor(Date.now() / 1000);
        const preSaleEndDate = now + 1; // Set a very short pre-sale duration
  
        // Create a pre-sale
        await uppercentNFTPass.createPresale(50, 1000000000000000000n, now, preSaleEndDate);
  
        // Wait for pre-sale to end
        await new Promise((resolve) => setTimeout(resolve, 2000));
  
        await expect(uppercentNFTPass.presaleMint(1, { value: 1000000000000000000n })).to.be.revertedWith(
          "Error: No active pre-sale"
        );
      });
      it("Should allow minting unsold pre-sale tokens at standard minting price", async function () {
        UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
        uppercentNFTPass = await upgrades.deployProxy(UppercentNFTPass, [owner.address, addr1.address, 10, 20, "testURI", 3, 2000000000000000000n, 3], { initializer: 'initialize' });
        
        // mint 1 token first
        await uppercentNFTPass.mint(1, { value: 2000000000000000000n });
        
        // create pre-sale with supply 2
        const now = Math.floor(Date.now() / 1000);
        const preSaleEndDate = now + 3600;
        await uppercentNFTPass.createPresale(2, 1000000000000000000n, now, preSaleEndDate);
  
        // mint token during pre-sale
        await uppercentNFTPass.presaleMint(1, { value: 1000000000000000000n });

        // close pre-sale before the end date
        await uppercentNFTPass.closePresale();
        // Wait for pre-sale to end
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // mint unsold pre-sale token at standard minting price
        await uppercentNFTPass.mint(1, { value: 2000000000000000000n });

        expect(await uppercentNFTPass.balanceOf(owner.address, 0)).to.equal(3);
      });
  });

  describe("Payment Distribution: ", function () {
    it("Should release funds to admin", async function () {
      await uppercentNFTPass.mint(1, { value: 2000000000000000000n });
      const adminBalanceBefore = await ethers.provider.getBalance(owner.address);
      await uppercentNFTPass.releaseFunds();
      const adminBalanceAfter = await ethers.provider.getBalance(owner.address);
      expect(adminBalanceAfter).to.be.gt(adminBalanceBefore);
    });
    it("Should release funds to creator", async function () {
        await uppercentNFTPass.mint(1, { value: 2000000000000000000n });
        const creatorBalanceBefore = await ethers.provider.getBalance(addr1.address);
        await uppercentNFTPass.releaseFunds();
        const creatorBalanceAfter = await ethers.provider.getBalance(addr1.address);
        expect(creatorBalanceAfter).to.be.gt(creatorBalanceBefore);
      });
  });
});
