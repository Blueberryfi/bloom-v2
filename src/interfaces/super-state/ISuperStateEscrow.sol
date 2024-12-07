// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

/**
 * @title ISuperStateEscrow
 * @notice Interface for the SuperStateEscrow contract.
 */
interface ISuperStateEscrow {
    /// @notice Returns the address of the borrower associated with this escrow contract.
    function borrower() external view returns (address);

    /// @notice Returns the address of the borrow module which created this escrow contract.
    function borrowModule() external view returns (address);

    /// @notice Returns the address of the underlying asset.
    function asset() external view returns (address);

    /// @notice Returns the address of the SuperstateToken (USTB).
    function superstateToken() external view returns (address);

    /// @notice Returns the address of SuperState's redemption contract.
    function redemptionContract() external view returns (address);
}
