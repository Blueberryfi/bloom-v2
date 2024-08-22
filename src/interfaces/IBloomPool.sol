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
     * @param rwaAmount The amount of rwa asset collateral.
     */
    struct TbyCollateral {
        uint128 assetAmount;
        uint128 rwaAmount;
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

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the market maker swaps in rwa tokens for assets.
     * @param id The unique identifier of the TBY.
     * @param account The address of the user who swapped in.
     * @param amount Amount of rwa tokens swapped in.
     */
    event MarketMakerSwappedIn(uint256 indexed id, address indexed account, uint256 amount);

    /**
     * @notice Emitted when the market maker swaps out rwa tokens for assets.
     * @param id The unique identifier of the TBY.
     * @param account The address of the user who swapped out.
     * @param amount Amount of rwa tokens swapped out.
     */
    event MarketMakerSwappedOut(uint256 indexed id, address indexed account, uint256 amount);

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
}
