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

/**
 * @title BloomErrors
 * @notice Custom Errors for Bloom V2 Contracts
 */
library BloomErrors {
    /*///////////////////////////////////////////////////////////////
                            Orderbook Errors    
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the orderbook is full and no more orders can be added.
    error OrderbookFull();

    /// @notice Emitted when the orderbook is empty and a borrow tries to fill orders.
    error NoOrdersToFill();

    /// @notice Emitted when an operation is trying to access more liquidity than there is depth.
    error InsufficientDepth();

    /// @notice Emitted the admin inputs a leverage value that is not within the bounds. (0, 100)
    error InvalidLeverage();

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

    /// @notice Emitted when a user tries to call a function only for the LTby token.
    error NotLTBY();

    error InvalidOrderType();

    /*///////////////////////////////////////////////////////////////
                            General Errors    
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a users inputs an invalid amount.
    error ZeroAmount();

    /// @notice Emiited when a user tries to spend more than their balance.
    error InsufficientBalance();

    /// @notice Emitted when array lengths do not match.
    error ArrayMismatch();
}
