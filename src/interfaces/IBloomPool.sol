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

import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";
import {IPoolStorage} from "@bloom-v2/interfaces/IPoolStorage.sol";

/**
 * @title IBloomPool
 * @notice Interface for Bloom V2's BloomPool
 */
interface IBloomPool is IOrderbook, IPoolStorage {
    /*///////////////////////////////////////////////////////////////
                            Structs
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct representing the collateral backed by a TBY.
     * @param assetAmount The amount of underlying asset collateral.
     * @param currentRwaAmount The amount of rwa asset collateral at the current time.
     * @param originalRwaAmount The amount of rwa asset collateral at the start of the TBY (will only be set at the end of the TBYs maturity for accounting purposes)
     */
    struct TbyCollateral {
        uint128 assetAmount;
        uint128 currentRwaAmount;
        uint128 originalRwaAmount;
    }

    /**
     * @notice Struct representing the maturity range of a TBY.
     * @param start The start timestamp in seconds of the maturity range.
     * @param end The end timestamp in seconds of the maturity range.
     */
    struct TbyMaturity {
        uint128 start;
        uint128 end;
    }

    /**
     * @notice Struct to store the price range for RWA assets at the time of lTBY start and end times.
     * @param startPrice The starting price of the RWA at the time of the market maker swap.
     * @param endPrice  The ending price of the RWA at the time of the market maker swap.
     */
    struct RwaPrice {
        uint128 startPrice;
        uint128 endPrice;
    }

    /**
     * @notice Struct to store the price feed for an RWA.
     * @param priceFeed The address of the price feed.
     * @param updateInterval The interval in seconds at which the price feed should be updated.
     * @param decimals The number of decimals the price feed returns.
     */
    struct RwaPriceFeed {
        address priceFeed;
        uint64 updateInterval;
        uint8 decimals;
    }

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a lenders match order is converted to a live TBY.
     * @param id The unique identifier of the TBY.
     * @param lender The address of the user who created the lend order.
     * @param borrower The address of the borrower who filled the order.
     * @param lenderCollateral The amount of lender collateral converted.
     * @param borrowerCollateral The amount of borrower collateral converted.
     */
    event MatchOrderConverted(
        uint256 indexed id,
        address indexed lender,
        address indexed borrower,
        uint256 lenderCollateral,
        uint256 borrowerCollateral
    );

    /**
     * @notice Emitted when the market maker swaps in rwa tokens for assets.
     * @param id The unique identifier of the TBY.
     * @param account The address of the user who swapped in.
     * @param rwaAmountIn Amount of rwa tokens swapped in.
     * @param assetAmountOut Amount of assets swapped out.
     */
    event MarketMakerSwappedIn(
        uint256 indexed id, address indexed account, uint256 rwaAmountIn, uint256 assetAmountOut
    );

    /**
     * @notice Emitted when the market maker swaps out rwa tokens for assets.
     * @param id The unique identifier of the TBY.
     * @param account The address of the user who swapped out.
     * @param rwaAmountOut Amount of rwa tokens swapped out.
     * @param assetAmountIn Amount of assets swapped in.
     */
    event MarketMakerSwappedOut(
        uint256 indexed id, address indexed account, uint256 rwaAmountOut, uint256 assetAmountIn
    );

    /**
     * @notice Emitted when a Lender redeems their share of rewards from a TBY.
     * @param account The address of the lender redeeming.
     * @param id The unique identifier of the TBY being redeemed.
     * @param amount The amount of rewards being redeemed.
     */
    event LenderRedeemed(address indexed account, uint256 indexed id, uint256 amount);

    /**
     * @notice Emitted when a Borrower redeems their share of rewards from a TBY.
     * @param account The address of the borrower redeeming.
     * @param id The unique identifier of the TBY being redeemed.
     * @param amount The amount of rewards being redeemed.
     */
    event BorrowerRedeemed(address indexed account, uint256 indexed id, uint256 amount);

    /**
     * @notice Emitted when the RWA price feed is set.
     * @param priceFeed The address of the RWA price feed.
     */
    event RwaPriceFeedSet(address priceFeed);

    /**
     * @notice Emitted when the maturity time for the next TBY is set.
     * @param maturityLength The length of time in seconds that future TBY Ids will mature for.
     */
    event TbyMaturitySet(uint256 maturityLength);

    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Redeem the lender's share of rewards generated from the TBY at its maturity.
     * @dev Rewards generated from TBYs are only claimable by the holder of the TBY at maturity.
     * @param id The id of the TBY to redeem.
     * @param amount The amount of TBYs to redeem.
     * @return reward The amount of rewards for the lender.
     */
    function redeemLender(uint256 id, uint256 amount) external returns (uint256 reward);

    /**
     * @notice Redeem the borrowers's share of rewards generated from the TBY at its maturity.
     * @dev Rewards generated from TBYs are only claimable by the holder of the TBY at maturity.
     * @param id The id of the TBY to redeem.
     * @return reward The amount of rewards for the borrower.
     */
    function redeemBorrower(uint256 id) external returns (uint256 reward);

    /**
     * @notice Returns the current rate of the TBY in terms of USD.
     * @dev The rate is returned as a fixed point number with 18 decimals.
     * @param id The id of the TBY.
     */
    function getRate(uint256 id) external view returns (uint256);

    /// @notice Returns the last minted TBY id.
    function lastMintedId() external view returns (uint256);

    /// @notice Returns the length of time that the next minted TBY Id will mature for. Default is 180 days.
    function futureMaturity() external view returns (uint256);

    /// @notice Returns the RWAs price feed struct.
    function rwaPriceFeed() external view returns (RwaPriceFeed memory);

    /// @notice Returns the TbyCollateral struct containing the breakdown of collateral for a given Tby ID.
    function tbyCollateral(uint256 id) external view returns (TbyCollateral memory);

    /// @notice Returns the TbyMaturity struct containing the start and end timestamps of a given Tby ID.
    function tbyMaturity(uint256 id) external view returns (TbyMaturity memory);

    /// @notice Returns the TbyPrice struct containing RWA price at the start and end of a Tby's lifetime.
    function tbyRwaPricing(uint256 id) external view returns (RwaPrice memory);

    /// @notice Returns the total amount of assets a borrower has contributed to for a given Tby ID.
    function borrowerAmount(address account, uint256 id) external view returns (uint256);

    /// @notice Returns the total amount of assets all the borrowers have contributed to for a given Tby ID.
    function totalBorrowed(uint256 id) external view returns (uint256);

    /// @notice Returns the total amount of assets currently available for lender's to redeem for a given Tby ID.
    function lenderReturns(uint256 id) external view returns (uint256);

    /// @notice Returns the total amount of assets currently available for borrower's to redeem for a given Tby ID.
    function borrowerReturns(uint256 id) external view returns (uint256);

    /// @notice Returns if a Tby is eligible for redemption.
    function isTbyRedeemable(uint256 id) external view returns (bool);
}
