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
// to get data feed for Flare/Coston/Coston2/Songbird
import "@flarenetwork/flare-periphery-contracts/coston2/ContractRegistry.sol";
import "@flarenetwork/flare-periphery-contracts/coston2/TestFtsoV2Interface.sol";

/**
 *
 * UppercentNFTPass contract combining ERC1155 features with:
 * Ownable, Pausable, Burnable, Supply, and UUPS upgradeability
 */
contract UppercentNFTPass is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155BurnableUpgradeable,
    ERC1155SupplyUpgradeable,
    UUPSUpgradeable
{
    TestFtsoV2Interface internal ftsoV2;
    //
    /**
     * Constant for token ID
     * @notice A new contract per course NFT passes
     * Hence token ID is fixed to '0'
     */
    uint256 public constant TOKEN_ID = 0;
    string private constant TOKEN_SYMBOL = "SGB"; // for FTSO
    bytes21 private constant FEED_ID = bytes21(0x01464c522f55534400000000000000000000000000); // FLR/USD

    // State variables for contract parameters
    uint256 private _maxSupply;
    address private _admin;
    uint256 private _adminEarning;
    uint256 private _mintPrice;
    // Pre-sale state variable
    uint256 private _presaleMintPrice;
    uint256 private _presaleStartDate;
    uint256 private _presaleEndDate;
    uint256 private _firstPresaleWindow;
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
    address private constant FLARE_CONTRACT_REGISTRY =
        0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019;

    mapping(address => uint256) private earnings;
    mapping(address => uint256) private allowListBalances;
    mapping(address => uint256) private reservedNFTPasses;

    // Event for presale creation
    event PresaleCreated(
        uint256 supply,
        uint256 price,
        uint256 startDate,
        uint256 endDate
    );
    event AllowListCreated(
        uint256 limit,
        uint256 price,
        uint256 startDate,
        uint256 endDate
    );
    event AllowListSubscribed(address indexed account, uint256 amount);

    // Modifier to allow execution only once
    modifier onlyOnce() {
        require(!_presaleCreated, "Error: Can only be called once");
        _;
        _presaleCreated = true;
    }

    // Modifier to allow execution only during the first pre-sale window (default: 7 days) for allow-list users
    modifier onlyDuringFirst7Days() {
        require(
            // Check if it's within the first pre-sale window and the sender is on the allow-list
            (isFirstPresaleWindow() && reservedNFTPasses[msg.sender] > 0) ||
                // Or if it's after the first pre-sale window
                (isPresaleActive() &&
                    (!allowListExits() ||
                        block.timestamp >
                        (_presaleStartDate + _firstPresaleWindow))),
            "Error: First pre-sale window is for allowed list or no active pre-sale"
        );
        _;
    }

    /**
     *
     * Initialize function to set up the contract parameters
     */
    function initialize(
        address owner,
        uint256 adminEarning,
        string memory uri,
        uint256 maxSupply,
        uint256 mintPrice,
        uint256 userMintLimit
    ) public initializer {
        // Initialize ERC1155 and other upgradeable contracts
        __ERC1155_init(uri);
        __Ownable_init(owner);
        __ERC1155Pausable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();

        // Set contract parameters
        _maxSupply = maxSupply;
        _mintPrice = mintPrice; // $USD
        _admin = owner;
        _adminEarning = adminEarning;
        _userMintLimit = userMintLimit;
        _presaleCreated = false;
        _allowListExists = false;
        _firstPresaleWindow = 7 days;
        ftsoV2 = ContractRegistry.getTestFtsoV2();
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
     * Function to change admin address
     */
    function changeAdmin(address newAdmin) public onlyOwner {
        // Check for address 0
        require(newAdmin != address(0), "Error:  address");
        _admin = newAdmin;
    }

    /**
     * @dev Function to update the percentage of earnings the admin should receive.
     * @param percentage The percentage of earnings to be allocated to the admin.
     */
    function updateAdminsShare(uint256 percentage) public onlyOwner {
        // Check for address 0
        require(percentage > 0, "Error: Invalid percentage");
        _adminEarning = percentage;
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
        require(
            amount <= getUserMintLimit(msg.sender, TOKEN_ID),
            "Error: Exceeds per-user limit"
        );
        require(
            totalSupply(TOKEN_ID) + amount <=
                maxAvailableSupply(msg.sender, _maxSupply),
            "Error: Exceeds maximum supply"
        );
        require(
            msg.value >= requiredMintAmount(amount, msg.sender),
            "Error: Insufficient amount sent"
        );

        adjustReservations(amount, msg.sender);
        // Mint NFTs, transfer earnings, and update user's pass count
        _mint(msg.sender, TOKEN_ID, amount, "");
    }

    /**
     *
     * Function to mint NFTs during pre-sale window
     */
    function presaleMint(uint256 amount) public payable onlyDuringFirst7Days {
        // Check various conditions before allowing minting

        require(isPresaleActive(), "Error: No active pre-sale");
        require(
            totalSupply(TOKEN_ID) + amount <=
                maxAvailableSupply(msg.sender, _maxSupply),
            "Error: Exceeds maximum supply"
        );
        require(
            _presaleTotalSupply + amount <=
                maxAvailableSupply(msg.sender, _presaleMaxSupply),
            "Error: Exceeds pre-sale supply"
        );
        require(
            amount <= getUserMintLimit(msg.sender, TOKEN_ID),
            "Error: Exceeds per-user limit"
        );
        require(
            msg.value >= requiredMintAmount(amount, msg.sender),
            "Error: Insufficient amount sent"
        );

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
        require(
            totalSupply(TOKEN_ID) + supply <= _maxSupply,
            "Error: Presale supply exceeds max supply"
        );
        require(price > 0, "Error: Presale price must be greater than zero");
        require(
            startDate >= block.timestamp,
            "Error: Start date can not be set to past date"
        );
        require(startDate < endDate, "Error: Invalid presale dates");

        // Set presale parameters
        _presaleMaxSupply = supply;
        _presaleMintPrice = price; // $USD
        _presaleStartDate = startDate;
        _presaleEndDate = endDate;

        // Emit event for presale creation
        emit PresaleCreated(supply, price, startDate, endDate);
    }

    /**
     *
     * Function for the owner to release and withdraw funds to the admin
     */
    function releaseFunds() public onlyOwner {
        // Calculate admin shares
        uint256 adminShare = (address(this).balance * _adminEarning) / 100;

        // Record earnings
        earnings[_admin] += adminShare;

        // Transfer funds to admin
        payable(_admin).transfer(adminShare);
    }

    /**
     * Function that calculates required mint amount to mint NFT pass
     * @ amount is number of NFTs
     * @ account is wallet address
     */
    function requiredMintAmount(
        uint256 amount,
        address account
    ) public view virtual returns (uint256) {
        uint256 mintPrice = getMintPrice();
        uint256 discountedPrice = mintPrice - _allowListPrice;
        uint256 reqAmount;

        if (reservedNFTPasses[account] > 0 && amount > 0) {
            uint256 reservedPasses = min(amount, reservedNFTPasses[account]);
            uint256 regularPasses = amount - reservedPasses;

            reqAmount =
                discountedPrice *
                reservedPasses +
                mintPrice *
                regularPasses;
        } else {
            reqAmount = mintPrice * amount;
        }

        return dollarToWei(reqAmount);
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
    function maxAvailableSupply(
        address account,
        uint256 supply
    ) internal view returns (uint256) {
        uint256 totalReservedSupply = _totalReservedSupply;
        uint256 userReserved = reservedNFTPasses[account];
        // reservations are void after 7 days of pre-sale
        if (!isFirstPresaleWindow()) {
            totalReservedSupply = 0;
            userReserved = 0;
        }
        uint256 _maxAavailable = supply - totalReservedSupply;
        uint256 _availableForUser = _maxAavailable + userReserved;
        return _availableForUser;
    }

    /**
     *
     * Function to check if presale is active
     */
    function isPresaleActive() public view virtual returns (bool) {
        return
            block.timestamp >= _presaleStartDate &&
            block.timestamp <= _presaleEndDate;
    }

    /**
     * returns true during first pre-sale window (default: 7 days)
     */
    function isFirstPresaleWindow() public view virtual returns (bool) {
        return (isPresaleActive() &&
            allowListExits() &&
            block.timestamp >= _presaleStartDate &&
            block.timestamp <= (_presaleStartDate + _firstPresaleWindow));
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
     *
     * Get admin share
     */
    function getAdminShare() public view virtual returns (uint256) {
        return _adminEarning;
    }

    /**
     *
     * Get admin earnings
     */
    function getEarnings(
        address account
    ) public view virtual returns (uint256) {
        return earnings[account];
    }

    /**
     *
     * Get current mint price based on presale status
     */
    function getMintPrice() public view virtual returns (uint256) {
        uint256 price = isPresaleActive() ? _presaleMintPrice : _mintPrice;
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
    function getUserMintLimit(
        address user,
        uint256 id
    ) public view virtual returns (uint256) {
        return _userMintLimit - balanceOf(user, id);
    }

    /**
     *
     * FTSO Integration
     */
    function getTokenPriceWei()
        public
        view
        returns (uint256 _price, uint64 _timestamp)
    {
        (_price, _timestamp) = ftsoV2.getFeedByIdInWei(FEED_ID);
    }

    /**
     * Convert wei to dollar
     */
    function weiToDollar(
        uint256 _amount
    ) public view returns (uint256 _price) {
        uint64 _timestamp;
        (_price, _timestamp) = getTokenPriceWei();
        return uint256(_price * _amount);
    }

    /**
     * Convert dollar to wei
     */
    function dollarToWei(
        uint256 _amount
    ) public view returns (uint256 _price) {
        uint64 _timestamp;
        (_price, _timestamp) = getTokenPriceWei();
        return uint256(_amount / _price);
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
        require(
            !isPresaleActive(),
            "Error: No Allow list when pre-sale is active"
        );
        require(
            totalSupply(TOKEN_ID) + limit <= _maxSupply,
            "Error: Allow list supply exceeds max supply"
        );
        require(price > 0, "Error: Price must be greater than zero");
        require(
            startDate >= block.timestamp,
            "Error: Start date can not be set to past date"
        );
        require(startDate < endDate, "Error: Invalid dates");

        // Set presale parameters
        _allowListMaxLimit = limit;
        _allowListPrice = price; // $USD
        _allowListStartDate = startDate;
        _allowListEndDate = endDate;
        _allowListExists = true;

        // Emit event for allow list creation
        emit AllowListCreated(limit, price, startDate, endDate);
    }

    /**
     *
     * set first presale window (default is 7 days)
     */
    function setFirstPresaleWindow(
        uint256 firstPresaleWindow
    ) public onlyOwner {
        require(
            firstPresaleWindow > 0 && firstPresaleWindow <= _presaleEndDate,
            "Error: Invalid first pre-sale window"
        );
        _firstPresaleWindow = firstPresaleWindow;
    }

    /**
     *
     * Function for the users to subscribe to an allow list
     */
    function subscribeAllowList(uint256 amount) public payable {
        uint256 userLimit = _userMintLimit - reservedNFTPasses[msg.sender];
        require(
            allowListExits() && isAllowListActive(),
            "Error: No allow list exists"
        );
        require(
            !isPresaleActive(),
            "Error: Cannot subscribe when pre-sale is live"
        );
        require(amount > 0, "Error: Subscribe to at least 1 NFT pass");
        require(
            amount <= (_allowListMaxLimit - _totalReservedSupply),
            "Error: Exceeds maximum allowed list limit"
        );
        require(amount <= userLimit, "Error: Exceeds per-user limit");
        require(
            msg.value >= dollarToWei(_allowListPrice * amount),
            "Error: Insufficient amount sent"
        );

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
    function adjustReservations(uint256 amount, address sender) internal {
        uint256 reservedPasses = min(amount, reservedNFTPasses[sender]);
        reservedNFTPasses[sender] -= reservedPasses;
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
        return
            block.timestamp >= _allowListStartDate &&
            block.timestamp <= _allowListEndDate;
    }

    /**
     * Returns supply of total reserved NFT passes
     */
    function getTotalReservedPasses() public view virtual returns (uint256) {
        return
            (isPresaleCreated() &&
                block.timestamp > (_presaleStartDate + _firstPresaleWindow))
                ? 0
                : _totalReservedSupply;
    }

    /**
     * Returns user reserved NFT passes
     */
    function getUserReservedPasses(
        address account
    ) public view virtual returns (uint256) {
        return
            (isPresaleCreated() &&
                block.timestamp > (_presaleStartDate + _firstPresaleWindow))
                ? 0
                : reservedNFTPasses[account];
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
     * Return first presale window (exclusive for allow listed users)
     */
    function getFirstPresaleWindow() public view virtual returns (uint256) {
        return _firstPresaleWindow;
    }

    /**
     *
     * Function to close allow list window
     */
    function closeAllowList() public onlyOwner {
        _allowListEndDate = block.timestamp;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     *
     * The following functions are overrides required by Solidity.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    )
        internal
        override(
            ERC1155Upgradeable,
            ERC1155PausableUpgradeable,
            ERC1155SupplyUpgradeable
        )
    {
        super._update(from, to, ids, values);
    }
}
