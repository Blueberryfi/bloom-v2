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

import {ITby} from "./ITby.sol";

interface IBloomPool is ITby {
    /*///////////////////////////////////////////////////////////////
                                Structs
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Struct representing the collateral backed by a TBY.
     * @param assetAmount The amount of underlying asset collateral.
     * @param rwaAmount The amount of rwa asset collateral at the current time.
     */
    struct TbyCollateral {
        uint128 assetAmount;
        uint128 rwaAmount;
    }

    /**
     * @notice Struct to store the price range for RWA assets at the time of TBY start and end times.
     * @param startPrice The starting price of the RWA at the time of the borrower swap.
     * @param endPrice  The ending price of the RWA at the time of the borrower swap.
     * @param spread The spread for the TBY.
     */
    struct RwaPrice {
        uint128 startPrice;
        uint128 endPrice;
        uint128 spread;
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
     * @notice Struct used to return the total value of a set of TBYs when batchValue is called.
     * @param totalValue The total value of the TBYs.
     * @param remainingIds The ids of the TBYs that were not processed in the call.
     */
    struct BatchValueResult {
        uint256 totalValue;
        uint256[] remainingIds;
    }

    /**
     * @notice Struct representing the borrow order.
     * @param tbyId The id of the TBY to borrow the assets for.
     * @param borrower The address of the borrower.
     * @param totalAmount The total amount of underlying assets that the borrower is borrowering.
     * @param lenders The addresses of the lenders.
     * @param amounts The amounts of the lenders.
     */
    struct BorrowOrder {
        uint256 tbyId;
        address borrower;
        uint256 totalAmount;
        address[] lenders;
        uint256[] amounts;
    }

    /**
     * @notice Struct representing the result of a borrow order.
     * @param bCollateral The amount of borrower collateral posted to execute the transaction.
     * @param rwaPurchased The amount of RWA assets purchased from the loan.
     */
    struct BorrowResult {
        uint256 bCollateral;
        uint256 rwaPurchased;
    }

    /**
     * @notice Struct representing the result of a repay order.
     * @param rwaRepaid The amount of RWA assets repaid.
     * @param assetsReturned The amount of underlying assets received after repaying the RWA.
     * @param rwaCollRemaining The amount of RWA collateral backed by the TBY after repaying the RWA.
     * @param assetCollRemaining The amount of underlying asset collateral backed by the TBY after repaying the RWA.
     */
    struct RepayResult {
        uint256 rwaRepaid;
        uint256 assetsReturned;
        uint256 rwaCollRemaining;
        uint256 assetCollRemaining;
    }

    /*///////////////////////////////////////////////////////////////
                              Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a borrower is KYCed.
    event BorrowerKyced(address indexed account, bool isKyced);

    /// @notice Emitted when the spread is updated.
    event SpreadSet(uint256 spread);

    /**
     * @notice Emitted when the borrowers leverage amount is updated
     * @param leverage The updated leverage amount for the borrower.
     */
    event LeverageSet(uint256 leverage);

    /**
     * @notice Emitted when the maturity time for the next TBY is set.
     * @param maturityLength The length of time in seconds that future TBY Ids will mature for.
     */
    event TbyMaturitySet(uint256 maturityLength);

    /**
     * @notice Emitted when a new TBY id's maturity is set.
     * @param id The id of the new TBY.
     * @param start The start timestamp of the new TBY.
     * @param end The end timestamp of the new TBY.
     */
    event NewTbyId(uint256 id, uint256 start, uint256 end);

    /*///////////////////////////////////////////////////////////////
                            Write Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Borrow lenders funds to purchase an RWA asset.
     * @dev This function will be called by the BloomRouter.
     * @dev Module Developers need to implement the _purchaseRwa function in order to allow this function to execute successfully.
     * @param order A BorrowOrder struct containing the id of the TBY to borrow the assets for, the address of the borrower,
     *         the amount of underlying assets that the borrower is borrowering, the addresses of the lenders, and the amounts of the lenders.
     * @return result A BorrowResult struct containing the amount of borrower collateral posted to execute the transaction
     *         and the amount of RWA assets purchased from the loan.
     */
    function borrow(BorrowOrder memory order) external payable returns (BorrowResult memory result);

    /**
     * @notice Repays ALL borrowers borrowed funds + collateral.
     * @dev This function will be called by the BloomRouter.
     * @dev Module Developers need to implement the _getRwaSwapAmount and _repayRwa functions in order to allow this function to execute successfully.
     * @param tbyId The id of the TBY to repay the borrowed assets for.
     * @return result A RepayResult struct containing the amount of RWA assets repaid, the amount of underlying assets received after repaying the RWA,
     *         the amount of RWA collateral backed by the TBY after repaying the RWA, and the amount of underlying asset collateral backed by the TBY after repaying the RWA.
     */
    function repay(uint256 tbyId) external returns (RepayResult memory result);

