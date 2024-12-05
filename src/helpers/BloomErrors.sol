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

/**
 * @title BloomErrors
 * @notice Custom Errors for Bloom V2 Contracts
 */
library BloomErrors {
    /*///////////////////////////////////////////////////////////////
                            Pool Errors
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user tries to redeem a TBY that is not redeemable.
    error TBYNotRedeemable();

    /// @notice Emitted when a user tries to redeem a TBY but has no rewards to claim.
    error ZeroRewards();

    /// @notice Emitted when the owner tries to set the spread to a value that is too large.
    error InvalidSpread();

    /// @notice Emitted when getting the price of a Tby that does not exist.
    error InvalidTby();

    /// @notice Emitted when a market maker tries to swap out too small of a percentage of RWA tokens.
    error SwapOutTooSmall();

    /// @notice Emitted when a borrower tries to redeem a TBY but the total borrowed for that TBY is zero.
    error TotalBorrowedZero();

    /*///////////////////////////////////////////////////////////////
                            Orderbook Errors    
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an operation is trying to access more liquidity than there is depth.
    error InsufficientDepth();

    /// @notice Emitted the admin inputs a leverage value that is not within the bounds. (0, 100)
    error InvalidLeverage();

    /// @notice Emitted when a borrower matches an order or orders that are too small to be filled.
    ///         Amount post leverage must be greater than 0.
    error InvalidMatchSize();

    /// @notice Emitted when a borrower tries to kill a match order that does not exist.
    error MatchOrderNotFound();

    /// @notice Emitted when a borrower tries to borrow from an invalid borrow module. (Could be paused or not added)
    error InvalidBorrowModule();

    /// @notice Emitted when a borrower tries to borrow an amount that is greater than the total collateral.
    error ExceedsSlippage();

    /// @notice Emitted when an order falls below the minimum size.
    error OrderBelowMinSize();

    /*///////////////////////////////////////////////////////////////
                            KYC Errors    
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a users tries to interact with a function that requires KYC verification.
    error KYCFailed();

    /*///////////////////////////////////////////////////////////////
                            Token Errors
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user tries to call a function only for the BloomPool.
    error NotBloom();

    /// @notice Emitted when trying to swap out TBYs that have not matured.
    error TBYNotMatured();

    /// @notice Emitted when a user tries to check the total supply of a order that isnt a live TBY.
    error InvalidId();

    /// @notice Emitted when a borrower or lender has no shares of lTBY or bTBY.
    error ZeroShares();

    /*///////////////////////////////////////////////////////////////
                            General Errors    
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a users inputs an invalid amount.
    error ZeroAmount();

    /// @notice Emitted when a user inputs an invalid address.
    error ZeroAddress();

    /// @notice Emiited when a user tries to spend more than their balance.
    error InsufficientBalance();

    /*///////////////////////////////////////////////////////////////
                            CCIP Errors
    //////////////////////////////////////////////////////////////*/

    /// @notice The error emitted when the sender is invalid.
    error InvalidSender();

    /// @notice The error emitted when the chain ID is 0 on construction or if a message is sent from the wrong chain.
    error InvalidChainId();

    /*///////////////////////////////////////////////////////////////
                            Price Feeds    
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the rwa price feed is out of date.
    error OutOfDate();

    /// @notice Invalid Price Feed
    error InvalidPriceFeed();

    /// @notice Invalid Configuration
    error InvalidConfiguration();
}
