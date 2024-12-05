// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Ownable2Step, Ownable} from "@openzeppelin/access/Ownable2Step.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {IBloomOracle} from "@bloom-v2/interfaces/IBloomOracle.sol";

/**
 * @title BloomOracle
 * @author Euler Labs (https://www.eulerlabs.com/)
 *         Modified by Bloom Protocol (https://bloom.garden/)
 * @notice Default Oracle resolver for Bloom lending products.
 * @dev This contract is modified from EulerRouter to support Bloom's lending products.
 *      Change Log:
 *         1. Unneeded functions from the EulerRouter is removed.
 *         2. Removed ERC4626 vault related logic.
 *         3. Removed fallback oracle logic.
 *         4. Some functions are renamed to fit Bloom's naming conventions.
 * @dev Supports Oracle Adapters built on top of the ERC-7726
 */
contract BloomOracle is IBloomOracle, Ownable2Step {
    /**
     * @notice Mapping of PriceOracle addresses per asset pair.
     * @dev The keys are lexicographically sorted (asset0 < asset1).
     */
    mapping(address asset0 => mapping(address asset1 => address oracle)) internal oracles;

    constructor(address _owner) Ownable(_owner) {
        if (_owner == address(0)) revert Errors.ZeroAddress();
    }

    /**
     * @notice Configure a PriceOracle to resolve base/quote and quote/base.
     * @param base The address of the base token.
     * @param quote The address of the quote token.
     * @param oracle The address of the PriceOracle to resolve the pair.
     */
    function setConfig(address base, address quote, address oracle) external onlyOwner {
        // This case is handled by `resolveOracle`.
        if (base == quote) revert Errors.InvalidConfiguration();
        (address asset0, address asset1) = _sort(base, quote);
        oracles[asset0][asset1] = oracle;
        emit ConfigSet(asset0, asset1, oracle);
    }

    /// @inheritdoc IBloomOracle
    function getQuote(uint256 inAmount, address base, address quote) external view override returns (uint256) {
        address oracle = getConfiguredOracle(base, quote);
        if (base == quote) return inAmount;
        return IBloomOracle(oracle).getQuote(inAmount, base, quote);
    }

    /**
     * @notice Get the PriceOracle configured for base/quote.
     * @param base The address of the base token.
     * @param quote The address of the quote token.
     * @return The configured `PriceOracle` for the pair or `address(0)` if no oracle is configured.
     */
    function getConfiguredOracle(address base, address quote) public view returns (address) {
        (address asset0, address asset1) = _sort(base, quote);
        return oracles[asset0][asset1];
    }

    /**
     * @notice Lexicographically sort two addresses.
     * @param assetA One of the assets in the pair.
     * @param assetB The other asset in the pair.
     * @return The address first in lexicographic order.
     * @return The address second in lexicographic order.
     */
    function _sort(address assetA, address assetB) internal pure returns (address, address) {
        return assetA < assetB ? (assetA, assetB) : (assetB, assetA);
    }
}