    /**
     * @notice Withdraws the lender's funds from the TBY.
     * @dev This function will be called by the BloomRouter.
     * @param tbyId The id of the TBY to withdraw the lender's funds from.
     * @param lender The address of the lender to withdraw the funds for.
     * @param amount The amount of funds to withdraw.
     * @return reward The amount of rewards to be paid to the lender.
     */
    function withdrawLender(uint256 tbyId, address lender, uint256 amount) external returns (uint256 reward);

    /**
     * @notice Withdraws the borrower's funds from the TBY.
     * @dev This function will be called by the BloomRouter.
     * @param tbyId The id of the TBY to withdraw the borrower's funds from.
     * @param borrower The address of the borrower to withdraw the funds for.
     * @return reward The amount of rewards to be paid to the borrower.
     */
    function withdrawBorrower(uint256 tbyId, address borrower) external returns (uint256 reward);

    /**
     * @notice Calculates the TBY id to mint based on the last minted TBY id (in this module), the swap buffer, and the last minted TBY id from the Bloom Pool.
     * @dev This function is called by the Bloom Pool.
     * @dev If the last minted TBY id (from this module) was created 48 hours ago or more, a new TBY id is minted.
     * @return id The id of the TBY to mint.
     */
    function calculateTbyId(uint256 bloomsLastMintedId) external returns (uint256 id);

    /*///////////////////////////////////////////////////////////////
                            View Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current rate of the TBY in terms of USD.
     * @dev The rate is returned as a fixed point number with 18 decimals.
     * @param id The id of the TBY.
     */
    function getRate(uint256 id) external view returns (uint256);

    /// @notice Returns the address of the Bloom Pool.
    function bloomRouter() external view returns (address);

    /// @notice Returns the address of the underlying asset of the pool.
    function asset() external view returns (address);

    /// @notice Returns the address of the RWA token of the pool.
    function rwa() external view returns (address);

    /// @notice Returns the leverage of the borrow module.
    function leverage() external view returns (uint256);

    /// @notice Returns the spread between the TBY rate and the RWA rate.
    function spread() external view returns (uint256);

    /// @notice Returns the swap buffer for the borrow module.
    function swapBuffer() external view returns (uint256);

    /// @notice Returns the loan duration for the borrow module.
    function loanDuration() external view returns (uint256);

    /// @notice Returns the last TBY id that was minted associated with the borrow module.
    function lastMintedId() external view returns (uint256);

    /**
     * @notice Returns if the user is a valid borrower.
     * @param account The address of the user to check.
     * @return bool True if the user is a valid borrower.
     */
    function isKYCedBorrower(address account) external view returns (bool);

    /**
     * @notice Returns the RWA price ranges for a given TBY id.
     * @param tbyId The id of the TBY to get the RWA price for.
     * @return RwaPrice The RWA price struct for the TBY.
     */
    function rwaPrice(uint256 tbyId) external view returns (RwaPrice memory);

    /**
     * @notice Returns the collateral for a given TBY id.
     * @param tbyId The id of the TBY to get the collateral for.
     * @return TbyCollateral The collateral for the TBY.
     */
    function tbyCollateral(uint256 tbyId) external view returns (TbyCollateral memory);

    /// @notice Returns the total amount of assets a borrower has contributed to for a given Tby ID.
    function borrowerAmount(address account, uint256 id) external view returns (uint256);

    /// @notice Returns the total amount of assets all the borrowers have contributed to for a given Tby ID.
    function totalBorrowed(uint256 id) external view returns (uint256);

    /// @notice Returns the TbyMaturity struct containing the start and end timestamps of a given Tby ID.
    function tbyMaturity(uint256 id) external view returns (TbyMaturity memory);

    /// @notice Returns the total amount of assets currently available for lender's to redeem for a given Tby ID.
    function lenderReturns(uint256 id) external view returns (uint256);

    /// @notice Returns the total amount of assets currently available for borrower's to redeem for a given Tby ID.
    function borrowerReturns(uint256 id) external view returns (uint256);

    /**
     * @notice This function is used to get the total value worth of a set of TBYs for a given lender.
     * @param ids The ids of the TBYs to get the total value for.
     * @param lender The address of the lender to get the total value for.
     * @return result A BatchValueResult struct containing the total value worth of the TBYs for the lender
     *         and the remaining ids that were not processed in the call.
     */
    function batchValue(uint256[] calldata ids, address lender)
        external
        view
        returns (BatchValueResult memory result);
}
