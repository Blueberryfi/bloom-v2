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
import {ReentrancyGuard} from "@solady/utils/ReentrancyGuard.sol";
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
contract BloomPool is IBloomPool, Orderbook, ReentrancyGuard {
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
        _lastMintedId = type(uint256).max;
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

        IERC20(_asset).safeTransfer(msg.sender, reward);
        emit LenderRedeemed(msg.sender, id, reward);
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

        IERC20(_asset).safeTransfer(msg.sender, reward);
        emit BorrowerRedeemed(msg.sender, id, reward);
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
        // Get the TBY id to mint
        id = _lastMintedId;
        TbyMaturity memory maturity = _idToMaturity[id];

        // If the timestamp of the last minted TBYs start is greater than 48 hours from now, this swap is for a new TBY Id.
        if (block.timestamp > maturity.start + 48 hours) {
            // Last minted id is set to type(uint256).max, so we need to wrap around to 0 to start the first TBY.
            unchecked {
                id = ++_lastMintedId;
            }

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
        }

        // Initialize the starting price of the RWA token if it has not been set
        RwaPrice storage rwaPrice = _tbyIdToRwaPrice[id];
        TbyCollateral storage collateral = _idToCollateral[id];
        uint256 currentPrice = _rwaPrice();

        uint256 rwaAmount = (amountSwapped * _assetScalingFactor).divWadUp(currentPrice) / _rwaScalingFactor;
        require(rwaAmount > 0, Errors.ZeroAmount());

        if (rwaPrice.startPrice == 0) {
            rwaPrice.startPrice = uint128(currentPrice);
        } else if (rwaPrice.startPrice != currentPrice) {
            // In the event that the market maker is doing multiple swaps for the same TBY Id,
            //     and the rwa price has changes, we need to recalculate the starting price of the TBY,
            //     to ensure accuracy in the TBY's rate of return. To do this we will normalize the price
            //     by taking the weighted average of the startPrice and the currentPrice.
            uint256 totalValue = uint256(collateral.rwaAmount).mulWad(rwaPrice.startPrice)
                + rwaAmount.mulWad(currentPrice) / _rwaScalingFactor;
            uint256 totalCollateral = collateral.rwaAmount + rwaAmount;
            uint256 normalizedPrice = totalValue.divWad(totalCollateral);
            rwaPrice.startPrice = uint128(normalizedPrice);
        }

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

        if (rwaPrice.endPrice == 0) {
            _tbyIdToRwaPrice[id].endPrice = uint128(currentPrice);
        }

        uint256 percentSwapped = rwaAmount.divWad(collateral.rwaAmount);

        if (percentSwapped > Math.WAD) {
            percentSwapped = Math.WAD;
            rwaAmount = collateral.rwaAmount;
        }

        uint256 tbyTotalSupply = _tby.totalSupply(id);
        uint256 tbyAmount = percentSwapped != Math.WAD ? tbyTotalSupply.mulWadUp(percentSwapped) : tbyTotalSupply;
        require(tbyAmount > 0, Errors.ZeroAmount());

        assetAmount = uint256(currentPrice).mulWad(rwaAmount) / (10 ** ((18 - _rwaDecimals) + (18 - _assetDecimals)));

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
                uint256 newRate = accumulatedCollateral.divWad(_tby.totalSupply(id));
                uint256 adjustedEndPrice = (newRate * rwaPrice.startPrice) / _spread;
                rwaPrice.endPrice = uint128(adjustedEndPrice);
            }
        }
        uint256 borrowerReturn = assetAmount - lenderReturn;

        _tbyBorrowerReturns[id] += borrowerReturn;
        _tbyLenderReturns[id] += lenderReturn;

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
     * @notice Sets the price feed for the RWA token.
     * @dev Only the owner can call this function.
     * @param rwaPriceFeed_ The address of the price feed for the RWA token.
     */
    function setPriceFeed(address rwaPriceFeed_) public onlyOwner {
        _setPriceFeed(rwaPriceFeed_);
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions    
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current price of the RWA token.
    function _rwaPrice() private view returns (uint256) {
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
                (uint256 lenderFunds, uint256 borrowerFunds) =
                    _calculateRemovalAmounts(remainingAmount, matches[index].lCollateral, matches[index].bCollateral);
                uint256 amountToRemove = lenderFunds + borrowerFunds;

                if (amountToRemove == 0) break;
                remainingAmount -= amountToRemove;

                _borrowerAmounts[matches[index].borrower][id] += borrowerFunds;
                borrowerAmountConverted += borrowerFunds;

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
    function _setPriceFeed(address rwaPriceFeed_) internal {
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(rwaPriceFeed_).latestRoundData();
        require(answer > 0, Errors.InvalidPriceFeed());
        require(updatedAt >= block.timestamp - 1 days, Errors.OutOfDate());

        _rwaPriceFeed = rwaPriceFeed_;
        _rwaPriceFeedDecimals = AggregatorV3Interface(rwaPriceFeed_).decimals();
        emit RwaPriceFeedSet(rwaPriceFeed_);
    }

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

        uint256 time = block.timestamp;
        // If the TBY has not started accruing interest, return 1e18.
        if (time <= maturity.start) {
            return Math.WAD;
        }

        // If the TBY has matured, and is eligible for redemption, calculate price based on the end price.
        if (time >= maturity.end && rwaPrice.endPrice != 0) {
            return ((rwaPrice.endPrice * _spread) / rwaPrice.startPrice);
        }

        // If the TBY has matured, and is not-eligible for redemption due to market maker delay,
        //     calculate price based on the current price of the RWA token via the price feed.
        return ((_rwaPrice() * _spread) / rwaPrice.startPrice);
    }

    function lastMintedId() external view returns (uint256) {
        return _lastMintedId;
    }

    /// @inheritdoc IBloomPool
    function rwaPriceFeed() external view returns (address) {
        return _rwaPriceFeed;
    }

    function tbyCollateral(uint256 id) external view returns (TbyCollateral memory) {
        return _idToCollateral[id];
    }

    function tbyMaturity(uint256 id) external view returns (TbyMaturity memory) {
        return _idToMaturity[id];
    }

    function tbyRwaPricing(uint256 id) external view returns (RwaPrice memory) {
        return _tbyIdToRwaPrice[id];
    }

    function borrowerAmount(address account, uint256 id) external view returns (uint256) {
        return _borrowerAmounts[account][id];
    }

    function totalBorrowed(uint256 id) external view returns (uint256) {
        return _idToTotalBorrowed[id];
    }

    function lenderReturns(uint256 id) external view returns (uint256) {
        return _tbyLenderReturns[id];
    }

    function borrowerReturns(uint256 id) external view returns (uint256) {
        return _tbyBorrowerReturns[id];
    }

    function isTbyRedeemable(uint256 id) external view returns (bool) {
        return _isTbyRedeemable[id];
    }
}
