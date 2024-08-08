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
 * @title IBTBY
 * @notice Interface for the Borrower Term Bound Yield Token
 */
interface IBTBY {
    /*///////////////////////////////////////////////////////////////
                            Events    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when idle capital is increased.
     * @param account Address of the borrowers account who's idle capital is increased.
     * @param amount Amount of idle capital increased.
     */
    event IdleCapitalIncreased(address indexed account, uint256 amount);

    /**
     * @notice Emitted when idle capital is decreased.
     * @param account Address of the borrowers account who's idle capital is decreased.
     * @param amount Amount of idle capital decreased.
     */
    event IdleCapitalDecreased(address indexed account, uint256 amount);

    /**
     * @notice Emitted when idle capital is withdrawn from the system.
     * @param account Address of the borrowers account who's idle capital is withdrawn.
     * @param amount Amount of idle capital withdrawn.
     */
    event IdleCapitalWithdrawn(address indexed account, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Increases the idle capital of the borrower.
     * @param accounts An array of accounts to increase idle capital.
     * @param amounts An array of amounts to increase idle capital.
     */
    function increaseIdleCapital(address[] memory accounts, uint256[] memory amounts) external;

    /**
     * @notice Decreases the idle capital of the borrower.
     * @param amount Amount of idle capital to withdraw.
     */
    function withdrawIdleCapital(uint256 amount) external;

    /**
     * @notice Mints the BTBY token to the borrower.
     * @param account Address of the borrower to mint the BTBY token.
     * @param amount Amount of BTBY token to mint.
     * @return The amount of BTBY token minted.
     */
    function mint(address account, uint256 amount) external returns (uint256);

    /**
     * @notice Burns the BTBY token from the borrower.
     * @param account Address of the borrower to burn the BTBY token.
     * @param amount Amount of BTBY token to burn.
     */
    function burn(address account, uint256 amount) external;

    /**
     * @notice Returns the idle capital of the borrower.
     * @param account Address of the borrower to query idle capital.
     * @return The idle capital of the borrower.
     */
    function idleCapital(address account) external view returns (uint256);

    /**
     * @notice Returns the address of the BloomPool contract.
     * @return The address of the BloomPool contract.
     */
    function bloomPool() external view returns (address);
}
