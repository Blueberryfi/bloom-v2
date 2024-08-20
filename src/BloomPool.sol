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

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
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
contract BloomPool is IBloomPool, Orderbook, Ownable2Step {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice The last TBY id that was minted.
    uint256 private _lastMintedId;

    /// @notice Price feed for the RWA token.
    address private immutable _rwaPriceFeed;

    /// @notice Decimals for the RWA price feed.
    uint8 private immutable _rwaPriceFeedDecimals;

    /// @notice The spread between the rate of the TBY and the rate of the RWA token.
    uint256 private _spread;

    /// @notice Mapping of TBY ids to the maturity range.
    mapping(uint256 => TbyMaturity) private _idToMaturity;

    /// @notice Mapping of TBY ids to the RWA pricing ranges.
    mapping(uint256 => RwaPrice) private _tbyIdToRwaPrice;

    /// @notice Mapping of TBY ids to the borower's return amount.
    mapping(uint256 => uint256) private _tbyBorrowerReturns;

    /// @notice Mapping of TBY ids to overall lender's return amount.
    mapping(uint256 => uint256) private _tbyLenderReturns;

    /// @notice Mapping of borrowers to their token shares for each TBY id.
    mapping(address => mapping(uint256 => uint256)) private _borrowerAmounts;

    /// @notice A mapping of the TBY id to the total amount matched by borrowers.
    mapping(uint256 => uint256) private _idToTotalMatched;

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(
        address asset_,
        address rwa_,
        address rwaPriceFeed,
        uint256 initLeverage,
        uint256 spread,
        address owner_
    ) Ownable(owner_) Orderbook(asset_, rwa_, initLeverage) {
        require(owner_ != address(0), Errors.ZeroAddress());
        require(
            initLeverage >= 1e18 && initLeverage < 100e18,
            Errors.InvalidLeverage()
        );

        _rwaPriceFeedDecimals = AggregatorV3Interface(rwaPriceFeed).decimals();
        _rwaPriceFeed = rwaPriceFeed;
        _spread = spread;
    }

    /*///////////////////////////////////////////////////////////////
                                Functions    
    //////////////////////////////////////////////////////////////*/

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
    function swapIn(
        address[] memory accounts,
        uint256 assetAmount
    ) external KycMarketMaker returns (uint256 id, uint256 amountSwapped) {
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
            uint256 removedAmount = _convertMatchOrders(
                id,
                accounts[i],
                assetAmount
            );
            assetAmount -= removedAmount;
            amountSwapped += removedAmount;
            if (assetAmount == 0) break;
            _lTby.mint(id, accounts[i], amountSwapped);
        }

        // Initialize the starting price of the RWA token if it has not been set
        RwaPrice memory rwaPrice = _tbyIdToRwaPrice[id];
        uint256 currentPrice = _rwaPrice();

        if (rwaPrice.startPrice == 0) {
            _tbyIdToRwaPrice[id].startPrice = uint128(currentPrice);
        }

        uint256 rwaAmount = (currentPrice * amountSwapped) / 1e18;
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
    function swapOut(
        uint256 id,
        uint256 rwaAmount
    ) external KycMarketMaker returns (uint256 assetAmount) {
        require(rwaAmount > 0, Errors.ZeroAmount());
        require(
            IERC20(_rwa).balanceOf(msg.sender) >= rwaAmount,
            Errors.InsufficientBalance()
        );
        require(
            _idToMaturity[id].end <= block.timestamp,
            Errors.TBYNotMatured()
        );

        RwaPrice memory rwaPrice = _tbyIdToRwaPrice[id];
        uint256 currentPrice = _rwaPrice();

        if (rwaPrice.endPrice == 0) {
            _tbyIdToRwaPrice[id].endPrice = uint128(currentPrice);
        }

        uint256 tbyAmount = (rwaPrice.startPrice * rwaAmount) / 1e18;
        assetAmount = (rwaAmount * 1e6) / currentPrice;

        uint256 lenderReturn = (getRate(id) * tbyAmount) / 1e12;
        uint256 borrowerReturn = tbyAmount - lenderReturn;

        _tbyBorrowerReturns[id] += borrowerReturn;
        _tbyLenderReturns[id] += lenderReturn;

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), assetAmount);
        IERC20(_rwa).safeTransfer(msg.sender, rwaAmount);

        emit MarketMakerSwappedOut(id, msg.sender, rwaAmount);
    }

    /// @inheritdoc IBloomPool
    function redeemLender(uint256 id) external override {
        uint256 lenderReturns = _tbyLenderReturns[id];
        uint256 share = _lTby.shareOf(id, msg.sender);

        require(lenderReturns > 0, Errors.TBYNotMatured());
        require(share > 0, Errors.ZeroShares());

        uint256 reward = lenderReturns.mulWad(share);
        _tbyLenderReturns[id] -= reward;
        _lTby.burnShares(id, msg.sender, share);
        IERC20(_asset).safeTransfer(msg.sender, reward);
    }

    /// @inheritdoc IBloomPool
    function redeemBorrower(uint256 id) external override {
        uint256 borrowerReturns = _tbyBorrowerReturns[id];
        uint256 borrowerShare = borrowerShareOf(id, msg.sender);
        uint256 reward = borrowerReturns.mulWad(borrowerShare);
        _tbyBorrowerReturns[id] -= reward;
        _borrowerAmounts[msg.sender][id] -= borrowerShare.mulWad(
            _borrowerAmounts[msg.sender][id]
        );
        IERC20(_asset).safeTransfer(msg.sender, reward);
    }

    /// @inheritdoc IBloomPool
    function borrowerShareOf(
        uint256 id,
        address account
    ) public view override returns (uint256) {
        return _borrowerAmounts[account][id].divWadUp(_idToTotalMatched[id]);
    }

    /// @inheritdoc IBloomPool
    function getRate(uint256 id) public view override returns (uint256) {
        TbyMaturity memory maturity = _idToMaturity[id];
        RwaPrice memory rwaPrice = _tbyIdToRwaPrice[id];

        uint256 time = block.timestamp;
        // If the TBY has not started accruing interest, return 1e18.
        if (time <= maturity.start) {
            return 1e18;
        }

        // If the TBY has matured, and is eligible for redemption, calculate price based on the end price.
        if (time >= maturity.end && rwaPrice.endPrice != 0) {
            return 1e18 + (rwaPrice.endPrice * _spread) / rwaPrice.startPrice;
        }

        // If the TBY has matured, and is not-eligible for redemption due to market maker delay,
        //     calculate price based on the current price of the RWA token via the price feed.
        return 1e18 + (_rwaPrice() * _spread) / rwaPrice.startPrice;
    }

    /// @notice Returns the current price of the RWA token.
    function _rwaPrice() public view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(
            _rwaPriceFeed
        ).latestRoundData();
        require(updatedAt >= block.timestamp - 1 days, Errors.OutOfDate());
        return uint256(answer) * 10 ** (Math.WAD - _rwaPriceFeedDecimals);
    }

    /**
     * @notice Whitelists an address to be a KYCed borrower.
     * @dev Only the owner can call this function.
     * @param account The address of the borrower to whitelist.
     */
    function whitelistBorrower(address account) external onlyOwner {
        _borrowers[account] = true;
        emit BorrowerKYCed(account);
    }

    /**
     * @notice Whitelists an address to be a KYCed borrower.
     * @dev Only the owner can call this function.
     * @param account The address of the borrower to whitelist.
     */
    function whitelistMarketMaker(address account) external onlyOwner {
        _marketMakers[account] = true;
        emit MarketMakerKYCed(account);
    }

    /**
     * @notice Updates the leverage for future borrower fills
     * @dev Leverage is scaled to 1e18. (20x leverage = 20e18)
     * @param leverage Updated leverage
     */
    function setLeverage(uint256 leverage) external onlyOwner {
        require(
            leverage >= 1e18 && leverage < 100e18,
            Errors.InvalidLeverage()
        );
        _leverage = leverage;
        emit LeverageSet(leverage);
    }

    /**
     * @notice Updates the spread between the TBY rate and the RWA rate.
     * @param spread The new spread value.
     */
    function setSpread(uint256 spread) external onlyOwner {
        _spread = spread;
        emit SpreadUpdated(spread);
    }

    function _convertMatchOrders(
        uint256 id,
        address account,
        uint256 amount
    ) internal returns (uint256) {
        MatchOrder[] storage matches = _userMatchedOrders[account];
        uint256 remainingAmount = amount;
        uint256 borrowerAmountConverted = 0;

        uint256 length = matches.length;
        for (uint256 i = length; i != 0; --i) {
            uint256 index = i - 1;

            if (remainingAmount >= matches[index].amount) {
                remainingAmount -= matches[index].amount;

                uint256 borrowerAmount = matches[index].amount.divWadUp(
                    matches[index].leverage
                );

                _borrowerAmounts[account][id] += borrowerAmount;
                borrowerAmountConverted += borrowerAmount;

                matches.pop();
            } else {
                break;
            }
        }

        _idToTotalMatched[id] += borrowerAmountConverted;
        uint256 totalRemoved = amount - remainingAmount;
        _matchedDepth -= totalRemoved;

        return totalRemoved;
    }
}
