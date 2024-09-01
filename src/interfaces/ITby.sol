// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.26;

/**
 * @title ITby
 * @notice Interface for the Lender's Term Bound Yield Token
 */
interface ITby {
    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a user mints Tby.
     * @param account The address of the account that minted the Tby.
     * @param id The unique identifier of the Tby.
     * @param amount The amount of Tby minted.
     */
    event Mint(address indexed account, uint256 id, uint256 amount);

    /**
     * @notice Emitted when a user burns Tby.
     * @param account The address of the account that burned the Tby.
     * @param id The unique identifier of the Tby.
     * @param amount The amount of Tby burned.
     */
    event Burn(address indexed account, uint256 id, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

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
     * @notice Total Supply of the TBY.
     * @param id The id of the token.
     */
    function totalSupply(uint256 id) external view returns (uint256);
}
