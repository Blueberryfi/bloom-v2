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

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";
import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {IPoolStorage} from "@bloom-v2/interfaces/IPoolStorage.sol";
import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

contract BloomFuzzTest is BloomTestSetup {
    using FpMath for uint256;
    address[] public lenders;
    address[] public filledOrders;
    uint256[] public filledAmounts;

    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower);
    }

    function testFuzz_SetLeverage(uint256 leverage) public {
        vm.startPrank(owner);

        bool changed = true;
        if (leverage >= 100e18 || leverage < 1e18) {
            vm.expectRevert(Errors.InvalidLeverage.selector);
            changed = false;
        } else {
            vm.expectEmit(false, false, false, true);
            emit IPoolStorage.LeverageSet(leverage);
        }
        bloomPool.setLeverage(leverage);

        changed
            ? assertEq(bloomPool.leverage(), leverage)
            : assertEq(bloomPool.leverage(), initialLeverage);
    }

    function testFuzz_LendOrder(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000_000e6);

        vm.startPrank(alice);
        stable.mint(alice, amount);
        stable.approve(address(bloomPool), amount);

        vm.expectEmit(true, false, false, true);
        emit IOrderbook.OrderCreated(alice, amount);
        bloomPool.lendOrder(amount);

        assertEq(bloomPool.openDepth(), amount);
        assertEq(
            ltby.balanceOf(alice, uint256(IOrderbook.OrderType.OPEN)),
            amount
        );
        assertEq(ltby.openBalance(alice), amount);
    }

    function testFuzz_FillSingleOrder(
        uint256 orderAmount,
        uint256 fillAmount
    ) public {
        orderAmount = bound(orderAmount, 1e6, 100_000_000e6);
        fillAmount = bound(fillAmount, 1e6, 100_000_000e6);

        _createLendOrder(alice, orderAmount);
        uint256 preFillOpenBalance = ltby.openBalance(alice);
        uint256 preFillDepth = bloomPool.openDepth();

        // The user is allowed to input a fill amount greater than the order amount
        uint256 expectedFillAmount = orderAmount > fillAmount
            ? fillAmount
            : orderAmount;

        uint256 expectedBorrowAmount = expectedFillAmount.divWadUp(
            initialLeverage
        );

        vm.startPrank(borrower);

        if (expectedBorrowAmount < 1e6) {
            vm.expectRevert(Errors.InvalidMatchSize.selector);
            bloomPool.fillOrder(alice, expectedFillAmount);
            return;
        }
        stable.mint(borrower, expectedBorrowAmount);
        stable.approve(address(bloomPool), expectedBorrowAmount);

        vm.expectEmit(true, true, true, true);
        emit IOrderbook.OrderFilled(
            alice,
            borrower,
            initialLeverage,
            expectedFillAmount
        );
        uint256 amountFilled = bloomPool.fillOrder(alice, expectedFillAmount);

        /*///////////////////////////////////////////////////////////////
                             Invariant Checks
        //////////////////////////////////////////////////////////////*/

        // Verify the return value of the fillOrder function is equal to the expected fill amount
        assertEq(amountFilled, expectedFillAmount);
        // Verify the state of the orderbook
        assertEq(bloomPool.matchedDepth(), expectedFillAmount);

        // Verify the state of the user's balances
        assertEq(ltby.matchedBalance(alice), expectedFillAmount);
        assertEq(ltby.openBalance(alice), orderAmount - expectedFillAmount);
        assertEq(btby.balanceOf(borrower), expectedBorrowAmount);
        assertApproxEqRel(
            ltby.matchedBalance(alice),
            btby.balanceOf(borrower).mulWadUp(initialLeverage),
            0.000001e18
        );

        // Verify the invariant that the orderbook has changed proportionally
        assertEq(
            ltby.openBalance(alice) + ltby.matchedBalance(alice),
            preFillOpenBalance
        );
        assertEq(
            bloomPool.openDepth() + bloomPool.matchedDepth(),
            preFillDepth
        );
    }

    function testFuzz_MultiOrderFill(
        uint256[3] memory orders,
        uint256 fillAmount
    ) public {
        orders[0] = bound(orders[0], 1e6, 100_000_000e6);
        orders[1] = bound(orders[1], 1e6, 100_000_000e6);
        orders[2] = bound(orders[2], 1e6, 100_000_000e6);
        fillAmount = bound(fillAmount, 1e6, 300_000_000e6);

        _createLendOrder(alice, orders[0]);
        _createLendOrder(bob, orders[1]);
        _createLendOrder(rando, orders[2]);

        lenders.push(alice);
        lenders.push(bob);
        lenders.push(rando);

        uint256 expectedFillAmount;
        for (uint256 i = 0; i < 3; i++) {
            uint256 orderDepth = orders[i];
            uint256 amountFilled = Math.min(
                orderDepth,
                fillAmount - expectedFillAmount
            );
            expectedFillAmount += amountFilled;
            orderDepth -= amountFilled;
            if (amountFilled > 0) {
                filledOrders.push(lenders[i]);
                filledAmounts.push(amountFilled);
            }
        }

        uint256 expectedBorrowAmount = expectedFillAmount.divWadUp(
            initialLeverage
        );

        vm.startPrank(borrower);

        if (expectedBorrowAmount < 1e6) {
            vm.expectRevert(Errors.InvalidMatchSize.selector);
            bloomPool.fillOrders(lenders, expectedFillAmount);
            return;
        }

        stable.mint(borrower, expectedBorrowAmount);
        stable.approve(address(bloomPool), expectedBorrowAmount);

        uint256 filled = bloomPool.fillOrders(lenders, expectedFillAmount);

        /*///////////////////////////////////////////////////////////////
                             Invariant Checks
        //////////////////////////////////////////////////////////////*/

        // Verify the return value of the fillOrder function is equal to the expected fill amount
        assertEq(filled, expectedFillAmount);
        // Verify the state of the orderbook
        assertEq(bloomPool.matchedDepth(), expectedFillAmount);
        assertEq(
            bloomPool.openDepth() + bloomPool.matchedDepth(),
            orders[0] + orders[1] + orders[2]
        );

        uint256 filledOrderCount = filledAmounts.length;

        // Verify the state of the user's balances
        assertEq(btby.balanceOf(borrower), expectedBorrowAmount);
        assertEq(ltby.matchedBalance(alice), filledAmounts[0]);
        assertEq(
            ltby.matchedBalance(bob),
            filledOrderCount > 1 ? filledAmounts[1] : 0
        );
        assertEq(
            ltby.matchedBalance(rando),
            filledOrderCount > 2 ? filledAmounts[2] : 0
        );
    }
}
