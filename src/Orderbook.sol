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

    /// @notice Current total depth of unfilled orders.
    uint256 private _openDepth;

    /// @notice Current total depth of matched orders.
    uint256 private _matchedDepth;

    /// @notice Mapping of the user's matched orders.
    mapping(address => MatchOrder[]) private _userMatchedOrders;

    /*///////////////////////////////////////////////////////////////
                              Modifier    
    //////////////////////////////////////////////////////////////*/
    modifier onlyBTby() {
        require(msg.sender == address(_bTby), Errors.NotBloom());
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(
        address asset_,
        address rwa_,
        uint256 initLeverage
    ) PoolStorage(asset_, rwa_) {
        _leverage = initLeverage;
    }

    /*///////////////////////////////////////////////////////////////
                            Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrderbook
    function lendOrder(uint256 amount) external {
        require(amount > 0, Errors.ZeroAmount());

        _openDepth += amount;
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amount);
        _lTby.open(msg.sender, amount);

        emit OrderCreated(msg.sender, amount);
    }

    /// @inheritdoc IOrderbook
    function fillOrder(
        address order,
        uint256 amount
    ) external KycBorrower returns (uint256 filled) {
        filled = _fillOrder(order, amount);
        _depositBorrower(filled);
    }

    /// @inheritdoc IOrderbook
    function fillOrders(
        address[] memory accounts,
        uint256 amount
    ) external KycBorrower returns (uint256 filled) {
        uint256 len = accounts.length;
        for (uint256 i = 0; i != len; ++i) {
            uint256 size = _fillOrder(accounts[i], amount);
            amount -= size;
            filled += size;
            if (amount == 0) break;
        }
        _depositBorrower(filled);
    }

    function _fillOrder(
        address account,
        uint256 amount
    ) internal returns (uint256 filled) {
        require(account != address(0), Errors.ZeroAddress());
        require(amount > 0, Errors.ZeroAmount());

        uint256 orderDepth = _lTby.openBalance(account);

        filled = Math.min(orderDepth, amount);
        _openDepth -= filled;
        _matchedDepth += filled;

        _lTby.stage(account, filled);
        _userMatchedOrders[account].push(
            MatchOrder(msg.sender, _leverage, amount)
        );

        emit OrderFilled(account, msg.sender, _leverage, filled);
    }

    /// @inheritdoc IOrderbook
    function killOrder(uint256 id, uint256 amount) external {
        uint256 orderDepth = _lTby.balanceOf(msg.sender, id);
        require(
            id == uint256(OrderType.OPEN) || id == uint256(OrderType.MATCHED),
            Errors.InvalidOrderType()
        );
        require(amount <= orderDepth, Errors.InsufficientDepth());

        if (id == uint256(OrderType.MATCHED)) {
            (
                address[] memory borrowers,
                uint256[] memory removedAmounts
            ) = _closeMatchOrder(amount);
            _matchedDepth -= amount;
            _bTby.increaseIdleCapital(borrowers, removedAmounts);
        }

        _lTby.close(msg.sender, id, amount);

        IERC20(_asset).safeTransfer(msg.sender, amount);
        emit OrderKilled(msg.sender, id, amount);
    }

    function _closeMatchOrder(
        uint256 amount
    )
        internal
        returns (address[] memory borrowers, uint256[] memory removedAmounts)
    {
        MatchOrder[] storage matches = _userMatchedOrders[msg.sender];
        uint256 remainingAmount = amount;

        uint256 startIndex = matches.length - 1;
        for (uint256 i = startIndex; i == 0; --i) {
            uint256 matchedAmount = Math.min(
                remainingAmount,
                matches[i].amount
            );

            matches[i].amount -= matchedAmount;
            remainingAmount -= matchedAmount;
            borrowers[i] = matches[i].borrower;
            removedAmounts[i] = matchedAmount;

            if (matches[i].amount == 0) {
                matches.pop();
            }
        }
    }

    /// @inheritdoc IOrderbook
    function leverage() external view override returns (uint256) {
        return _leverage;
    }

    function transferAsset(address to, uint256 amount) external onlyBTby {
        IERC20(_asset).safeTransfer(to, amount);
    }

    function _depositBorrower(uint256 amountMatched) internal {
        uint256 borrowAmount = amountMatched.divWadUp(_leverage);

        require(borrowAmount >= 1e6, Errors.InvalidMatchSize());
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

    function openDepth() external view returns (uint256) {
        return _openDepth;
    }

    function matchedDepth() external view returns (uint256) {
        return _matchedDepth;
    }
}
