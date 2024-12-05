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

interface IBloomOracle {
    /*///////////////////////////////////////////////////////////////
                              Events
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Configure a PriceOracle to resolve an asset pair.
     * @dev If `oracle` is `address(0)` then the configuration was removed.
     *  The keys are lexicographically sorted (asset0 < asset1).
     * @param asset0 The address first in lexicographic order.
     * @param asset1 The address second in lexicographic order.
     * @param oracle The address of the PriceOracle that resolves the pair.
     */
    event ConfigSet(address indexed asset0, address indexed asset1, address indexed oracle);

    /*///////////////////////////////////////////////////////////////
                              Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice @notice One-sided price: How much quote token you would get for inAmount of base token, assuming no price spread.
     * @param inAmount The amount of `base` to convert.
     * @param base The token that is being priced.
     * @param quote  The token that is the unit of account.
     * @return The amount of `quote` that is equivalent to `inAmount` of `base`.
     */
    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256);
}
