// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/shared/interfaces/AggregatorV3Interface.sol";
import {FixedPointMathLib as Math} from "@solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "@solady/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {Orderbook} from "@bloom-v2/Orderbook.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";

/**
 * @title BloomPool
 * @notice RWA pool contract facilitating the creation of Term Bound Yield Tokens through lending underlying tokens
 *         to market markers for 6 month terms.
 */
contract BloomPool is IBloomPool, Orderbook, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice The last TBY id that was minted.
    uint256 private _lastMintedId;

    /// @notice The length of time that future minted TBY Id will mature for. Default is 180 days.
    uint256 private _futureMaturity;

    /// @notice The price feed for the RWA token.
    RwaPriceFeed private _rwaPriceFeed;

    /// @notice A mapping of the TBY id to the collateral that is backed by the tokens.
    mapping(uint256 => TbyCollateral) private _idToCollateral;

    /// @notice Mapping of TBY ids to the maturity range.
    mapping(uint256 => TbyMaturity) private _idToMaturity;

    /// @notice Mapping of TBY ids to the RWA pricing ranges.
    mapping(uint256 => RwaPrice) private _tbyIdToRwaPrice;

    /// @notice Mapping of borrowers to their token amounts for each TBY id.
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
                        Constants & Immutables
    //////////////////////////////////////////////////////////////*/

    /// @notice The buffer time between the first minted token of a given TBY id
    ///         and the last possible swap in for that tokenId.
    uint256 constant SWAP_BUFFER = 48 hours;

    /// @notice The default length of time that TBYs mature.
    uint256 constant DEFAULT_MATURITY = 180 days;

    /// @notice The minimum percentage of RWA tokens that must be swapped out in a single `swapOut` call. (0.25% of total RWA collateral for the TBY)
    uint256 constant MIN_SWAP_OUT_PERCENT = 0.0025e18;

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
        uint64 priceFeedUpdateInterval_,
        uint256 initLeverage,
        uint256 spread,
        address owner_
    ) Orderbook(asset_, rwa_, initLeverage, spread, owner_) {
        require(owner_ != address(0), Errors.ZeroAddress());
        _setPriceFeed(rwaPriceFeed_, priceFeedUpdateInterval_);
        _lastMintedId = type(uint256).max;
        _futureMaturity = DEFAULT_MATURITY;
    }

    /*///////////////////////////////////////////////////////////////
                                Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBloomPool
    function redeemLender(uint256 id, uint256 amount) external override isRedeemable(id) returns (uint256 reward) {
        require(_tby.balanceOf(msg.sender, id) >= amount, Errors.InsufficientBalance());

        uint256 totalSupply = _tby.totalSupply(id);
        reward = (_tbyLenderReturns[id] * amount) / totalSupply;
        require(reward > 0, Errors.ZeroRewards());

        _idToCollateral[id].assetAmount -= uint128(reward);
        _tbyLenderReturns[id] -= reward;
        _tby.burn(id, msg.sender, amount);

        emit LenderRedeemed(msg.sender, id, reward);
        IERC20(_asset).safeTransfer(msg.sender, reward);
    }

    /// @inheritdoc IBloomPool
    function redeemBorrower(uint256 id) external override isRedeemable(id) returns (uint256 reward) {
        uint256 totalBorrowAmount = _idToTotalBorrowed[id];
        uint256 borrowAmount = _borrowerAmounts[msg.sender][id];

        reward = (_tbyBorrowerReturns[id] * borrowAmount) / totalBorrowAmount;
        require(reward > 0, Errors.ZeroRewards());

        _idToCollateral[id].assetAmount -= uint128(reward);
        _tbyBorrowerReturns[id] -= reward;
        _borrowerAmounts[msg.sender][id] -= borrowAmount;

        emit BorrowerRedeemed(msg.sender, id, reward);
        IERC20(_asset).safeTransfer(msg.sender, reward);
    }

    /**
     * @notice Swaps in assets for rwa tokens, starting the TBY minting process.
     * @dev Only market makers can call this function.
     * @dev From the first swap for a given TBY id, the market maker has 48 hours to fill orders that
     *      will be included in the batch. All TBYs will mature after 180 days.
     * @param accounts An Array of addresses to convert from matched orders to live TBYs.
     * @param assetAmount The amount of assets that will be swapped out for rwa tokens.
     * @return id The id of the TBY that was minted.
     * @return amountSwapped The amount of assets swapped in.
     */
    function swapIn(address[] memory accounts, uint256 assetAmount)
        external
        KycMarketMaker
        nonReentrant
        returns (uint256 id, uint256 amountSwapped)
    {
        id = _handleTbyId();

        // Iterate through the accounts and convert the matched orders to live TBYs.
        uint256 len = accounts.length;
        for (uint256 i = 0; i != len; ++i) {
            uint256 amountUsed = _convertMatchOrders(id, accounts[i], assetAmount);
            assetAmount -= amountUsed;
            amountSwapped += amountUsed;
            if (assetAmount == 0) break;
        }

        TbyCollateral storage collateral = _idToCollateral[id];
        uint256 currentPrice = _rwaPrice();

        // Calculate the amount of RWA tokens needed to complete the swap.
        uint256 rwaAmount = (amountSwapped * _assetScalingFactor).divWadUp(currentPrice) / _rwaScalingFactor;
        require(rwaAmount > 0, Errors.ZeroAmount());

        // Initalize or normalize the starting price of the TBY.
        _setStartPrice(id, currentPrice, rwaAmount, collateral.rwaAmount);

        // Update the collateral for the TBY id.
        collateral.rwaAmount += uint128(rwaAmount);

        emit MarketMakerSwappedIn(id, msg.sender, rwaAmount, amountSwapped);

        IERC20(_rwa).safeTransferFrom(msg.sender, address(this), rwaAmount);
        IERC20(_asset).safeTransfer(msg.sender, amountSwapped);
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
        require(_idToMaturity[id].end <= block.timestamp, Errors.TBYNotMatured());

        RwaPrice storage rwaPrice = _tbyIdToRwaPrice[id];
        TbyCollateral storage collateral = _idToCollateral[id];
        uint256 currentPrice = _rwaPrice();

        // Cannot swap out more RWA tokens than is allocated for the TBY.
        rwaAmount = Math.min(rwaAmount, collateral.rwaAmount);
        uint256 totalRwaCollateral = collateral.rwaAmount;

        if (rwaPrice.endPrice == 0) {
            rwaPrice.endPrice = uint128(currentPrice);
        } else {
            totalRwaCollateral += uint256(collateral.assetAmount * _assetScalingFactor).divWad(rwaPrice.endPrice);
        }

        // Calculate the percentage of RWA tokens that are being currently swapped
        uint256 percentSwapped = rwaAmount.divWad(totalRwaCollateral);
        require(percentSwapped >= MIN_SWAP_OUT_PERCENT, Errors.SwapOutTooSmall());

        uint256 tbyTotalSupply = _tby.totalSupply(id);
        uint256 tbyAmount = percentSwapped != Math.WAD ? tbyTotalSupply.mulWadUp(percentSwapped) : tbyTotalSupply;
        require(tbyAmount > 0, Errors.ZeroAmount());

        // Calculate the amount of assets that will be swapped out.
        assetAmount = uint256(currentPrice).mulWadUp(rwaAmount) / (10 ** ((18 - _rwaDecimals) + (18 - _assetDecimals)));
        uint256 lenderReturn = getRate(id).mulWad(tbyAmount);

        // If the price has dropped between the end of the TBY's maturity date and when the market maker swap finishes,
        //     only the borrower's returns will be negatively impacted, unless the rate of the drop in price is so large,
        //     that the lender's returns are less than their implied rate. In this case, the rate will be adjusted to
        //     reflect the price of the new assets entering the pool. This adjustment is to ensure that lender returns always
        //     match up with the implied rate of the TBY.
        if (currentPrice < rwaPrice.endPrice) {
            if (lenderReturn > assetAmount) {
                lenderReturn = assetAmount;
                uint256 accumulatedCollateral = _tbyLenderReturns[id] + lenderReturn;
                uint256 remainingAmount = (collateral.rwaAmount - rwaAmount).mulWad(currentPrice) / _assetScalingFactor;
                uint256 totalCollateral = accumulatedCollateral + remainingAmount;
                uint256 newRate = totalCollateral.divWad(_tby.totalSupply(id));
                uint256 adjustedRate = _takeSpread(newRate);
                rwaPrice.endPrice = uint128(adjustedRate.mulWad(rwaPrice.startPrice));
            }
        }
        uint256 borrowerReturn = assetAmount - lenderReturn;

        // Adjust the borrower and lender returns.
        _tbyBorrowerReturns[id] += borrowerReturn;
        _tbyLenderReturns[id] += lenderReturn;

        // Update the collateral for the TBY id.
        collateral.rwaAmount -= uint128(rwaAmount);
        collateral.assetAmount += uint128(assetAmount);

        if (collateral.rwaAmount == 0) {
            _isTbyRedeemable[id] = true;
        }

        emit MarketMakerSwappedOut(id, msg.sender, rwaAmount, assetAmount);

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), assetAmount);
        IERC20(_rwa).safeTransfer(msg.sender, rwaAmount);
    }

    /**
     * @notice Sets the length of time that future TBY Ids will mature for.
     * @param maturity The length of time that future TBYs Id will mature for.
     */
    function setMaturity(uint256 maturity) external onlyOwner {
        _futureMaturity = maturity;
        emit TbyMaturitySet(maturity);
    }

    /**
     * @notice Sets the price feed for the RWA token.
     * @dev Only the owner can call this function.
     * @param rwaPriceFeed_ The address of the price feed for the RWA token.
     * @param priceFeedUpdateInterval_ The interval at which the price feed should be updated.
     */
    function setPriceFeed(address rwaPriceFeed_, uint64 priceFeedUpdateInterval_) external onlyOwner {
        _setPriceFeed(rwaPriceFeed_, priceFeedUpdateInterval_);
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the TBY id to mint based on the last minted TBY id and the swap buffer.
     * @dev If the last minted TBY id was created 48 hours ago or more, a new TBY id is minted.
     * @return id The id of the TBY to mint.
     */
    function _handleTbyId() private returns (uint256 id) {
        // Get the TBY id to mint
        id = _lastMintedId;
        TbyMaturity memory maturity = _idToMaturity[id];

        // If the timestamp of the last minted TBYs start is greater than 48 hours from now, this swap is for a new TBY Id.
        if (block.timestamp > maturity.start + SWAP_BUFFER) {
            // Last minted id is set to type(uint256).max, so we need to wrap around to 0 to start the first TBY.
            unchecked {
                id = ++_lastMintedId;
            }
            uint128 start = uint128(block.timestamp);
            uint128 end = start + uint128(_futureMaturity);
            _idToMaturity[id] = TbyMaturity(start, end);
        }
    }

    /**
     * @notice Initializes or normalizes the starting price of the TBY.
     * @dev If the TBY Id has already been minted before the start price will be normalized via a time weighted average.
     * @param id The id of the TBY to initialize the start price for.
     * @param currentPrice The current price of the RWA token.
     * @param rwaAmount The amount of rwaAssets that are being swapped in.
     * @param existingCollateral The amount of RWA collateral already in the pool, before the swap, for the TBY id.
     */
    function _setStartPrice(uint256 id, uint256 currentPrice, uint256 rwaAmount, uint256 existingCollateral) private {
        RwaPrice storage rwaPrice = _tbyIdToRwaPrice[id];
        uint256 startPrice = rwaPrice.startPrice;
        if (startPrice == 0) {
            rwaPrice.startPrice = uint128(currentPrice);
        } else if (startPrice != currentPrice) {
            rwaPrice.startPrice = uint128(_normalizePrice(startPrice, currentPrice, rwaAmount, existingCollateral));
        }
    }

    /**
     * @notice Normalizes the price of the RWA by taking the weighted average of the startPrice and the currentPrice
     * @dev This is done n the event that the market maker is doing multiple swaps for the same TBY Id,
     *      and the rwa price has changes. We need to recalculate the starting price of the TBY,
     *      to ensure accuracy in the TBY's rate of return.
     * @param startPrice The starting price of the RWA, before the swap.
     * @param currentPrice The Current price of the RWA token.
     * @param amount The amount of RWA tokens being swapped in.
     * @param existingCollateral The existing RWA collateral in the pool, before the swap, for the TBY id.
     */
    function _normalizePrice(uint256 startPrice, uint256 currentPrice, uint256 amount, uint256 existingCollateral)
        private
        view
        returns (uint128)
    {
        uint256 totalValue = (existingCollateral.mulWad(startPrice) + amount.mulWad(currentPrice)) / _rwaScalingFactor;
        uint256 totalCollateral = existingCollateral + amount;
        return uint128(totalValue.divWad(totalCollateral));
    }

    /// @notice Returns the current price of the RWA token.
    function _rwaPrice() private view returns (uint256) {
        RwaPriceFeed memory priceFeed = _rwaPriceFeed;
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(priceFeed.priceFeed).latestRoundData();

        // Validate the latest round data from the price feed.
        require(answer > 0, Errors.InvalidPriceFeed());
        require(updatedAt >= block.timestamp - priceFeed.updateInterval, Errors.OutOfDate());
        require(answeredInRound >= roundId, Errors.OutOfDate());

        uint256 scaler = 10 ** (18 - priceFeed.decimals);
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
                (uint256 lenderFunds, uint256 borrowerFunds) =
                    _calculateRemovalAmounts(remainingAmount, matches[index].lCollateral, matches[index].bCollateral);
                uint256 amountToRemove = lenderFunds + borrowerFunds;

                if (amountToRemove == 0) break;
                remainingAmount -= amountToRemove;

                _borrowerAmounts[matches[index].borrower][id] += borrowerFunds;
                borrowerAmountConverted += borrowerFunds;

                emit MatchOrderConverted(id, account, matches[index].borrower, lenderFunds, borrowerFunds);

                if (lenderFunds == matches[index].lCollateral) {
                    matches.pop();
                } else {
                    matches[index].lCollateral -= uint128(lenderFunds);
                }
            } else {
                break;
            }
        }

        amountUsed = amount - remainingAmount;
        if (amountUsed != 0) {
            _idToTotalBorrowed[id] += borrowerAmountConverted;
            uint256 totalLenderFunds = amountUsed - borrowerAmountConverted;
            _matchedDepth -= totalLenderFunds;
            _tby.mint(id, account, totalLenderFunds);
        }
    }

    /// @notice Logic to set the price feed for the RWA token.
    function _setPriceFeed(address rwaPriceFeed_, uint64 priceFeedUpdateInterval_) internal {
        require(priceFeedUpdateInterval_ != 0, Errors.ZeroAmount());
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(rwaPriceFeed_).latestRoundData();

        // Validate the latest round data from the price feed.
        require(answer > 0, Errors.InvalidPriceFeed());
        require(updatedAt >= block.timestamp - priceFeedUpdateInterval_, Errors.OutOfDate());
        require(answeredInRound >= roundId, Errors.OutOfDate());

        // Set the price feed for the RWA token.
        _rwaPriceFeed = RwaPriceFeed({
            priceFeed: rwaPriceFeed_,
            updateInterval: priceFeedUpdateInterval_,
            decimals: AggregatorV3Interface(rwaPriceFeed_).decimals()
        });

        emit RwaPriceFeedSet(rwaPriceFeed_);
    }

    /**
     * @notice Calculates the amount of funds to remove from a matched order.
     * @param remainingAmount The remaining amount of assets left to remove.
     * @param lCollateral Amount of collateral provided by the lender.
     * @param bCollateral Amount of collateral provided by the borrower.
     * @return lenderFunds The amount of lenderFunds that will be removed from the order.
     * @return borrowerFunds The amount of borrowerFunds that will be removed from the order.
     */
    function _calculateRemovalAmounts(uint256 remainingAmount, uint128 lCollateral, uint128 bCollateral)
        internal
        pure
        returns (uint256 lenderFunds, uint256 borrowerFunds)
    {
        uint256 totalCollateral = lCollateral + bCollateral;

        if (remainingAmount >= totalCollateral) {
            return (lCollateral, bCollateral);
        }

        lenderFunds = (remainingAmount * lCollateral) / totalCollateral;
        borrowerFunds = remainingAmount - lenderFunds;
    }

    /// @notice Takes removes the borrower's interest earned off the yield of the RWA token in order to calculate the TBY rate.
    function _takeSpread(uint256 rate) internal view returns (uint256) {
        if (rate > Math.WAD) {
            uint256 yield = rate - Math.WAD;
            return Math.WAD + yield.mulWad(_spread);
        }
        return rate;
    }

    /*///////////////////////////////////////////////////////////////
                            View Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBloomPool
    function getRate(uint256 id) public view override returns (uint256) {
        TbyMaturity memory maturity = _idToMaturity[id];
        RwaPrice memory rwaPrice = _tbyIdToRwaPrice[id];

        if (rwaPrice.startPrice == 0) {
            revert Errors.InvalidTby();
        }
        // If the TBY has not started accruing interest, return 1e18.
        if (block.timestamp <= maturity.start) {
            return Math.WAD;
        }

        // If the TBY has matured, and is eligible for redemption, calculate the rate based on the end price.
        uint256 price = rwaPrice.endPrice != 0 ? rwaPrice.endPrice : _rwaPrice();
        uint256 rate = (uint256(price).divWad(uint256(rwaPrice.startPrice)));
        return _takeSpread(rate);
    }

    /// @inheritdoc IBloomPool
    function lastMintedId() external view returns (uint256) {
        return _lastMintedId;
    }

    /// @inheritdoc IBloomPool
    function futureMaturity() external view returns (uint256) {
        return _futureMaturity;
    }

    /// @inheritdoc IBloomPool
    function rwaPriceFeed() external view returns (RwaPriceFeed memory) {
        return _rwaPriceFeed;
    }

    /// @inheritdoc IBloomPool
    function tbyCollateral(uint256 id) external view returns (TbyCollateral memory) {
        return _idToCollateral[id];
    }

    /// @inheritdoc IBloomPool
    function tbyMaturity(uint256 id) external view returns (TbyMaturity memory) {
        return _idToMaturity[id];
    }

    /// @inheritdoc IBloomPool
    function tbyRwaPricing(uint256 id) external view returns (RwaPrice memory) {
        return _tbyIdToRwaPrice[id];
    }

    /// @inheritdoc IBloomPool
    function borrowerAmount(address account, uint256 id) external view returns (uint256) {
        return _borrowerAmounts[account][id];
    }

    /// @inheritdoc IBloomPool
    function totalBorrowed(uint256 id) external view returns (uint256) {
        return _idToTotalBorrowed[id];
    }

    /// @inheritdoc IBloomPool
    function lenderReturns(uint256 id) external view returns (uint256) {
        return _tbyLenderReturns[id];
    }

    /// @inheritdoc IBloomPool
    function borrowerReturns(uint256 id) external view returns (uint256) {
        return _tbyBorrowerReturns[id];
    }

    /// @inheritdoc IBloomPool
    function isTbyRedeemable(uint256 id) external view returns (bool) {
        return _isTbyRedeemable[id];
    }
}
