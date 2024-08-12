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

import {PoolStorage} from "@bloom-v2/PoolStorage.sol";
import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";
import "forge-std/console2.sol";

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

    /// @notice Mapping of users to their open order amount.
    mapping(address => uint256) private _userOpenOrder;

    /// @notice Mapping of the user's matched orders.
    mapping(address => MatchOrder[]) private _userMatchedOrders;

    /// @notice Mapping of borrower's to the amount of idle capital they have.
    mapping(address => uint256) private _idleCapital;

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(address asset_, address rwa_, uint256 initLeverage) PoolStorage(asset_, rwa_) {
        _leverage = initLeverage;
    }

    /*///////////////////////////////////////////////////////////////
                            Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IOrderbook
    function lendOrder(uint256 amount) external {
        require(amount > 0, Errors.ZeroAmount());

        _openDepth += amount;
        _userOpenOrder[msg.sender] += amount;

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amount);
        emit OrderCreated(msg.sender, amount);
    }

    /// @inheritdoc IOrderbook
    function fillOrder(address account, uint256 amount) external KycBorrower returns (uint256 filled) {
        filled = _fillOrder(account, amount);
        _depositBorrower(filled);
    }

    /// @inheritdoc IOrderbook
    function fillOrders(address[] memory accounts, uint256 amount) external KycBorrower returns (uint256 filled) {
        uint256 len = accounts.length;
        for (uint256 i = 0; i != len; ++i) {
            uint256 size = _fillOrder(accounts[i], amount);
            amount -= size;
            filled += size;
            if (amount == 0) break;
        }
        _depositBorrower(filled);
    }

    /// @inheritdoc IOrderbook
    function killOpenOrder(uint256 amount) external {
        uint256 orderDepth = _userOpenOrder[msg.sender];
        require(amount <= orderDepth, Errors.InsufficientDepth());

        _userOpenOrder[msg.sender] -= amount;
        _openDepth -= amount;

        IERC20(_asset).safeTransfer(msg.sender, amount);
        emit OrderKilled(msg.sender, amount);
    }

    /// @inheritdoc IOrderbook
    function killMatchOrder(uint256 amount) external returns (uint256 totalRemoved) {
        // if the order is already matched we have to account for the borrower's who filled the order.
        // If you kill a match order and there are multiple borrowers, the order will be closed in a LIFO manner.
        // For each borrow the full amount that was matched must be removed from the order.
        // In the event that the match is not fully removed, that match will not be removed.
        MatchOrder[] storage matches = _userMatchedOrders[msg.sender];
        uint256 remainingAmount = amount;

        uint256 length = matches.length;
        for (uint256 i = length; i != 0; --i) {
            uint256 index = i - 1;

            if (remainingAmount >= matches[index].amount) {
                remainingAmount -= matches[index].amount;
                totalRemoved += matches[index].amount;

                uint256 borrowerAmount = matches[index].amount.divWadUp(matches[index].leverage);
                _idleCapital[matches[index].borrower] += borrowerAmount;

                matches.pop();
            } else {
                break;
            }
        }
        _matchedDepth -= totalRemoved;
        IERC20(_asset).safeTransfer(msg.sender, totalRemoved);

        emit OrderKilled(msg.sender, totalRemoved);
    }

    /// @inheritdoc IOrderbook
    function withdrawIdleCapital(uint256 amount) external {
        address account = msg.sender;
        require(amount > 0, Errors.ZeroAmount());

        uint256 idleFunds = _idleCapital[account];

        if (amount == type(uint256).max) {
            amount = idleFunds;
        } else {
            require(idleFunds >= amount, Errors.InsufficientBalance());
        }

        _idleCapital[account] -= amount;
        IERC20(_asset).safeTransfer(account, amount);

        emit IdleCapitalWithdrawn(account, amount);
    }

    /**
     * @notice Fills an order with a specified amount of underlying assets
     * @param account The address of the order to fill
     * @param amount Amount of underlying assets of the order to fill
     */
    function _fillOrder(address account, uint256 amount) internal returns (uint256 filled) {
        require(account != address(0), Errors.ZeroAddress());
        require(amount > 0, Errors.ZeroAmount());

        uint256 orderDepth = _userOpenOrder[account];

        filled = Math.min(orderDepth, amount);
        _openDepth -= filled;
        _matchedDepth += filled;
        _userOpenOrder[account] -= filled;

        _userMatchedOrders[account].push(MatchOrder(msg.sender, _leverage, filled));

        emit OrderFilled(account, msg.sender, _leverage, filled);
    }

    /**
     * @notice Deposits the leveraged matched amount of underlying assets to the borrower
     * @dev The borrower supplies less than the matched amount of underlying assets based on the leverage
     * @param amount Amount of underlying assets matched by the borrower
     */
    function _depositBorrower(uint256 amount) internal {
        uint256 borrowAmount = amount.divWadUp(_leverage);

        require(borrowAmount >= 1e6, Errors.InvalidMatchSize());
        require(IERC20(_asset).balanceOf(msg.sender) >= borrowAmount, Errors.InsufficientBalance());

        borrowAmount = _utilizeIdleCapital(msg.sender, borrowAmount);
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), borrowAmount);
    }

    function _utilizeIdleCapital(address account, uint256 amount) internal returns (uint256) {
        uint256 idleUsed = Math.min(_idleCapital[account], amount);
        if (idleUsed > 0) {
            _idleCapital[account] -= idleUsed;
            amount -= idleUsed;
            emit IdleCapitalDecreased(account, idleUsed);
        }
        return amount;
    }

    /**
     * @notice Closes the matched order for the user
     * @dev Orders are closed in a LIFO manner
     * @param amount The amount of underlying assets to close the matched order
     * @return totalRemoved The amount for each borrower that was removed.
     */
    function _closeMatchOrder(uint256 amount) internal returns (uint256 totalRemoved) {
        MatchOrder[] storage matches = _userMatchedOrders[msg.sender];
        uint256 remainingAmount = amount;

        uint256 length = matches.length;
        for (uint256 i = length; i != 0; --i) {
            uint256 index = i - 1;

            if (remainingAmount >= matches[index].amount) {
                remainingAmount -= matches[index].amount;
                totalRemoved += matches[index].amount;

                uint256 borrowerAmount = matches[index].amount.divWadUp(matches[index].leverage);
                _idleCapital[matches[index].borrower] += borrowerAmount;

                matches.pop();
            } else {
                break;
            }
        }
    }

    /// @inheritdoc IOrderbook
    function leverage() external view override returns (uint256) {
        return _leverage;
    }

    /// @inheritdoc IOrderbook
    function openDepth() external view returns (uint256) {
        return _openDepth;
    }

    /// @inheritdoc IOrderbook
    function matchedDepth() external view returns (uint256) {
        return _matchedDepth;
    }

    /// @inheritdoc IOrderbook
    function amountOpen(address account) external view returns (uint256) {
        return _userOpenOrder[account];
    }

    /// @inheritdoc IOrderbook
    function amountMatched(address account) external view returns (uint256 amount) {
        uint256 len = _userMatchedOrders[account].length;
        for (uint256 i = 0; i != len; ++i) {
            amount += _userMatchedOrders[account][i].amount;
        }
    }

    /// @inheritdoc IOrderbook
    function matchedOrder(address account, uint256 index) external view returns (MatchOrder memory) {
        return _userMatchedOrders[account][index];
    }

    /// @inheritdoc IOrderbook
    function matchedOrderCount(address account) external view returns (uint256) {
        return _userMatchedOrders[account].length;
    }

    /// @inheritdoc IOrderbook
    function idleCapital(address account) public view returns (uint256) {
        return _idleCapital[account];
    }
}
