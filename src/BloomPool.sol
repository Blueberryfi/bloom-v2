// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FixedPointMathLib as Math} from "@solady/utils/FixedPointMathLib.sol";
import {AggregatorV3Interface} from "@chainlink/shared/interfaces/AggregatorV3Interface.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {Orderbook} from "@bloom-v2/Orderbook.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";

/**
 * @title BloomPool
 * @notice RWA pool contract facilitating the creation of Term Bound Yield Tokens through lending underlying tokens
 *         to market markers for 6 month terms.
 */
contract BloomPool is IBloomPool, Orderbook {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice The last TBY id that was minted.
    uint256 private _lastMintedId;

    /// @notice Price feed for the RWA token.
    address private _rwaPriceFeed;

    /// @notice Decimals for the RWA price feed.
    uint8 private _rwaPriceFeedDecimals;

    /// @notice A mapping of the TBY id to the collateral that is backed by the tokens.
    mapping(uint256 => TbyCollateral) private _idToCollateral;

    /// @notice Mapping of TBY ids to the maturity range.
    mapping(uint256 => TbyMaturity) private _idToMaturity;

    /// @notice Mapping of TBY ids to the RWA pricing ranges.
    mapping(uint256 => RwaPrice) private _tbyIdToRwaPrice;

    /// @notice Mapping of borrowers to their token shares for each TBY id.
    mapping(address => mapping(uint256 => uint256)) private _borrowerAmounts;

    /// @notice A mapping of the TBY id to the total amount of funds contributed by borrowers.
    mapping(uint256 => uint256) private _idToTotalBorrowed;

    /// @notice Mapping of TBY ids to overall lender's return amount.
    mapping(uint256 => uint256) private _tbyLenderReturns;

    /// @notice Mapping of TBY ids to the borower's return amount.
    mapping(uint256 => uint256) private _tbyBorrowerReturns;

    /// @notice A mapping of TBY id if the TBY is eligible for redemption.
    mapping(uint256 => bool) private _isTbyRedeemable;

    /*///////////////////////////////////////////////////////////////
                            Modifiers   
    //////////////////////////////////////////////////////////////*/

    modifier isRedeemable(uint256 id) {
        require(_isTbyRedeemable[id], Errors.TBYNotRedeemable());
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(
        address asset_,
        address rwa_,
        address rwaPriceFeed_,
        uint256 initLeverage,
        uint256 spread,
        address owner_
    ) Orderbook(asset_, rwa_, initLeverage, spread, owner_) {
        require(owner_ != address(0), Errors.ZeroAddress());
        _setPriceFeed(rwaPriceFeed_);
    }

    /*///////////////////////////////////////////////////////////////
                                Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBloomPool
    function redeemLender(uint256 id, uint256 amount) external override isRedeemable(id) returns (uint256 reward) {
        require(_tby.balanceOf(msg.sender, id) >= amount, Errors.InsufficientBalance());
        uint256 totalSupply = _tby.totalSupply(id);

        reward = _tbyLenderReturns[id].mulWad(amount).divWadUp(totalSupply);
        require(reward > 0, Errors.ZeroRewards());

        _tbyLenderReturns[id] -= reward;
        _tby.burn(id, msg.sender, amount);

        IERC20(_asset).safeTransfer(msg.sender, reward);
        emit LenderRedeemed(msg.sender, id, reward);
    }

    /// @inheritdoc IBloomPool
    function redeemBorrower(uint256 id) external override isRedeemable(id) returns (uint256 reward) {
        uint256 borrowerReturns = _tbyBorrowerReturns[id];
        uint256 totalBorrowed = _idToTotalBorrowed[id];
        uint256 borrowAmount = _borrowerAmounts[msg.sender][id];

        reward = borrowerReturns.mulWad(borrowAmount).divWadUp(totalBorrowed);
        require(reward > 0, Errors.ZeroRewards());

        _tbyBorrowerReturns[id] -= reward;
        _borrowerAmounts[msg.sender][id] -= borrowAmount;

        IERC20(_asset).safeTransfer(msg.sender, reward);
        emit BorrowerRedeemed(msg.sender, id, reward);
    }

    /**
     * @notice Swaps in assets for rwa tokens, starting the TBY minting process.
     * @dev Only market makers can call this function.
     * @dev From the first swap for a given TBY id, the market maker has 48 hours to fill orders that
     *      will be included in the batch. All TBYs will mature after 180 days.
     * @param accounts An Array of addresses to convert from matched orders to live TBYs.
     * @param assetAmount The amount of assets that will be swapped in for rwa tokens.
     * @return id The id of the TBY that was minted.
     * @return amountSwapped The amount of assets swapped in.
     */
    function swapIn(address[] memory accounts, uint256 assetAmount)
        external
        KycMarketMaker
        returns (uint256 id, uint256 amountSwapped)
    {
        // Get the TBY id to mint
        id = _lastMintedId;
        TbyMaturity memory maturity = _idToMaturity[id];

        if (block.timestamp > maturity.start + 48 hours) {
            id = _lastMintedId++;
            uint128 start = uint128(block.timestamp);
            uint128 end = start + 180 days;
            _idToMaturity[id] = TbyMaturity(start, end);
        }

        // Iterate through the accounts and convert the matched orders to live TBYs.
        uint256 len = accounts.length;
        for (uint256 i = 0; i != len; ++i) {
            uint256 amountUsed = _convertMatchOrders(id, accounts[i], assetAmount);
            assetAmount -= amountUsed;
            amountSwapped += amountUsed;
            if (assetAmount == 0) break;
            _tby.mint(id, accounts[i], amountSwapped);
        }

        // Initialize the starting price of the RWA token if it has not been set
        RwaPrice memory rwaPrice = _tbyIdToRwaPrice[id];
        uint256 currentPrice = _rwaPrice();

        if (rwaPrice.startPrice == 0) {
            _tbyIdToRwaPrice[id].startPrice = uint128(currentPrice);
        }

        uint256 rwaAmount = (currentPrice * amountSwapped) / Math.WAD;
        _idToCollateral[id] = TbyCollateral(0, uint128(rwaAmount));

        IERC20(_rwa).safeTransferFrom(msg.sender, address(this), rwaAmount);
        IERC20(_asset).safeTransfer(msg.sender, amountSwapped);

        emit MarketMakerSwappedIn(id, msg.sender, rwaAmount);
    }

    /**
     * @notice Swaps asset tokens in and rwa tokens out, ending the TBY life cycle.
     * @dev Only market makers can call this function.
     * @dev Can only be called after the TBY has matured.
     * @param id The id of the TBY that the swap is for.
     * @param rwaAmount The amount of rwa tokens to remove.
     * @return assetAmount The amount of assets swapped out.
     */
    function swapOut(uint256 id, uint256 rwaAmount) external KycMarketMaker returns (uint256 assetAmount) {
        require(rwaAmount > 0, Errors.ZeroAmount());
        require(IERC20(_rwa).balanceOf(msg.sender) >= rwaAmount, Errors.InsufficientBalance());
        require(_idToMaturity[id].end <= block.timestamp, Errors.TBYNotMatured());

        RwaPrice memory rwaPrice = _tbyIdToRwaPrice[id];
        TbyCollateral storage collateral = _idToCollateral[id];
        uint256 currentPrice = _rwaPrice();

        if (rwaPrice.endPrice == 0) {
            _tbyIdToRwaPrice[id].endPrice = uint128(currentPrice);
        }

        uint256 tbyAmount = uint256(rwaPrice.startPrice).mulWad(rwaAmount);
        assetAmount = (rwaAmount * (10 ** _assetDecimals)) / currentPrice;

        uint256 lenderReturn = (getRate(id) * tbyAmount) / (10 ** (18 - _assetDecimals));
        uint256 borrowerReturn = tbyAmount - lenderReturn;

        _tbyBorrowerReturns[id] += borrowerReturn;
        _tbyLenderReturns[id] += lenderReturn;

        collateral.rwaAmount -= uint128(rwaAmount);
        collateral.assetAmount += uint128(assetAmount);

        if (collateral.rwaAmount == 0) {
            _isTbyRedeemable[id] = true;
        }

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), assetAmount);
        IERC20(_rwa).safeTransfer(msg.sender, rwaAmount);

        emit MarketMakerSwappedOut(id, msg.sender, rwaAmount);
    }

    /**
     * @notice Sets the price feed for the RWA token.
     * @dev Only the owner can call this function.
     * @param rwaPriceFeed_ The address of the price feed for the RWA token.
     */
    function setPriceFeed(address rwaPriceFeed_) public onlyOwner {
        _setPriceFeed(rwaPriceFeed_);
    }

    /// @inheritdoc IBloomPool
    function getRate(uint256 id) public view override returns (uint256) {
        TbyMaturity memory maturity = _idToMaturity[id];
        RwaPrice memory rwaPrice = _tbyIdToRwaPrice[id];

        uint256 time = block.timestamp;
        // If the TBY has not started accruing interest, return 1e18.
        if (time <= maturity.start) {
            return Math.WAD;
        }

        // If the TBY has matured, and is eligible for redemption, calculate price based on the end price.
        if (time >= maturity.end && rwaPrice.endPrice != 0) {
            return Math.WAD + (rwaPrice.endPrice * _spread) / rwaPrice.startPrice;
        }

        // If the TBY has matured, and is not-eligible for redemption due to market maker delay,
        //     calculate price based on the current price of the RWA token via the price feed.
        return Math.WAD + (_rwaPrice() * _spread) / rwaPrice.startPrice;
    }

    /// @inheritdoc IBloomPool
    function rwaPriceFeed() external view returns (address) {
        return _rwaPriceFeed;
    }

    /// @notice Returns the current price of the RWA token.
    function _rwaPrice() public view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(_rwaPriceFeed).latestRoundData();
        require(updatedAt >= block.timestamp - 1 days, Errors.OutOfDate());
        uint256 scaler = 10 ** (18 - _rwaPriceFeedDecimals);

        return uint256(answer) * scaler;
    }

    /**
     * @notice Converts matched orders to live TBYs.
     * @param id The id of the TBY that the swap is for.
     * @param account The address of the lender who's order is being converted.
     * @param amount The amount of assets available to swap.
     * @return amountUsed The amount of assets that were used (both borrower funds & lender funds)
     *                    to convert matched orders to live TBYs.
     */
    function _convertMatchOrders(uint256 id, address account, uint256 amount) internal returns (uint256 amountUsed) {
        MatchOrder[] storage matches = _userMatchedOrders[account];
        uint256 remainingAmount = amount;
        uint256 borrowerAmountConverted = 0;

        uint256 length = matches.length;
        for (uint256 i = length; i != 0; --i) {
            uint256 index = i - 1;

            if (remainingAmount != 0) {
                uint256 amountToRemove = Math.min(remainingAmount, matches[index].amount);
                remainingAmount -= amountToRemove;

                uint256 borrowerAmount = amountToRemove.divWadUp(matches[index].leverage);
                _borrowerAmounts[account][id] += borrowerAmount;
                borrowerAmountConverted += borrowerAmount;

                if (amountToRemove == matches[index].amount) {
                    matches.pop();
                } else {
                    matches[index].amount -= amountToRemove;
                }
            } else {
                break;
            }
        }
        _idToTotalBorrowed[id] += borrowerAmountConverted;
        uint256 totalRemoved = amount - remainingAmount;
        _matchedDepth -= totalRemoved;
        amountUsed = totalRemoved + borrowerAmountConverted;
    }

    /// @notice Logic to set the price feed for the RWA token.
    function _setPriceFeed(address rwaPriceFeed_) internal {
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(rwaPriceFeed_).latestRoundData();
        require(answer > 0, Errors.InvalidPriceFeed());
        require(updatedAt >= block.timestamp - 1 days, Errors.OutOfDate());

        _rwaPriceFeed = rwaPriceFeed_;
        _rwaPriceFeedDecimals = AggregatorV3Interface(rwaPriceFeed_).decimals();
    }
}
