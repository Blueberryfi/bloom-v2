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
     * @notice Opens a new order in the orderbook.
     * @dev Only the BloomPool can call this function
     * @param amount The amount of underlying tokens being placed into the orderbook.
     */
    function open(address account, uint256 amount) external;

    /**
     * @notice Close an order in the orderbook.
     * @dev Only the BloomPool can call this function
     * @param amount The amount of underlying tokens to remove from the orderbook.
     */
    function close(address account, uint256 id, uint256 amount) external;

    /**
     * @notice The order is staged for the market maker.
     * @dev The staging process occurs after the order is matched by the borrower.
     * @dev Only the BloomPool can call this function.
     * @param amount The amount of underlying tokens that have been matched.
     */
    function stage(address account, uint256 amount) external;

    /**
     * @notice Returns the open balance of an account.
     * @param account The account to check the balance of.
     */
    function openBalance(address account) external view returns (uint256);

    function matchedBalance(address account) external view returns (uint256);

    function liveBalance(address account) external view returns (uint256);

    /**
     * @notice Returns the sum of open, matched, and live balances for an account.
     * @param account The address of the account to check the balance of.
     */
    function totalBalance(address account) external view returns (uint256 amount);

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
}
