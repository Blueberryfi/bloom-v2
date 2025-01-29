// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {AggregatorV3Interface} from "@chainlink/shared/interfaces/AggregatorV3Interface.sol";

interface ISuperStateOracle is AggregatorV3Interface{
    /// @notice Represents a checkpoint for a Net Asset Value per Share (NAV/S) for a specific Superstate Business Day
    struct NavsCheckpoint {
        /// @notice The timestamp of 5pm ET of the Superstate Business day for this NAV/S
        uint64 timestamp;
        /// @notice The timestamp from which this NAV/S price can be used for realtime pricing
        uint64 effectiveAt;
        /// @notice The NAV/S at this checkpoint
        uint128 navs;
    }

    /// @notice Adds a single NAV/S checkpoint
    /// @dev This function can only be called by the contract owner. Automated systems should only use this and not `addCheckpoints`
    /// @param timestamp The timestamp of the checkpoint
    /// @param effectiveAt The time from which this checkpoint becomes effective
    /// @param navs The Net Asset Value per Share for this checkpoint
    /// @param shouldOverrideEffectiveAt Flag to allow overriding an existing pending effective timestamp
    function addCheckpoint(uint64 timestamp, uint64 effectiveAt, uint128 navs, bool shouldOverrideEffectiveAt) external;
}
