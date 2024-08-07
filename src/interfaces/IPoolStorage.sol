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

    /**
     * @notice Emitted when the borrowers leverage amount is updated
     * @param leverage The updated leverage amount for the borrower.
     */
    event LeverageSet(uint256 leverage);

    /*///////////////////////////////////////////////////////////////
                              Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the lTby token.
    function lTby() external view returns (address);

    /// @notice Returns the address of the bTby token.
    function bTby() external view returns (address);

    /// @notice Returns the address of the underlying asset of the pool.
    function asset() external view returns (address);

    /// @notice Returns the number of decimals for the underlying asset of the pool.
    function assetDecimals() external view returns (uint8);

    /// @notice Returns the address of the RWA token of the pool.
    function rwa() external view returns (address);

    /// @notice Returns the number of decimals for the RWA token of the pool.
    function rwaDecimals() external view returns (uint8);

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
