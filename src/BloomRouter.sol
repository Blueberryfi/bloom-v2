// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.27;

import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@solady/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {Tby} from "@bloom-v2/token/Tby.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";
import {IBloomRouter} from "@bloom-v2/interfaces/IBloomRouter.sol";

/**
 * @title BloomRouter
 * @dev The BloomRouter is the entry point for all interactions with the Bloom Protocol and will route the user to the correct BloomPool.
 * @notice An RFQ protocol for permissionlessly being able to access RWA yield by connecting lenders to compliant borrowers.
 */
contract BloomRouter is IBloomRouter, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using FpMath for uint256;

    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Current total depth of unfilled orders.
    uint256 private _openDepth;

    /// @notice The last TBY id that was minted.
    uint256 private _lastMintedId;

    /// @notice The minimum size of an order.
    uint256 private _minOrderSize;

    /// @notice Mapping of users to their open order amount.
    mapping(address => uint256) private _userOpenOrder;

    /// @notice Mapping of Bloom Pool addresses to whether they are active.
    mapping(address => bool) private _bloomPools;

    /// @notice Mapping of TBY ids to their corresponding Bloom Pool.
    mapping(uint256 => address) private _idToPool;

    /*///////////////////////////////////////////////////////////////
                        Constants & Immutables
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the underlying asset of the Pool.
    address private immutable _asset;

    /// @notice Decimals of the underlying asset of the Pool.
    uint8 private immutable _assetDecimals;

    /*///////////////////////////////////////////////////////////////
                            Modifiers    
    //////////////////////////////////////////////////////////////*/

    modifier validPool(address pool) {
        if (!_bloomPools[pool]) revert Errors.InvalidPool();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(address asset_, uint256 minOrderSize_, address owner_) Ownable(owner_) {
        _asset = asset_;
        _minOrderSize = minOrderSize_;

        uint8 decimals = IERC20Metadata(asset_).decimals();

        _assetDecimals = decimals;
        _lastMintedId = type(uint256).max;
    }

    /*///////////////////////////////////////////////////////////////
                            Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBloomRouter
    function lendOrder(uint256 amount) external override {
        _amountZeroCheck(amount);
        _minOrderSizeCheck(amount);
        _openOrder(msg.sender, amount);
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IBloomRouter
    function borrow(address[] memory lenders, address pool, uint256 amount)
        external
        payable
        override
        validPool(pool)
        nonReentrant
        returns (uint256 tbyId, uint256 lCollateral, uint256 bCollateral)
    {
        uint256 bloomsLastMintedId = _lastMintedId;
        tbyId = IBloomPool(pool).calculateTbyId(bloomsLastMintedId);

        if (tbyId > bloomsLastMintedId || bloomsLastMintedId == type(uint256).max) {
            _idToPool[tbyId] = pool;
            _lastMintedId = tbyId;
        }

        uint256 len = lenders.length;
        uint256[] memory amounts = new uint256[](len);

        for (uint256 i = 0; i != len; ++i) {
            amounts[i] = _fillOrder(lenders[i], amount);
            if (amounts[i] == 0) break;
            lCollateral += amounts[i];
        }

        IERC20(_asset).forceApprove(pool, lCollateral);
        bCollateral = IBloomPool(pool).borrow(
            tbyId, 
            msg.sender, 
            lCollateral,
            lenders,
            amounts
        );
        emit Borrowed(msg.sender, tbyId, lCollateral, bCollateral);
    }

    /// @inheritdoc IBloomRouter
    function repay(uint256 tbyId) external override nonReentrant {
        address pool = _idToPool[tbyId];
        require(pool != address(0), Errors.InvalidTby());
        (uint256 rwaAmount, uint256 assetAmount, uint256 endRwaCollateral, uint256 endAssetCollateral) =
            IBloomPool(pool).repay(tbyId);
        emit Repaid(tbyId, msg.sender, rwaAmount, assetAmount, endRwaCollateral, endAssetCollateral);
    }

    /// @inheritdoc IBloomRouter
    function redeemLender(uint256 tbyId, uint256 amount) external override returns (uint256 reward) {
        reward = IBloomPool(_idToPool[tbyId]).withdrawLender(tbyId, msg.sender, amount);
        emit LenderRedeemed(msg.sender, tbyId, reward);
    }

    /// @inheritdoc IBloomRouter
    function redeemBorrower(uint256 tbyId) external override returns (uint256 reward) {
        reward = IBloomPool(_idToPool[tbyId]).withdrawBorrower(tbyId, msg.sender);
        emit BorrowerRedeemed(msg.sender, tbyId, reward);
    }

    /// @inheritdoc IBloomRouter
    function killOpenOrder(uint256 amount) external override {
        uint256 orderDepth = _userOpenOrder[msg.sender];
        _amountZeroCheck(amount);
        require(amount <= orderDepth, Errors.InsufficientDepth());

        _userOpenOrder[msg.sender] -= amount;
        _openDepth -= amount;

        emit OpenOrderKilled(msg.sender, amount);
        IERC20(_asset).safeTransfer(msg.sender, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            Admin Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a bloom pool to the router.
     * @param pool The address of the bloom pool to add.
     */
    function addPool(address pool) external onlyOwner {
        _bloomPools[pool] = true;
    }

    /**
     * @notice Pauses a bloom pool.
     * @dev Pausing a bloom pool prevents new borrows from being created, but does not affect the ability to repay existing borrows.
     * @param pool The address of the bloom pool to pause.
     */
    function pausePool(address pool) external onlyOwner {
        _bloomPools[pool] = false;
    }

    /**
     * @notice Sets the minimum order size.
     * @param minOrderSize_ The new minimum order size.
     */
    function setMinOrderSize(uint256 minOrderSize_) external onlyOwner {
        _minOrderSize = minOrderSize_;
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fills an order with a specified amount of underlying assets
     * @param account The address of the order to fill
     * @param amount Amount of underlying assets of the order to fill
     */
    function _fillOrder(address account, uint256 amount) internal returns (uint256 lCollateral) {
        require(account != address(0), Errors.ZeroAddress());
        if (amount == 0) return 0;

        uint256 orderDepth = _userOpenOrder[account];

        lCollateral = FpMath.min(orderDepth, amount);
        _openDepth -= lCollateral;
        orderDepth -= lCollateral;

        if (orderDepth != 0) {
            // Make sure that lCollateral is
            _minOrderSizeCheck(orderDepth);
        }

        _userOpenOrder[account] = orderDepth;
        emit OrderFilled(account, msg.sender, lCollateral);
    }

    /**
     * @notice Opens an order for the lender
     * @param lender The address of the lender
     * @param amount The amount of underlying assets to open the order
     */
    function _openOrder(address lender, uint256 amount) internal {
        _openDepth += amount;
        _userOpenOrder[lender] += amount;
        emit OrderCreated(lender, amount);
    }

    /**
     * @notice Checks if the amount is greater than zero
     * @param amount The amount of underlying assets to close the matched order
     */
    function _amountZeroCheck(uint256 amount) internal pure {
        require(amount > 0, Errors.ZeroAmount());
    }

    /**
     * @notice Checks if an amount is greater than the minimum order size
     * @param amount The amount of underlying assets to check
     */
    function _minOrderSizeCheck(uint256 amount) internal view {
        require(amount >= _minOrderSize, Errors.OrderBelowMinSize());
    }

    /*///////////////////////////////////////////////////////////////
                            View Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBloomRouter
    function asset() external view override returns (address) {
        return _asset;
    }

    /// @inheritdoc IBloomRouter
    function assetDecimals() external view override returns (uint8) {
        return _assetDecimals;
    }

    /// @inheritdoc IBloomRouter
    function openDepth() external view override returns (uint256) {
        return _openDepth;
    }

    /// @inheritdoc IBloomRouter
    function amountOpen(address account) external view override returns (uint256) {
        return _userOpenOrder[account];
    }

    /// @inheritdoc IBloomRouter
    function minOrderSize() external view override returns (uint256) {
        return _minOrderSize;
    }

    /// @inheritdoc IBloomRouter
    function lastMintedId() external view override returns (uint256) {
        return _lastMintedId;
    }

    /// @inheritdoc IBloomRouter
    function isPool(address pool) external view override returns (bool) {
        return _bloomPools[pool];
    }

    /// @inheritdoc IBloomRouter
    function poolFromTbyId(uint256 id) external view override returns (address) {
        return _idToPool[id];
    }

    /*///////////////////////////////////////////////////////////////
                            General Functions    
    //////////////////////////////////////////////////////////////*/

    /// @notice Ability to receive Native currency payments
    receive() external payable {}
}
