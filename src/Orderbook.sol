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
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amount);
        _lTby.open(msg.sender, amount);

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

    /**
     * @notice Fills an order with a specified amount of underlying assets
     * @param account The address of the order to fill
     * @param amount Amount of underlying assets of the order to fill
     */
    function _fillOrder(address account, uint256 amount) internal returns (uint256 filled) {
        require(account != address(0), Errors.ZeroAddress());
        require(amount > 0, Errors.ZeroAmount());

        uint256 orderDepth = _lTby.openBalance(account);

        filled = Math.min(orderDepth, amount);
        _openDepth -= filled;
        _matchedDepth += filled;

        _lTby.stage(account, filled);
        _userMatchedOrders[account].push(MatchOrder(msg.sender, _leverage, amount));

        emit OrderFilled(account, msg.sender, _leverage, filled);
    }

    /**
     * @notice Deposits the leveraged matched amount of underlying assets to the borrower
     * @dev The borrower supplies less than the matched amount of underlying assets based on the leverage
     * @param amountMatched Amount of underlying assets matched by the borrower
     */
    function _depositBorrower(uint256 amountMatched) internal {
        uint256 borrowAmount = amountMatched.divWadUp(_leverage);

        require(borrowAmount >= 1e6, Errors.InvalidMatchSize());
        require(IERC20(_asset).balanceOf(msg.sender) >= borrowAmount, Errors.InsufficientBalance());

        uint256 amountMinted = _bTby.mint(msg.sender, borrowAmount);
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), amountMinted);
    }

    /// @inheritdoc IOrderbook
    function killOrder(uint256 id, uint256 amount) external returns (uint256 amountKilled) {
        uint256 orderDepth = _lTby.balanceOf(msg.sender, id);
        require(id == uint256(OrderType.OPEN) || id == uint256(OrderType.MATCHED), Errors.InvalidOrderType());
        require(amount <= orderDepth, Errors.InsufficientDepth());

        // if the order is already matched we have to account for the borrower's who filled the order.
        // If you kill a match order and there are multiple borrowers, the order will be closed in a LIFO manner.
        // For each borrow the full amount that was matched must be removed from the order.
        // In the event that the match is not fully removed, that match will not be removed.
        if (id == uint256(OrderType.MATCHED)) {
            (address[] memory borrowers, uint256[] memory removedAmounts, uint256 removedAmount) =
                _closeMatchOrder(amount);
            amountKilled = removedAmount;
            _matchedDepth -= amountKilled;
            _bTby.increaseIdleCapital(borrowers, removedAmounts);
        } else {
            amountKilled = amount;
            _openDepth -= amountKilled;
        }

        _lTby.close(msg.sender, id, amountKilled);

        IERC20(_asset).safeTransfer(msg.sender, amountKilled);
        emit OrderKilled(msg.sender, id, amountKilled);
    }

    /**
     * @notice Closes the matched order for the user
     * @dev Orders are closed in a LIFO manner
     * @param amount The amount of underlying assets to close the matched order
     * @return borrowers The borrowers who's match was removed.
     * @return removedAmounts The amount for each borrower that was removed.
     */
    function _closeMatchOrder(uint256 amount)
        internal
        returns (address[] memory borrowers, uint256[] memory removedAmounts, uint256 totalRemoved)
    {
        MatchOrder[] storage matches = _userMatchedOrders[msg.sender];
        uint256 remainingAmount = amount;

        uint256 matchLength = matches.length;
        borrowers = new address[](matchLength);
        removedAmounts = new uint256[](matchLength);

        uint256 matchesRemoved;
        for (uint256 i = matchLength; i != 0; --i) {
            uint256 index = i - 1;

            if (remainingAmount >= matches[index].amount) {
                remainingAmount -= matches[index].amount;
                totalRemoved += matches[index].amount;

                borrowers[matchesRemoved] = matches[index].borrower;
                removedAmounts[matchesRemoved] = matches[index].amount.divWadUp(matches[index].leverage);

                matchesRemoved++;
                matches.pop();
            } else {
                break;
            }
        }

        // Reduce the length of the borrowers and removedAmounts arrays if not all orders were removed
        if (matchesRemoved != matchLength) {
            uint256 difference = matchLength - matchesRemoved;
            assembly {
                mstore(borrowers, sub(mload(borrowers), difference))
                mstore(removedAmounts, sub(mload(removedAmounts), difference))
            }
        }
    }

    /**
     * @notice Transfer asset to an address
     * @dev Only the borrower TBY can call this function
     * @param to Address that is receiving the asset
     * @param amount Amount of asset to transfer
     */
    function transferAsset(address to, uint256 amount) external onlyBTby {
        IERC20(_asset).safeTransfer(to, amount);
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
    function matchOrder(address account, uint256 index) external view returns (MatchOrder memory) {
        return _userMatchedOrders[account][index];
    }

    /// @inheritdoc IOrderbook
    function matchOrderCount(address account) external view returns (uint256) {
        return _userMatchedOrders[account].length;
    }
}
