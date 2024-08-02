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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FixedPointMathLib as Math} from "@solady/utils/FixedPointMathLib.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

import {PoolStorage} from "@bloom-v2/PoolStorage.sol";
import {LTby} from "@bloom-v2/token/LTby.sol";
import {BTby} from "@bloom-v2/token/BTby.sol";

/**
 * @title Orderbook
 * @notice An orderbook matching lender and borrower orders for RWA loans.
 */
abstract contract Orderbook is IOrderbook, PoolStorage {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*///////////////////////////////////////////////////////////////
                            Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Addresss of the lTby token
    LTby private _lTby;

    /// @notice Addresss of the bTby token
    BTby private _bTby;

    /// @notice Current total depth of unfilled orders.
    uint256 private _depth;

    /// @notice Mapping of the borrowers leverage on matching orders.
    uint256 private _leverageBps;

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(
        address asset_,
        address rwa_,
        uint256 initLeverageBps
    ) PoolStorage(asset_, rwa_) {
        _leverageBps = initLeverageBps;

        // Initialize the lTby and bTby tokens
        _lTby = new LTby(address(this));
        _bTby = new BTby(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                            Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrderbook
    function lendOrder(uint256 amount) external {
        require(amount > 0, Errors.ZeroAmount());

        _depth += amount;
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amount);
        _lTby.open(msg.sender, amount);

        emit OrderCreated(msg.sender, amount);
    }

    /// @inheritdoc IOrderbook
    function fillOrder(
        address order,
        uint256 amount
    ) external KycBorrower returns (uint256 filled) {
        require(amount > 0, Errors.ZeroAmount());

        filled = _fillOrder(order, amount);
        _depositBorrower(filled);
    }

    /// @inheritdoc IOrderbook
    function fillOrders(
        address[] memory accounts,
        uint256 amount
    ) external KycBorrower returns (uint256 filled) {
        require(amount > 0, Errors.ZeroAmount());

        uint256 len = accounts.length;
        for (uint256 i = 0; i != len; ++i) {
            uint256 size = _fillOrder(accounts[i], amount);
            amount -= size;
            filled += size;
        }
        _depositBorrower(filled);
    }

    function _fillOrder(
        address account,
        uint256 amount
    ) internal returns (uint256 filled) {
        uint256 orderDepth = _lTby.openBalance(account);
        filled = Math.min(orderDepth, amount);
        _depth -= filled;
        _lTby.stage(account, msg.sender, filled);
        emit OrderFilled(account, msg.sender, filled);
    }

    /// @inheritdoc IOrderbook
    function killOrder(uint256 id, uint256 amount) external {
        uint256 orderDepth = _lTby.balanceOf(msg.sender, id);
        require(amount <= orderDepth, Errors.InsufficientDepth());
        _depth -= amount;
        (address[] memory borrowers, uint256[] memory amounts) = _lTby.close(
            msg.sender,
            id,
            amount
        );
        _bTby.increaseIdleCapital(borrowers, amounts);
        IERC20(_asset).safeTransfer(msg.sender, amount);
        emit OrderKilled(msg.sender, id, amount);
    }

    /// @inheritdoc IOrderbook
    function setLeverageBps(uint256 leverageBps_) external {
        require(
            leverageBps_ > 0 && leverageBps_ <= 100,
            Errors.InvalidLeverage()
        );
        _leverageBps = leverageBps_;
    }

    /// @inheritdoc IOrderbook
    function leverageBps() external view override returns (uint256) {
        return _leverageBps;
    }

    function _depositBorrower(uint256 amountMatched) internal {
        uint256 borrowAmount = (amountMatched * _leverageBps) / 10000;
        require(
            IERC20(_asset).balanceOf(msg.sender) >= borrowAmount,
            Errors.InsufficientBalance()
        );
        uint256 amountMinted = _bTby.mint(msg.sender, borrowAmount);
        IERC20(_asset).safeTransferFrom(
            msg.sender,
            address(this),
            amountMinted
        );
    }
}
