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
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
// to get data feed for Flare/Coston/Coston2/Songbird
// for testing
// import "@flarenetwork/flare-periphery-contracts/coston2/ContractRegistry.sol";
// import "@flarenetwork/flare-periphery-contracts/coston2/TestFtsoV2Interface.sol";
import "@flarenetwork/flare-periphery-contracts/flare/ContractRegistry.sol";
import "@flarenetwork/flare-periphery-contracts/flare/FtsoV2Interface.sol";

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
    IERC1155 internal oldContract;
    //
    /**
     * Constant for token ID
     * @notice A new contract per course NFT passes
     * Hence token ID is fixed to '0'
     */
    uint256 public constant TOKEN_ID = 1;
    string private constant TOKEN_SYMBOL = "SGB"; // for FTSO
    bytes21 private constant FEED_ID = bytes21(0x01464c522f55534400000000000000000000000000); // FLR/USD

    // State variables for contract parameters
    uint256 private _maxSupply;
    uint256 private _remainingSupply;
    address private _admin;
    uint256 private _adminEarning;
    uint256 private _mintPrice;
    // Pre-sale state variable
    uint256 private _presaleMintPrice;
    uint256 private _presaleStartDate;
    uint256 private _presaleEndDate;
    bool private _presaleCreated;

    uint256 private _group1ReservedSupply;  // Reserved supply for Group 1
    uint256 private _group1Minted;  // Track how much Group 1 has minted
    uint256 private _group2Supply;  // Supply for Group 2
    uint256 private _group2Minted;  // Track how much Group 2 has minted

    uint256 private _userMintLimit;
    address private constant FLARE_CONTRACT_REGISTRY =
        0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019;

    address private constant PREVIOUS_CONTRACT_ADDRESS = 0xF173c2111F700D485ED7e88CcC488DFF41a9D829;

    mapping(address => uint256) private earnings;

    // Event for presale creation
    event PresaleCreated(
        uint256 price,
        uint256 startDate,
        uint256 endDate
    );

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
        uint256 adminEarning,
        string memory uri,
        uint256 maxSupply,
        uint256 mintPrice,
        uint256 userMintLimit,
        uint256 group1ReservedSupply
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
        _remainingSupply = maxSupply;
        _mintPrice = mintPrice; // $USD
        _admin = owner;
        _adminEarning = adminEarning;
        _userMintLimit = userMintLimit;
        _presaleCreated = false;
        ftsoV2 = ContractRegistry.getTestFtsoV2();
        oldContract = IERC1155(PREVIOUS_CONTRACT_ADDRESS);
        _group1ReservedSupply = group1ReservedSupply;
        require(_group1ReservedSupply <= maxSupply, "Error: Invalid reserved supply");
        _group2Supply = maxSupply - group1ReservedSupply;
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
        require(
            _remainingSupply >= amount,
            "Error: Exceeds maximum supply"
        );
        require(
            amount <= getUserMintLimit(msg.sender, TOKEN_ID),
            "Error: Exceeds per-user limit"
        );
        require(
            msg.value >= requiredMintAmount(amount),
            "Error: Insufficient amount sent"
        );
        if (isPresaleActive()) {
            if (oldContract.balanceOf(msg.sender, TOKEN_ID) > 0) {
                _group1Minted += amount;
            } else {
                require(_group2Minted + amount <= _group2Supply, "Error: Exceeds available supply for Group 2 during presale");
                _group2Minted += amount;
            }
        }
        
        // Mint NFTs, transfer earnings, and update user's pass count
        _mint(msg.sender, TOKEN_ID, amount, "");
        _remainingSupply -= amount;
    }

    /**
     * @dev Function that allows the owner to mint the remaining supply of NFTs 
     * and immediately burn them. Can only be called by the owner.
     */
    function mintAndBurnRemainingSupply() external onlyOwner {
        uint256 remainingSupply = _maxSupply - totalSupply(TOKEN_ID);
        require(remainingSupply > 0, "Error: No remaining supply to mint and burn");

        // Mint remaining supply to the owner's address
        _mint(msg.sender, TOKEN_ID, remainingSupply, "");

        // Burn the minted tokens immediately
        _burn(msg.sender, TOKEN_ID, remainingSupply);

        _remainingSupply = 0;
    }

    function getRemainingSupply() public view returns (uint256) {
        return _remainingSupply;
    }

    /**
     *
     * Function for the owner to create a presale
     * It can be be called only once
     */
    function createPresale(
        uint256 price,
        uint256 startDate,
        uint256 endDate
    ) public onlyOwner onlyOnce {
        require(price > 0, "Error: Presale price must be greater than zero");
        require(
            startDate >= block.timestamp,
            "Error: Start date can not be set to past date"
        );
        require(startDate < endDate, "Error: Invalid presale dates");

        // Set presale parameters
        _presaleMintPrice = price; // $USD
        _presaleStartDate = startDate;
        _presaleEndDate = endDate;

        // Emit event for presale creation
        emit PresaleCreated(price, startDate, endDate);
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
     */
    function requiredMintAmount(
        uint256 amount
    ) public view virtual returns (uint256) {
        uint256 mintPrice = getMintPrice();
        uint256 reqAmount = mintPrice * amount;

        return dollarToWei(reqAmount);
    }

    /**
     * Helper function to get the minimum of two numbers
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
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
        returns (uint256 _price, int8 _decimals, uint64 _timestamp)
    {
        (_price, _decimals, _timestamp) = ftsoV2.getFeedById(FEED_ID);
    }

    /**
     * Convert wei to dollar
     */
    function weiToDollar(
        uint256 _amount
    ) public view returns (uint256 _price) {
        uint64 _timestamp;
        int8 _decimals; // int8 since the getFeedById function uses int8 for decimals
        (_price, _decimals, _timestamp) = getTokenPriceWei();
        // Ensure _decimals is positive before casting to uint256
        require(_decimals >= 0, "Decimals must be non-negative");

        // Convert _decimals to uint256 for safe arithmetic
        uint256 decimals = uint256(int256(_decimals));

        // Adjusting for the decimal places returned by getFeedById
        return uint256((_price * _amount) / (10 ** (18 + decimals)));
    }

    /**
     * Convert dollar to wei
     */
    function dollarToWei(
        uint256 _amount
    ) public view returns (uint256 _price) {
        uint256 _timestamp;
        int8 _decimals; // int8 since the getFeedById function uses int8 for decimals
        (_price, _decimals, _timestamp) = getTokenPriceWei();
        // Ensure _decimals is positive before casting to uint256
        require(_decimals >= 0, "Decimals must be non-negative");

        // Convert _decimals to uint256 for safe arithmetic
        uint256 decimals = uint256(int256(_decimals));

        // Adjusting for the decimal places returned by getFeedById
        return uint256((_amount * (10 ** (18 + decimals))) / _price);
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
