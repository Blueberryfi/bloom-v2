// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title IRedemptionIdle
 * @author Superstate
 * @notice The ```IRedemptionIdle``` interface is used to interact with Superstate's RedemptionIdle contract.
 * @dev https://github.com/superstateinc/onchain-redemptions/blob/master/src/RedemptionIdle.sol
 */
interface IRedemptionIdle {
    /// @notice The ```redeem``` function allows users to redeem SUPERSTATE_TOKEN for USDC at the current oracle price
    /// @dev Will revert if oracle data is stale or there is not enough USDC in the contract
    /// @param superstateTokenInAmount The amount of SUPERSTATE_TOKEN to redeem
    function redeem(uint256 superstateTokenInAmount) external;

    /// @notice The ```maxUstbRedemptionAmount``` function returns the maximum amount of SUPERSTATE_TOKEN that can be redeemed based on the amount of USDC in the contract
    /// @return superstateTokenAmount The maximum amount of SUPERSTATE_TOKEN that can be redeemed
    /// @return usdPerUstbChainlinkRaw The price used to calculate the superstateTokenAmount
    function maxUstbRedemptionAmount()
        external
        view
        returns (uint256 superstateTokenAmount, uint256 usdPerUstbChainlinkRaw);

    /**
     * @notice The ```calculateUsdcOut``` function calculates the total amount of USDC you'll receive for redeeming Superstate tokens
     * @param superstateTokenInAmount The amount of Superstate tokens to redeem
     * @return usdcOutAmount The amount of USDC received for redeeming superstateTokenInAmount
     * @return usdPerUstbChainlinkRaw The raw chainlink price used in calculation
     */
    function calculateUsdcOut(uint256 superstateTokenInAmount)
        external
        view
        returns (uint256 usdcOutAmount, uint256 usdPerUstbChainlinkRaw);
}
