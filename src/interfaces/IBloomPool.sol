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
     */
    function redeemLender(uint256 id) external;

    /**
     * @notice Redeem the borrowers's share of rewards generated from the TBY at its maturity.
     * @dev Rewards generated from TBYs are only claimable by the holder of the TBY at maturity.
     * @param id The id of the TBY to redeem.
     */
    function redeemBorrower(uint256 id) external;

    /**
     * @notice Returns the share of matched orders for a borrower based on the TBYs id.
     * @dev TODO: Add scaling notes.
     * @param id The id of the TBY.
     * @param account The address of the borrower to check the share of.
     */
    function borrowerShareOf(uint256 id, address account) external view returns (uint256);

    /**
     * @notice Returns the current rate of the TBY in terms of USD.
     * @param id The id of the TBY.
     */
    function getRate(uint256 id) external view returns (uint256);
}