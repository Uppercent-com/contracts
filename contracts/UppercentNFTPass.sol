// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//     __  __                                      __     _   ______________   ____                             //
//    / / / /___  ____  ___  _____________  ____  / /_   / | / / ____/_  __/  / __ \____ ______________  _____. //
//   / / / / __ \/ __ \/ _ \/ ___/ ___/ _ \/ __ \/ __/  /  |/ / /_    / /    / /_/ / __ `/ ___/ ___/ _ \/ ___/  //
//  / /_/ / /_/ / /_/ /  __/ /  / /__/  __/ / / / /_   / /|  / __/   / /    / ____/ /_/ (__  |__  )  __(__  )   //
//  \____/ .___/ .___/\___/_/   \___/\___/_/ /_/\__/  /_/ |_/_/     /_/    /_/    \__,_/____/____/\___/____/    //
//      /_/   /_/                                                                                               //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * 
 * UppercentNFTPass contract combining ERC1155 features with: 
 * Ownable, Pausable, Burnable, Supply, and UUPS upgradeability 
 */
contract UppercentNFTPass is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ERC1155PausableUpgradeable, ERC1155BurnableUpgradeable, ERC1155SupplyUpgradeable, UUPSUpgradeable {
    
    // 
    /**
     * Constant for token ID
     * @notice A new contract per course NFT passes
     * Hence token ID is fixed to '0'
     */
    uint256 public constant TOKEN_ID = 0;

    // State variables for contract parameters
    uint256 private _maxSupply;
    address private _creator;
    address private _admin;
    uint256 private _adminEarning;
    uint256 private _creatorEarning;
    uint256 private _mintPrice;
    uint256 private _presaleMintPrice;
    uint256 private _presaleStartDate;
    uint256 private _presaleEndDate;
    uint256 private _presaleMaxSupply;
    uint256 private _presaleTotalSupply;
    uint256 private _userMintLimit;
    bool private _presaleCreated;

    // Event for presale creation
    event PresaleCreated(uint256 supply, uint256 price, uint256 startDate, uint256 endDate);

    // Modifier to allow execution only once
    modifier onlyOnce() {
        require(!_presaleCreated, "Error: Can only be called once");
        _;
        _presaleCreated = true;
    }

    /**
     * 
     * Initialize function to set up the contract parameters
     */
    function initialize(
        address owner, 
        address creator, 
        uint256 adminEarning, 
        uint256 creatorEarning, 
        string memory uri, 
        uint256 maxSupply,
        uint256 mintPrice,
        uint256 userMintLimit
        ) initializer public {

        // Initialize ERC1155 and other upgradeable contracts
        __ERC1155_init(uri);
        __Ownable_init(owner);
        __ERC1155Pausable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();

        // Set contract parameters
        _maxSupply = maxSupply;
        _mintPrice = mintPrice;
        _creator = creator;
        _admin = owner;
        _adminEarning = adminEarning;
        _creatorEarning = creatorEarning;
        _userMintLimit = userMintLimit;
    }

    /**
     * 
     * Function to set the URI for metadata
     */
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /**
     * 
     * Function to pause the contract
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * 
     * Function to unpause the contract
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * 
     * Function to mint NFTs at standard minting price
     */
    function mint(uint256 amount) public payable {
        // Check various conditions before allowing minting
        require(!isPresaleActive(), "Error: Pre-sale in Progress");
        require(amount <= getUserMintLimit(msg.sender, TOKEN_ID), "Error: Exceeds per-user limit");
        require(totalSupply(TOKEN_ID) + amount <= _maxSupply, "Error: Exceeds maximum supply");
        require(msg.value >= getMintPrice() * amount, "Error: Insufficient amount sent");

        // Mint NFTs, transfer earnings, and update user's pass count
        _mint(msg.sender, TOKEN_ID, amount, "");
    }

    /**
     * 
     * Function to mint NFTs during pre-sale window
     */
    function presaleMint(uint256 amount) public payable {
        // Check various conditions before allowing minting
        require(isPresaleActive(), "Error: No active pre-sale");
        require(totalSupply(TOKEN_ID) + amount <= _maxSupply, "Error: Exceeds maximum supply");
        require(_presaleTotalSupply + amount <= _presaleMaxSupply, "Error: Exceeds pre-sale supply");
        require(amount <= getUserMintLimit(msg.sender, TOKEN_ID), "Error: Exceeds per-user limit");
        require(msg.value >= getMintPrice() * amount, "Error: Insufficient amount sent");

        // Mint NFTs, transfer earnings, and update user's pass count
        _mint(msg.sender, TOKEN_ID, amount, "");
        _presaleTotalSupply += amount;
    }

    /**
     * 
     * Function for the owner to create a presale
     * It can be be called only once
     */
    function createPresale(
        uint256 supply,
        uint256 price,
        uint256 startDate,
        uint256 endDate
    ) public onlyOwner onlyOnce {
        require(totalSupply(TOKEN_ID) + supply <= _maxSupply, "Error: Presale supply exceeds max supply");
        require(price > 0, "Error: Presale price must be greater than zero");
        require(startDate < endDate, "Error: Invalid presale dates");

        // Set presale parameters
        _presaleMaxSupply = supply;
        _presaleMintPrice = price;
        _presaleStartDate = startDate;
        _presaleEndDate = endDate;

        // Emit event for presale creation
        emit PresaleCreated(supply, price, startDate, endDate);
    }

    /**
     * 
     * Function for the owner to release and withdraw funds to the admin and creator
     */
    function releaseFunds() public onlyOwner {
        // Calculate admin and creator shares
        uint256 adminShare = (address(this).balance * _adminEarning) / 100;
        uint256 creatorShare = (address(this).balance * _creatorEarning) / 100;

        // Transfer funds to admin and creator
        payable(_admin).transfer(adminShare);
        payable(_creator).transfer(creatorShare);
    }

    /**
     * 
     * Function to check if presale is active
     */
    function isPresaleActive() public view virtual returns (bool) {
        return block.timestamp >= _presaleStartDate && block.timestamp <= _presaleEndDate;
    }
 
    /**
     * 
     * Function to close pre-sale window
     */
    function closePresale() public onlyOwner {
        _presaleEndDate = block.timestamp;
    }

    /**
     * 
     * Get maximum supply of token
     */
    function getMaxSupply() public view virtual returns (uint256) {
        return _maxSupply;
    }

    /**
     * Get creator address
     */
    function getCreator() public view virtual returns (address) {
        return _creator;
    }

    /**
     * 
     * Get admin share
     */
    function getAdminShare() public view virtual returns (uint256) {
        return _adminEarning;
    }

    /**
     * 
     * Get creator share
     */
    function getCreatorShare() public view virtual returns (uint256) {
        return _creatorEarning;
    }

    /**
     * 
     * Get current mint price based on presale status
     */
    function getMintPrice() public view virtual returns (uint256){
        uint256 price = isPresaleActive() ? _presaleMintPrice: _mintPrice;
        return price;
    }

    /**
     * 
     * Get pre-sale start date
     */
    function getPresaleStartDate() public view virtual returns (uint256) {
        return _presaleStartDate;
    }

    /**
     * 
     * Get pre-sale start date
     */
    function getPresaleEndDate() public view virtual returns (uint256) {
        return _presaleEndDate;
    }

    /**
     * 
     * Get pre-sale maximum supply
     */
    function getPresaleMaxSupply() public view virtual returns (uint256) {
        return _presaleMaxSupply;
    }

    /**
     * 
     * Get pre-sale total supply
     */
    function getPresaleTotalSupply() public view virtual returns (uint256) {
        return _presaleTotalSupply;
    }

    /**
     * 
     * Get per user mint limit
     */
    function getUserMintLimit(address user, uint256 id) public view virtual returns (uint256) {
        return _userMintLimit - balanceOf(user, id);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

    /**
     * 
     * The following functions are overrides required by Solidity. 
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override(ERC1155Upgradeable, ERC1155PausableUpgradeable, ERC1155SupplyUpgradeable) {
        super._update(from, to, ids, values);
    }
}