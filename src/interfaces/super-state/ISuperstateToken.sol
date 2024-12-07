// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

/**
 * @title ISuperstateToken
 * @author Superstate
 * @notice The ```ISuperstateToken``` interface is used to interact with Superstate's SuperstateToken contract.
 * @dev https://github.com/superstateinc/ustb/blob/main/src/SuperstateToken.sol
 */
interface ISuperstateToken is IERC20 {
    /**
     * @notice The ```subscribe``` function takes in stablecoins and mints SuperstateToken in the proper amount for the msg.sender depending on the current Net Asset Value per Share.
     * @param inAmount The amount of the stablecoin in
     * @param stablecoin The address of the stablecoin to calculate with
     */
    function subscribe(uint256 inAmount, address stablecoin) external;
}
