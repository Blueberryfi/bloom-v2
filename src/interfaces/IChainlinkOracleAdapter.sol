// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.27;

import {IOracleAdapter} from "./IOracleAdapter.sol";

interface IChainlinkOracleAdapter is IOracleAdapter {
    /*///////////////////////////////////////////////////////////////
                              Structs
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct to store the price feed for an RWA.
     * @param priceFeed The address of the price feed.
     * @param updateInterval The interval in seconds at which the price feed should be updated.
     * @param decimals The number of decimals the price feed returns.
     */
    struct RwaPriceFeed {
        address priceFeed;
        uint64 updateInterval;
        uint8 decimals;
    }

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the price feed information for an RWA.
     * @param token Address of the token to get the price feed for.
     * @return The RwaPriceFeed struct for the RWA.
     */
    function priceFeed(address token) external view returns (RwaPriceFeed memory);
}
