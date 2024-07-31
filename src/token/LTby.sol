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

import {ERC1155} from "@solady/tokens/ERC1155.sol";
import {FixedPointMathLib as Math} from "@solady/utils/FixedPointMathLib.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomPool} from "@bloom-v2/BloomPool.sol";

/**
 * @title BTby
 * @notice bTbys or borrowerTBYs are tokens representing a lenders's position in the Bloom v2 protocol.
 */
contract LTby is ERC1155 {
    using Math for uint256;

    /// @notice Address of the BloomPool contract.
    address private immutable _bloomPool;

    /// @notice Mapping of the user's matched orders.
    mapping(address => MatchOrder[]) private _userMatchedOrders;

    struct MatchOrder {
        address borrower;
        uint256 amount;
    }

    enum OrderType {
        OPEN, // All open orders will have an id of 0
        MATCHED, // All matched orders will have an id of 1
        LIVE // All live orders will have a blended id of 2 and the orders start timestamp
    }

    modifier onlyBloom() {
        require(msg.sender == _bloomPool, Errors.NotBloom());
        _;
    }

    constructor(address bloomPool_) {
        _bloomPool = bloomPool_;
    }

    function uri(
        uint256 id
    ) public view virtual override returns (string memory) {
        if (id == 0) {
            return "https://bloom.garden/open";
        }
        if (id == 1) {
            return "https://bloom.garden/matched";
        }
        return "https://bloom.garden/live";
    }

    /**
     * @notice Opens a new order in the orderbook.
     * @dev Only the BloomPool can call this function
     * @param amount The amount of underlying tokens being placed into the orderbook.
     */
    function open(address account, uint256 amount) external onlyBloom {
        _mint(account, OrderType.OPEN, amount, "");
    }

    /**
     * @notice Close an order in the orderbook.
     * @dev Only the BloomPool can call this function
     * @param amount The amount of underlying tokens to remove from the orderbook.
     */
    function close(
        address account,
        uint256 id,
        uint256 amount
    )
        external
        onlyBloom
        returns (address[] memory borrowers, uint256[] memory removedAmounts)
    {
        require(
            id == OrderType.OPEN || id == OrderType.MATCHED,
            Errors.InvalidOrderType()
        );
        require(balanceOf(account, id) >= amount, Errors.InsufficientDepth());

        if (id == OrderType.MATCHED) {
            MatchOrder[] storage matches = _userMatchedOrders[account];
            uint256 remainingAmount = amount;

            uint256 length = matches.length();
            for (uint256 i = length - 1; i == 0; --i) {
                uint256 matchedAmount = Math.min(
                    remainingAmount,
                    matches[i].amount
                );

                matches[i].amount -= matchedAmount;
                remainingAmount -= matchedAmount;
                borrowers.push(matches[i].borrower);
                removedAmounts.push(matchedAmount);

                if (matches[i].amount == 0) {
                    matches.pop();
                }
            }
        }

        _burn(account, id, amount);
    }

    /**
     * @notice The order is staged for the market maker.
     * @dev The staging process occurs after the order is matched by the borrower.
     * @dev Only the BloomPool can call this function.
     * @param amount The amount of underlying tokens that have been matched.
     */
    function stage(
        address account,
        address borrower,
        uint256 amount
    ) external onlyBloom {
        _burn(account, OrderType.OPEN, amount);
        _mint(account, OrderType.MATCHED, amount, "");
        _userMatchedOrders[account].push(MatchOrder(borrower, amount));
    }

    /**
     * @notice Called to redeem underlying tokens and realize yield.
     * @dev This can only occur post the maturity date of the token.
     * @dev Only the BloomPool can call this function.
     * @param amount The amount of underlying tokens that have been matched.
     */
    function redeem(uint256 amount) external onlyBloom {}

    function openBalance(address account) public view returns (uint256) {
        return balanceOf(account, OrderType.OPEN);
    }

    function matchedBalance(address account) public view returns (uint256) {
        return balanceOf(account, OrderType.MATCHED);
    }

    // 1.) How many total TBYs for a user regardless of the duration.
    function liveBalance(address account) public view returns (uint256) {
        return balanceOf(account, OrderType.LIVE);
    }

    function totalValueLocked(
        address account
    ) external view returns (uint256 amount) {
        amount += openBalance(account);
        amount += matchedBalance(account);
        amount += liveBalance(account);
    }

    function name() external view returns (string memory) {
        return "Lender TBY";
    }

    function symbol() external view returns (string memory) {
        return "lTBY";
    }
}
