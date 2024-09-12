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

  beforeEach(async function () {
    [owner, buyer] = await ethers.getSigners();

    UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
    uppercentNFTPass = await upgrades.deployProxy(
      UppercentNFTPass,
      [owner.address, 10, "testURI", 100, 2, 10],
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
      await uppercentNFTPass.mint(1, { value: 2000000000000000000n });
      expect(await uppercentNFTPass.balanceOf(owner.address, 0)).to.equal(1);
    });

    it("Should not allow minting more than the maximum supply", async function () {
      UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
      uppercentNFTPass = await upgrades.deployProxy(
        UppercentNFTPass,
        [owner.address, 10, "testURI", 1, 1, 10],
        { initializer: "initialize" }
      );
      await uppercentNFTPass.mint(1, { value: 1000000000000000000n });
      await expect(
        uppercentNFTPass.mint(1, { value: 1000000000000000000n })
      ).to.be.revertedWith("Error: Exceeds maximum supply");
    });

    it("Should not allow minting more than the user's mint limit", async function () {
      UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
      uppercentNFTPass = await upgrades.deployProxy(
        UppercentNFTPass,
        [
          owner.address,
          10,
          "testURI",
          100,
          1000000000000000000n,
          2,
        ],
        { initializer: "initialize" }
      );
      await expect(
        uppercentNFTPass.mint(3, { value: 3000000000000000000n })
      ).to.be.revertedWith("Error: Exceeds per-user limit");
    });

    it("Should not allow minting with insufficient amount sent", async function () {
      await expect(
        uppercentNFTPass.mint(1, { value: 9n })
      ).to.be.revertedWith("Error: Insufficient amount sent");
    });

    it("Should pause minting", async function () {
      await uppercentNFTPass.pause();
      await expect(
        uppercentNFTPass.connect(buyer).mint(1, { value: 2000000000000000000n })
      ).to.be.revertedWithCustomError(uppercentNFTPass, "EnforcedPause");
    });
    it("Should unpause minting", async function () {
      await uppercentNFTPass.pause();
      await uppercentNFTPass.unpause();
      await uppercentNFTPass.mint(1, { value: 2000000000000000000n });
      expect(await uppercentNFTPass.balanceOf(owner.address, 0)).to.equal(1);
    });
  });

  describe("Creating Presale: ", function () {
    it("Should create a presale window and check if pre-sale is active", async function () {
      const now = Math.floor(Date.now() / 1000);
      const presaleStartDate = now + 100;
      const presaleEndDate = now + 3600;

      const createPresaleTx = await uppercentNFTPass.createPresale(
        50,
        1,
        presaleStartDate,
        presaleEndDate
      );
      await createPresaleTx.wait();
      await time.increase(1000);

      expect(await uppercentNFTPass.isPresaleActive()).to.equal(true);
    });

    it("Should set right presale supply", async function () {
      const now = Math.floor(Date.now() / 1000);
      const presaleStartDate = now + 100;
      const presaleEndDate = now + 3600;

      const createPresaleTx = await uppercentNFTPass.createPresale(
        50,
        1,
        presaleStartDate,
        presaleEndDate
      );
      await createPresaleTx.wait();
      await time.increase(1000);

      expect(await uppercentNFTPass.getPresaleMaxSupply()).to.equal(50);
    });

    it("Should set right presale price", async function () {
      const now = Math.floor(Date.now() / 1000);
      const presaleStartDate = now + 100;
      const presaleEndDate = now + 3600;

      const createPresaleTx = await uppercentNFTPass.createPresale(
        50,
        1,
        presaleStartDate,
        presaleEndDate
      );
      await createPresaleTx.wait();
      await time.increase(1000);

      expect(await uppercentNFTPass.getMintPrice()).to.equal(1);
    });

    it("Should set right presale start and end dates", async function () {
      const now = Math.floor(Date.now() / 1000);
      const presaleStartDate = now + 100;
      const presaleEndDate = now + 3600;

      const createPresaleTx = await uppercentNFTPass.createPresale(
        50,
        1,
        presaleStartDate,
        presaleEndDate
      );
      await createPresaleTx.wait();
      await time.increase(1000);

      expect(await uppercentNFTPass.getPresaleStartDate()).to.equal(presaleStartDate);
      expect(await uppercentNFTPass.getPresaleEndDate()).to.equal(
        presaleEndDate
      );
    });

    it("Should not allow creating a presale with invalid dates", async function () {
      const now = Math.floor(Date.now() / 1000);
      const presaleStartDate = now + 100;
      const presaleEndDate = now - 3600; // Invalid date (end before start)

      await expect(
        uppercentNFTPass.createPresale(50, 1, presaleStartDate, presaleEndDate)
      ).to.be.revertedWith("Error: Invalid presale dates");
    });

    it("Should not allow creating a presale with supply exceeding maximum supply", async function () {
      const now = Math.floor(Date.now() / 1000);
      const presaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;
      const supply = 101; // exceeds the maximum supply

      await expect(
        uppercentNFTPass.createPresale(supply, 1, presaleStartDate, preSaleEndDate)
      ).to.be.revertedWith("Error: Presale supply exceeds max supply");
    });
  });

  describe("Presale Minting: ", function () {
    it("Should mint NFTs during pre-sale with pre-sale price", async function () {
      const now = Math.floor(Date.now() / 1000);
      const presaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;

      // Create a pre-sale
      await uppercentNFTPass.createPresale(50, 1, presaleStartDate, preSaleEndDate);
      await time.increase(1000);
      await uppercentNFTPass.presaleMint(1, { value: 1000000000000000000n });

      expect(await uppercentNFTPass.balanceOf(owner.address, 0)).to.equal(1);
      expect(await uppercentNFTPass.isPresaleActive()).to.be.true;
      expect(await uppercentNFTPass.getMintPrice()).to.equal(1); // Pre-sale price
    });

    it("Should not allow minting more than the pre-sale max supply", async function () {
      const now = Math.floor(Date.now() / 1000);
      const presaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;

      // Create a pre-sale
      await uppercentNFTPass.createPresale(2, 1, presaleStartDate, preSaleEndDate);
      await time.increase(1000);

      await uppercentNFTPass.presaleMint(2, { value: 2000000000000000000n });

      await expect(
        uppercentNFTPass.presaleMint(1, { value: 1000000000000000000n })
      ).to.be.revertedWith("Error: Exceeds pre-sale supply");
    });

    it("Should not start pre-sale before the pre-sale start date", async function () {
      const now = Math.floor(Date.now() / 1000);
      const preSaleStartDate = now + 3600;
      const preSaleEndDate = preSaleStartDate + 3600;

      // Create a pre-sale
      await uppercentNFTPass.createPresale(
        50,
        1,
        preSaleStartDate,
        preSaleEndDate
      );

      await expect(
        uppercentNFTPass.presaleMint(1, { value: 1000000000000000000n })
      ).to.be.revertedWith(
        "Error: First pre-sale window is for allowed list or no active pre-sale"
      );
    });

    it("Should not allow standard minting during pre-sale window is active", async function () {
      const now = Math.floor(Date.now() / 1000);
      const preSaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;

      // Create a pre-sale
      await uppercentNFTPass.createPresale(50, 1, preSaleStartDate, preSaleEndDate);
      await time.increase(1000);

      await expect(
        uppercentNFTPass.mint(1, { value: 2000000000000000000n })
      ).to.be.revertedWith("Error: Pre-sale in Progress");
    });

    it("Should not allow minting at pre-sale price post pre-sale window is closed", async function () {
      const now = Math.floor(Date.now() / 1000);
      const preSaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;

      // Create a pre-sale
      await uppercentNFTPass.createPresale(50, 1, preSaleStartDate, preSaleEndDate);

      // Wait for pre-sale to end
      await time.increase(7200);

      await expect(
        uppercentNFTPass.presaleMint(1, { value: 1000000000000000000n })
      ).to.be.revertedWith(
        "Error: First pre-sale window is for allowed list or no active pre-sale"
      );
    });
    it("Should allow minting unsold pre-sale tokens at standard minting price", async function () {
      UppercentNFTPass = await ethers.getContractFactory("UppercentNFTPass");
      uppercentNFTPass = await upgrades.deployProxy(
        UppercentNFTPass,
        [owner.address, 10, "testURI", 3, 2, 3],
        { initializer: "initialize" }
      );

      // mint 1 token first
      await uppercentNFTPass.mint(1, { value: 2000000000000000000n });

      // create pre-sale with supply 2
      const now = Math.floor(Date.now() / 1000);
      const preSaleStartDate = now + 100;
      const preSaleEndDate = now + 3600;
      await uppercentNFTPass.createPresale(2, 1, preSaleStartDate, preSaleEndDate);
      await time.increase(1000);

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

  describe("Admin Earning:", function () {
    it("Should release funds to admin", async function () {
      await uppercentNFTPass.mint(1, { value: 2000000000000000000n });
      const adminBalanceBefore = await ethers.provider.getBalance(
        owner.address
      );
      await uppercentNFTPass.releaseFunds();
      const adminBalanceAfter = await ethers.provider.getBalance(owner.address);
      expect(adminBalanceAfter).to.be.gt(adminBalanceBefore);
    });
    it("Should return total earning for admin", async function () {
      await uppercentNFTPass.mint(1, { value: 2000000000000000000n });
      await uppercentNFTPass.mint(2, { value: 4000000000000000000n });
      await uppercentNFTPass.releaseFunds();
      expect(await uppercentNFTPass.getEarnings(owner.address)).to.equal(
        600000000000000000n
      );
    });
  });

  describe("Setting up Allow List: ", function () {
    it("Should set up allow list and check if allow list is active", async function () {
      const now = Math.floor(Date.now() / 1000);
      const allowlistEndDate = now + 3600;

      const tx = await uppercentNFTPass.setAllowList(
        50,
        1,
        now,
        allowlistEndDate
      );
      await tx.wait();

      expect(await uppercentNFTPass.isAllowListActive()).to.equal(true);
    });

    it("Should set right limit for allow list", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;

      const tx = await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await tx.wait();

      expect(await uppercentNFTPass.getAllowListMaxLimit()).to.equal(50);
    });

    it("Should set right allow list price", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;

      const tx = await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await tx.wait();

      expect(await uppercentNFTPass.getAllowListPrice()).to.equal(1);
    });

    it("Should set right allow list start and end dates", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;

      const tx = await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await tx.wait();

      expect(await uppercentNFTPass.getAllowListStartDate()).to.equal(now);
      expect(await uppercentNFTPass.getAllowListEndDate()).to.equal(endDate);
    });

    it("Should not allow setting up a allow list with invalid dates", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now - 3600; // Invalid date (end before start)

      await expect(
        uppercentNFTPass.setAllowList(50, 1, now, endDate)
      ).to.be.revertedWith("Error: Invalid dates");
    });

    it("Should not allow creating an allow list with limit exceeding maximum supply", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      const supply = 101; // exceeds the maximum supply

      await expect(
        uppercentNFTPass.setAllowList(supply, 1, now, endDate)
      ).to.be.revertedWith("Error: Allow list supply exceeds max supply");
    });

    it("Should not allow creating an allow list if pre-sale is active", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      // creating pre-sale
      const createPresaleTx = await uppercentNFTPass.createPresale(
        50,
        1,
        now,
        endDate
      );
      await createPresaleTx.wait();
      // setting up allow list
      await expect(
        uppercentNFTPass.setAllowList(50, 1, now, endDate)
      ).to.be.revertedWith("Error: No Allow list when pre-sale is active");
    });

    it("Should not allow creating an allow list again", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      // setting up allow list
      const tx1 = await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await tx1.wait();
      // setting up allow list again
      await expect(
        uppercentNFTPass.setAllowList(50, 1, now, endDate)
      ).to.be.revertedWith("Error: Allow list exists");
    });
  });

  describe("Subscribing Allow List: ", function () {
    it("Should not allow subscription with no active allow list", async function () {
      await expect(
        uppercentNFTPass.subscribeAllowList(1, { value: 1000000000000000000n })
      ).to.be.revertedWith("Error: No allow list exists");
    });

    it("Should allow subscription for at least 1 NFT pass", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      // setting up allow list
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(1, {
        value: 1000000000000000000n,
      });
      expect(
        await uppercentNFTPass.getUserReservedPasses(owner.address)
      ).to.equal(1);
    });

    it("Should not allow subscription for more than the allow-list limit", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      // setting up allow list
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(1, {
        value: 1000000000000000000n,
      });
      await expect(
        uppercentNFTPass.subscribeAllowList(50, { value: 1000000000000000000n })
      ).to.be.revertedWith("Error: Exceeds maximum allowed list limit");
    });

    it("Should not allow subscription for more than the user limit", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      // setting up allow list
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(9, {
        value: 9000000000000000000n,
      });
      await expect(
        uppercentNFTPass.subscribeAllowList(2, { value: 2000000000000000000n })
      ).to.be.revertedWith("Error: Exceeds per-user limit");
    });

    it("Should not allow subscription for insufficient amount", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      // setting up allow list
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await expect(
        uppercentNFTPass.subscribeAllowList(2, { value: 1000000000000000000n })
      ).to.be.revertedWith("Error: Insufficient amount sent");
    });

    it("Should not allow subscription when the pre-sale is live", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      // setting up allow list
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.createPresale(50, 1, now, endDate);
      await expect(
        uppercentNFTPass.subscribeAllowList(1, { value: 1000000000000000000n })
      ).to.be.revertedWith("Error: Cannot subscribe when pre-sale is live");
    });

    it("Should return user the correct number of reserved NFT paases in an allow-list", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(5, {
        value: 5000000000000000000n,
      });
      expect(
        await uppercentNFTPass.getUserReservedPasses(owner.address)
      ).to.equal(5);
    });

    it("Should return the correct total deposit in an allow-list", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(5, {
        value: 5000000000000000000n,
      });
      await uppercentNFTPass.subscribeAllowList(4, {
        value: 4000000000000000000n,
      });
      expect(await uppercentNFTPass.getAllowListDeposit()).to.equal(
        9000000000000000000n
      );
    });

    it("Should allow minting at discounted rate during a pre-sale at pre-sale price", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(5, {
        value: 5000000000000000000n,
      });
      await uppercentNFTPass.createPresale(50, 2, now, endDate); // pre-sale rate: $2
      await uppercentNFTPass.presaleMint(5, { value: 5000000000000000000n }); // required amount to mint 5 NFTs: 5000000000000000000n
      expect(await uppercentNFTPass.balanceOf(owner.address, 0)).to.equal(5);
    });

    it("Should not permit non-allow-list users to mint during first presale window", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.createPresale(50, 2, now, endDate); // pre-sale rate: $2
      await expect(
        uppercentNFTPass
          .connect(buyer)
          .presaleMint(5, { value: 5000000000000000000n })
      ).to.be.revertedWith(
        "Error: First pre-sale window is for allowed list or no active pre-sale"
      );
    });

    it("Should permit non-allow-list users to mint after first presale window is over", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.createPresale(50, 2, now, endDate); // pre-sale rate: $2
      await uppercentNFTPass.setFirstPresaleWindow(5); // setting pre-sale first window for 5 seconds
      // Wait for first pre-sale window to end
      await new Promise((resolve) => setTimeout(resolve, 5100));
      await uppercentNFTPass
        .connect(buyer)
        .presaleMint(5, { value: 10000000000000000000n });
      expect(await uppercentNFTPass.balanceOf(buyer, 0)).to.equal(5);
    });

    it("Should not permit non-allow-list users to mint at discounted price", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(5, {
        value: 5000000000000000000n,
      }); // owner address reserved 5 NFTs
      await uppercentNFTPass.createPresale(50, 2, now, endDate); // pre-sale rate: $2
      await uppercentNFTPass.setFirstPresaleWindow(5); // setting pre-sale first window for 5 seconds
      // Wait for first pre-sale window to end
      await new Promise((resolve) => setTimeout(resolve, 5100));
      await expect(
        uppercentNFTPass
          .connect(buyer)
          .presaleMint(5, { value: 5000000000000000000n })
      ).to.be.revertedWith("Error: Insufficient amount sent"); // required amount to mint 5 NFTs: 10000000000000000000n for non-allow-list users
    });

    it("Should not permit non-allow-list users to mint reserved NFTs", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(5, {
        value: 5000000000000000000n,
      }); // owner address reserved 5 NFTs
      await uppercentNFTPass.createPresale(50, 2, now, endDate); // pre-sale rate: 2000000000000000000n
      await expect(
        uppercentNFTPass
          .connect(buyer)
          .presaleMint(46, { value: 92000000000000000000n })
      ).to.be.revertedWith(
        "Error: First pre-sale window is for allowed list or no active pre-sale"
      );
    });

    it("Should ensure the required amount, to mint NFTs more than the reserved, is correct", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(5, {
        value: 5000000000000000000n,
      }); // owner address reserved 5 NFTs
      await uppercentNFTPass.createPresale(50, 2, now, endDate); // pre-sale rate: 2000000000000000000n
      expect(
        await uppercentNFTPass.requiredMintAmount(10, owner.address)
      ).to.equal(15000000000000000000n);
    });

    it("Should enable discounted minting during regular sale when pre-sale is inactive.", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(5, {
        value: 5000000000000000000n,
      });
      await uppercentNFTPass.mint(5, { value: 5000000000000000000n });
      expect(await uppercentNFTPass.balanceOf(owner.address, 0)).to.equal(5);
    });

    it("Should reset reserved supply after the first pre-sale window is over", async function () {
      const now = Math.floor(Date.now() / 1000);
      const endDate = now + 3600;
      await uppercentNFTPass.setAllowList(50, 1, now, endDate);
      await uppercentNFTPass.subscribeAllowList(5, {
        value: 5000000000000000000n,
      }); // owner address reserved 5 NFTs
      const uReserved = await uppercentNFTPass.getUserReservedPasses(
        owner.address
      );
      await uppercentNFTPass.createPresale(50, 2, now, endDate); // pre-sale rate: $2
      await uppercentNFTPass.setFirstPresaleWindow(5); // setting pre-sale first window for 5 seconds
      // Wait for first pre-sale window to end
      await new Promise((resolve) => setTimeout(resolve, 5100));
      const uResPostWindow = await uppercentNFTPass.getUserReservedPasses(
        owner.address
      );
      expect(uReserved).to.be.gt(uResPostWindow);
    });
  });
});
