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

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

import {BloomPool} from "@bloom-v2/pools/BloomPool.sol";

import {MockAMM} from "./MockAMM.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockPriceFeed} from "./MockPriceFeed.sol";

/**
 * @title MockBloomPool
 * @notice An extremely simplified mock Bloom Pool for testing purposes.
 */
contract MockBloomPool is BloomPool {
    using SafeERC20 for IERC20;
    using FpMath for uint256;

    MockAMM internal immutable _amm;
    MockPriceFeed internal immutable _priceFeed;

    constructor(
        string memory name_,
        string memory symbolSuffix_,
        address router,
        address rwa_,
        address priceFeed,
        uint8 assetDecimals_,
        uint256 initLeverage,
        uint256 initSpread,
        address owner_
    ) BloomPool(name_, symbolSuffix_, router, rwa_, assetDecimals_, initLeverage, initSpread, owner_) {
        _amm = new MockAMM();
        _priceFeed = MockPriceFeed(priceFeed);
    }

    /**
     * @notice Purchases the RWA tokens with the underlying asset collateral and stores them within the contract.
     * @dev This function needs to be implemented by the specific protocol that is being used to purchase the RWA tokens.
     *      Integration instructions:
     *         1. Approval has already been set on the BloomPool for the borrow module to spend. This is where the source of funds are coming from.
     *         2. The borrow module will need to swap the underlying asset collateral for the RWA token.
     *         3. RWA token should be held within the borrow module's contract.
     * @param totalCollateral The total amount of collateral being swapped in.
     * @return The amount of RWA tokens purchased.
     */
    function _purchaseRwa(
        address,
        /*borrower*/
        uint256 totalCollateral
    ) internal override returns (uint256) {
        IERC20(_asset).forceApprove(address(_amm), totalCollateral);

        uint256 scaledCollateral = totalCollateral * (10 ** (18 - _assetDecimals));
        uint256 scaledRwaAmount = scaledCollateral.divWad(_getRwaPrice());
        uint256 rwaAmount = scaledRwaAmount / (10 ** (18 - _rwaDecimals));

        _amm.swap(address(_asset), address(_rwa), totalCollateral, rwaAmount);
        return rwaAmount;
    }

    /**
     * @notice Repays the RWA tokens to the issuer in exchange for the underlying asset collateral.
     * @dev This function needs to be implemented by the specific protocol that is being used to repay the RWA tokens.
     *      Integration instructions:
     *         1. Source of funds are coming from the Borrow Module.
     *         2. The borrow module will need to swap the RWA token for the underlying asset collateral.
     *         3. Underlying asset should be held within the borrow module's contract.
     * @param amount The amount of RWA tokens being repaid.
     * @return The amount of underlying asset collateral being received.
     */
    function _repayRwa(uint256 amount) internal override returns (uint256) {
        IERC20(_rwa).forceApprove(address(_amm), amount);
        uint256 scaledAmount = amount * (10 ** (18 - _rwaDecimals));
        uint256 scaledAssetAmount = _getRwaPrice().mulWad(scaledAmount);
        uint256 assetAmount = scaledAssetAmount / (10 ** (18 - _assetDecimals));
        _amm.swap(address(_rwa), address(_asset), amount, assetAmount);
        return assetAmount;
    }

    /**
     * @notice Returns the amount of RWA tokens that are being swapped out of the pool.
     * @dev The out of the box implementation returns all of the RWA tokens that are currently held within the contract.
     *      Depending on the specific protocol that is being used to purchase the RWA tokens, this function may need to be overridden.
     * @param tbyId The id of the TBY to get the RWA swap amount for.
     * @return The amount of RWA tokens being swapped out.
     */
    function _getRwaSwapAmount(uint256 tbyId) internal view override returns (uint256) {
        return _idToCollateral[tbyId].rwaAmount;
    }

    /**
     * @notice Returns the price of the RWA token in 18 decimals.
     */
    function _getRwaPrice() internal view virtual override returns (uint256) {
        (, int256 price,,,) = _priceFeed.latestRoundData();
        uint256 feedDecimals = _priceFeed.decimals();
        uint256 scaledPrice = uint256(price) * 10 ** (18 - feedDecimals);
        return scaledPrice;
    }
}
