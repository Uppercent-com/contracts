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
// to get data feed for Flare/Coston/Coston2
import "@flarenetwork/flare-periphery-contracts/coston/util-contracts/userInterfaces/IFlareContractRegistry.sol";
import "@flarenetwork/flare-periphery-contracts/coston/ftso/userInterfaces/IFtsoRegistry.sol";


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
    // Pre-sale state variable
    uint256 private _presaleMintPrice;
    uint256 private _presaleStartDate;
    uint256 private _presaleEndDate;
    uint256 private _presaleMaxSupply;
    uint256 private _presaleTotalSupply;
    bool private _presaleCreated;
    // Allow list state variables
    uint256 private _allowListPrice;
    uint256 private _allowListStartDate;
    uint256 private _allowListEndDate;
    uint256 private _allowListMaxLimit;
    bool private _allowListExists;
    uint256 private _totalReservedSupply;
    uint256 private _allowListDeposit;

    uint256 private _userMintLimit;
    address private constant FLARE_CONTRACT_REGISTRY = 0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019;

    mapping(address => uint256) private earnings;
    mapping(address => uint256) private allowListBalances;
    mapping(address => uint256) private reservedNFTPasses;

    // Event for presale creation
    event PresaleCreated(uint256 supply, uint256 price, uint256 startDate, uint256 endDate);
    event AllowListCreated(uint256 limit, uint256 price, uint256 startDate, uint256 endDate);
    event AllowListSubscribed(address indexed account, uint256 amount);

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
        _presaleCreated = false;
        _allowListExists = false;
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
        require(totalSupply(TOKEN_ID) + amount <= maxAavailableSupply(msg.sender), "Error: Exceeds maximum supply");
        require(msg.value >= requiredMintAmount(amount, msg.sender), "Error: Insufficient amount sent");

        adjustReservations(amount, msg.sender);
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
        require(totalSupply(TOKEN_ID) + amount <= maxAavailableSupply(msg.sender), "Error: Exceeds maximum supply");
        require(_presaleTotalSupply + amount <= maxAavailableSupplyPresale(msg.sender), "Error: Exceeds pre-sale supply");
        require(amount <= getUserMintLimit(msg.sender, TOKEN_ID), "Error: Exceeds per-user limit");
        require(msg.value >= requiredMintAmount(amount, msg.sender), "Error: Insufficient amount sent");

        adjustReservations(amount, msg.sender);
        _presaleTotalSupply += amount;

        // Mint NFTs, transfer earnings, and update user's pass count
        _mint(msg.sender, TOKEN_ID, amount, "");
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

        // Record earnings
        earnings[_admin] += adminShare;
        earnings[_creator] += creatorShare;

        // Transfer funds to admin and creator
        payable(_admin).transfer(adminShare);
        payable(_creator).transfer(creatorShare);
    }

    /**
     * Function that calculates required mint amount to mint NFT pass
     * @ amount is number of NFTs
     * @ account is wallet address
     */
    function requiredMintAmount(uint256 amount, address account) public view virtual returns (uint256) {
        uint256 mintPrice = getMintPrice();
        uint256 discountedPrice = mintPrice - _allowListPrice;
        uint256 reqAmount;

        if (reservedNFTPasses[account] > 0 && amount > 0) {
            uint256 reservedPasses = min(amount, reservedNFTPasses[account]);
            uint256 regularPasses = amount - reservedPasses;

            reqAmount = discountedPrice * reservedPasses + mintPrice * regularPasses;
        } else {
            reqAmount = mintPrice * amount;
        }

        return reqAmount;
    }

    /**
     * Helper function to get the minimum of two numbers
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    /**
     * max unlocked supply for regular minting
     * @ account is the sender wallet address
     */
    function maxAavailableSupply(address account) internal view returns (uint256){
        uint256 _maxAavailable = _maxSupply - _totalReservedSupply;
        uint256 _availableForUser = _maxAavailable + reservedNFTPasses[account];
        return _availableForUser;
    }

    /**
     * max unlocked supply for pre-sale minting
     * @ account is the sender wallet address
     */
    function maxAavailableSupplyPresale(address account) internal view returns (uint256){
        uint256 _maxAavailable = _presaleMaxSupply - _totalReservedSupply;
        uint256 _availableForUser = _maxAavailable + reservedNFTPasses[account];
        return _availableForUser;
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
     * Function to check if presale is created
     */
    function isPresaleCreated() public view virtual returns (bool) {
        return _presaleCreated;
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
     * Get creator & admin earnings
     */
    function getEarnings(address account) public view virtual returns (uint256) {
        return earnings[account];
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

    /**
     * 
     * FTSO Integration
     */
    function getPriceinWei(string memory _symbol) public view returns (uint256) {
        // access the contract registry
        IFlareContractRegistry contractRegistry = IFlareContractRegistry(
            FLARE_CONTRACT_REGISTRY
        );

        // retrieve the FTSO registry
        IFtsoRegistry ftsoRegistry = IFtsoRegistry(
            contractRegistry.getContractAddressByName("FtsoRegistry")
        );

        // get latest price
        (uint256 _price, , uint256 _decimals) = ftsoRegistry
            .getCurrentPriceWithDecimals(_symbol);

        return uint256((_price * (10 ** (18 - _decimals))) / 1e18);
    }

/////////////////////////////////////////////////////////    
//     ___    ____                 __    _      __     //
//    /   |  / / /___ _      __   / /   (_)____/ /_    //
//   / /| | / / / __ \ | /| / /  / /   / / ___/ __/    //  
//  / ___ |/ / / /_/ / |/ |/ /  / /___/ (__  ) /_      //
// /_/  |_/_/_/\____/|__/|__/  /_____/_/____/\__/      //
//                                                     //
/////////////////////////////////////////////////////////

    /**
     * 
     * Function for the owner to set an allow list
     */
    function setAllowList(
        uint256 limit,
        uint256 price,
        uint256 startDate,
        uint256 endDate
    ) public onlyOwner {
        require(!allowListExits(), "Error: Allow list exists");
        require(!isPresaleActive(), "Error: No Allow list when pre-sale is active");
        require(totalSupply(TOKEN_ID) + limit <= _maxSupply, "Error: Allow list supply exceeds max supply");
        require(price > 0, "Error: Price must be greater than zero");
        require(startDate < endDate, "Error: Invalid dates");

        // Set presale parameters
        _allowListMaxLimit = limit;
        _allowListPrice = price;
        _allowListStartDate = startDate;
        _allowListEndDate = endDate;
        _allowListExists = true;

        // Emit event for allow list creation
        emit AllowListCreated(limit, price, startDate, endDate);
    }

    /**
     * 
     * Function for the users to subscribe to an allow list
     */
    function subscribeAllowList(uint256 amount) public payable {
        uint256 userLimit = _userMintLimit-reservedNFTPasses[msg.sender];
        require(allowListExits() && isAllowListActive(), "Error: No allow list exists");
        require(!isPresaleActive(), "Error: Cannot subscribe when pre-sale is live");
        require(amount>0, "Error: Subscribe to at least 1 NFT pass");
        require(amount <= (_allowListMaxLimit-_totalReservedSupply), "Error: Exceeds maximum allowed list limit");
        require(amount <= userLimit, "Error: Exceeds per-user limit");
        require(msg.value >= _allowListPrice * amount, "Error: Insufficient amount sent");

        allowListBalances[msg.sender] += msg.value;
        reservedNFTPasses[msg.sender] += amount;
        _totalReservedSupply += amount;
        _allowListDeposit += msg.value;

        // Emit event for allow list subscription
        emit AllowListSubscribed(msg.sender, amount);

    }

    /**
     * Adjust NFT passes reservations
     */
    function adjustReservations(uint256 amount, address account) internal {
        uint256 reservedPasses = min(amount, reservedNFTPasses[account]);
        reservedNFTPasses[account] -= reservedPasses;
        allowListBalances[account] -= reservedPasses * _allowListPrice;
        _totalReservedSupply -= reservedPasses;
    }

    /**
     * 
     * Function to check if allow list exists
     */
    function allowListExits() public view virtual returns (bool) {
        return _allowListExists;
    }

    /**
     * 
     * Function to check if allow list is active
     */
    function isAllowListActive() public view virtual returns (bool) {
        return block.timestamp >= _allowListStartDate && block.timestamp <= _allowListEndDate;
    }

    /**
     * Returns supply of total reserved NFT passes
     */
    function getTotalReservedPasses() public view virtual returns (uint256) {
        return _totalReservedSupply;
    }

    /**
     * Returns user reserved NFT passes
     */
    function getUserReservedPasses(address account) public view virtual returns (uint256) {
        return reservedNFTPasses[account];
    }

    /**
     * Returns total deposit for allow list
     */
    function getAllowListDeposit() public view virtual returns (uint256) {
        return _allowListDeposit;
    }

    /**
     * Returns max limit for allow list
     */
    function getAllowListMaxLimit() public view virtual returns (uint256) {
        return _allowListMaxLimit;
    }

    /**
     * Returns allow list price
     */
    function getAllowListPrice() public view virtual returns (uint256) {
        return _allowListPrice;
    }
    
    /**
     * Returns start date of allow list
     */
    function getAllowListStartDate() public view virtual returns (uint256) {
        return _allowListStartDate;
    }

    /**
     * Returns end date of allow list
     */
    function getAllowListEndDate() public view virtual returns (uint256) {
        return _allowListEndDate;
    }

    /**
     * 
     * Function to close allow list window
     */
    function closeAllowList() public onlyOwner {
        _allowListEndDate = block.timestamp;
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