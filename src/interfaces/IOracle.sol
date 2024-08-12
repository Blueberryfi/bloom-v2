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
 * @title IOracle
 * @notice Interface for Bloom V2's Oracle
 */
interface IOracle {
    /**
     * @notice Returns the price of the asset in USD.
     * @param asset The address of the asset to get the price of.
     */
    function getPrice(address asset) external view returns (uint256);

    /**
     * @notice Returns the rate per second acrual of a lTBY.
     * @param lTBy The address of the lTBY.
     * @return The rate per second of the lTBY scaled to 1e18.
     */
    function tbyRatePerSecond(address lTBy) external view returns (uint256);
}
