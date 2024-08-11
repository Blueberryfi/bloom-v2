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
 * @title ILTBY
 * @notice Interface for the Lender Term Bound Yield Token
 */
interface ILTBY {
    /**
     * @notice Returns the address of the BloomPool contract.
     * @return The address of the BloomPool contract.
     */
    function bloomPool() external view returns (address);

    /**
     * @notice Returns the name of the token.
     * @return The name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the symbol of the token.
     * @return The symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Returns the number of decimals for the token.
     * @return The number of decimals for the token.
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Total Supply of the token.
     * @param id The id of the token.
     * @param account The address of the account to check.
     */
    function totalSupply(uint256 id, address account) external view returns (uint256);
}
