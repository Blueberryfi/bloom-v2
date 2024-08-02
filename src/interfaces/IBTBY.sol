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
    event IdleCapitalIncreased(address indexed account, uint256 amount);

    event IdleCapitalDecreased(address indexed account, uint256 amount);

    event IdleCapitalWithdrawn(address indexed account, uint256 amount);
}
