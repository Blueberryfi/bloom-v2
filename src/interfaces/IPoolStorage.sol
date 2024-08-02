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
 * @title IPoolStorage
 * @notice Interface for global storage within Bloom v2
 */
interface IPoolStorage {
    /*///////////////////////////////////////////////////////////////
                              Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a borrower is KYCed.
    event BorrowerKYCed(address indexed account);

    /// @notice Emitted when a market maker is KYCed.
    event MarketMakerKYCed(address indexed account);

    /*///////////////////////////////////////////////////////////////
                              Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the underlying asset of the Pool.
    function asset() external view returns (address);

    /// @notice Returns the address of the RWA token of the Pool.
    function rwa() external view returns (address);

    /**
     * @notice Returns if the user is a valid borrower.
     * @param account The address of the user to check.
     * @return bool True if the user is a valid borrower.
     */
    function isKYCedBorrower(address account) external view returns (bool);

    /**
     * @notice Returns if the user is a valid market maker.
     * @param account The address of the user to check.
     * @return bool True if the user is a valid market maker.
     */
    function isKYCedMarketMaker(address account) external view returns (bool);
}
