// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

contract OrderbookFuzzTest is BloomTestSetup {
    using FpMath for uint256;

    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower, true);
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
        assertEq(bloomPool.amountOpen(alice), amount);
    }

    function testFuzz_FillSingleOrder(uint256 orderAmount, uint256 fillAmount) public {
        orderAmount = bound(orderAmount, 1e6, 100_000_000e6);
        fillAmount = bound(fillAmount, 1e6, 100_000_000e6);

        _createLendOrder(alice, orderAmount);
        uint256 preFillOpenBalance = bloomPool.amountOpen(alice);
        uint256 preFillDepth = bloomPool.openDepth();

        // The user is allowed to input a fill amount greater than the order amount
        uint256 expectedFillAmount = orderAmount > fillAmount ? fillAmount : orderAmount;

        uint256 expectedBorrowAmount = expectedFillAmount.divWad(initialLeverage);

        vm.startPrank(borrower);
        stable.mint(borrower, expectedBorrowAmount);
        stable.approve(address(bloomPool), expectedBorrowAmount);

        vm.expectEmit(true, true, true, true);
        emit IOrderbook.OrderFilled(alice, borrower, initialLeverage, expectedFillAmount);
        (uint256 amountFilled,) = bloomPool.fillOrder(alice, expectedFillAmount);

        /*///////////////////////////////////////////////////////////////
                             Invariant Checks
        //////////////////////////////////////////////////////////////*/

        // Verify the return value of the fillOrder function is equal to the expected fill amount
        assertEq(amountFilled, expectedFillAmount);
        // Verify the state of the orderbook
        assertEq(bloomPool.matchedDepth(), expectedFillAmount);

        // Verify the state of the orderbook
        assertEq(bloomPool.amountOpen(alice), orderAmount - expectedFillAmount);
        assertEq(bloomPool.amountMatched(alice), expectedFillAmount);

        // Verify the invariant that the orderbook has changed proportionally
        assertEq(bloomPool.amountOpen(alice) + bloomPool.amountMatched(alice), preFillOpenBalance);
        assertEq(bloomPool.openDepth() + bloomPool.matchedDepth(), preFillDepth);

        // Verify the matched order struct
        assertEq(bloomPool.matchedOrderCount(alice), 1);
        IOrderbook.MatchOrder memory aliceMatch = bloomPool.matchedOrder(alice, 0);
        assertEq(aliceMatch.borrower, borrower);
        assertEq(aliceMatch.bCollateral, expectedBorrowAmount);
        assertEq(aliceMatch.lCollateral, expectedFillAmount);
        assertApproxEqRel(uint256(aliceMatch.lCollateral).divWadUp(aliceMatch.bCollateral), initialLeverage, 0.0001e18);
    }

    function testFuzz_MultiOrderFill(uint256[3] memory orders, uint256 fillAmount) public {
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
            uint256 amountFilled = Math.min(orderDepth, fillAmount - expectedFillAmount);
            expectedFillAmount += amountFilled;
            orderDepth -= amountFilled;
            if (amountFilled > 0) {
                filledOrders.push(lenders[i]);
                filledAmounts.push(amountFilled);
            }
        }

        uint256 expectedBorrowAmount = expectedFillAmount.divWadUp(initialLeverage);

        vm.startPrank(borrower);
        stable.mint(borrower, expectedBorrowAmount);
        stable.approve(address(bloomPool), expectedBorrowAmount);

        (uint256 filled,) = bloomPool.fillOrders(lenders, expectedFillAmount);

        /*///////////////////////////////////////////////////////////////
                             Invariant Checks
        //////////////////////////////////////////////////////////////*/

        // Verify the return value of the fillOrder function is equal to the expected fill amount
        assertEq(filled, expectedFillAmount);
        // Verify the state of the orderbook
        assertEq(bloomPool.matchedDepth(), expectedFillAmount);
        assertEq(bloomPool.openDepth() + bloomPool.matchedDepth(), orders[0] + orders[1] + orders[2]);

        uint256 filledOrderCount = filledAmounts.length;

        // Verify the state of the user's orders
        assertEq(bloomPool.amountMatched(alice), filledAmounts[0]);
        assertEq(bloomPool.amountMatched(bob), filledOrderCount > 1 ? filledAmounts[1] : 0);
        assertEq(bloomPool.amountMatched(rando), filledOrderCount > 2 ? filledAmounts[2] : 0);
    }

    function testFuzz_KillOpenOrder(uint256 orderSize, uint256 killSize) public {
        orderSize = bound(orderSize, 1e6, 500_000_000e6);
        killSize = bound(killSize, 1e6, 500_000_000e6);

        _createLendOrder(alice, orderSize);
        vm.startPrank(alice);

        if (killSize > orderSize) {
            vm.expectRevert(Errors.InsufficientDepth.selector);
            bloomPool.killOpenOrder(killSize);
            return;
        } else {
            vm.expectEmit(true, false, false, true);
            emit IOrderbook.OpenOrderKilled(alice, killSize);
            bloomPool.killOpenOrder(killSize);
        }

        assertEq(bloomPool.amountOpen(alice), orderSize - killSize);
        assertEq(bloomPool.openDepth(), orderSize - killSize);
        assertEq(stable.balanceOf(alice), killSize);
        assertEq(bloomPool.matchedOrderCount(alice), 0);
    }

    function testFuzz_KillMatchedOrder(uint256 orderSize, uint256 killSize) public {
        orderSize = bound(orderSize, 1e6, 500_000_000e6);
        killSize = bound(killSize, uint256(1e6).mulWadUp(initialLeverage), 500_000_000e6);
        vm.assume(orderSize >= killSize);

        // Open order
        _createLendOrder(alice, orderSize);

        // Match the order
        uint256 borrowerAmount = orderSize.divWad(initialLeverage);
        vm.startPrank(borrower);
        stable.mint(borrower, borrowerAmount);
        stable.approve(address(bloomPool), borrowerAmount);
        bloomPool.fillOrder(alice, orderSize);

        // Kill the matched order
        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true);
        emit IOrderbook.MatchOrderKilled(alice, borrower, killSize);
        bloomPool.killMatchOrder(killSize);

        assertEq(bloomPool.amountMatched(alice), orderSize - killSize);
        assertEq(bloomPool.matchedDepth(), orderSize - killSize);
        assertEq(stable.balanceOf(alice), killSize);
        assertEq(bloomPool.idleCapital(borrower), killSize.divWad(initialLeverage));
    }

    function testFuzz_KillMultiOrder(uint256[3] memory orders, uint256 killAmount) public {
        orders[0] = bound(orders[0], 100e6, 100_000_000e6);
        orders[1] = bound(orders[1], 100e6, 100_000_000e6);
        orders[2] = bound(orders[2], 100e6, 100_000_000e6);
        killAmount = bound(killAmount, 1e6, 300_000_000e6);
        vm.assume(orders[0] + orders[1] + orders[2] >= killAmount);

        address borrower2 = makeAddr("borrower2");
        address borrower3 = makeAddr("borrower3");

        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower2, true);
        bloomPool.whitelistBorrower(borrower3, true);

        stable.mint(borrower, orders[0].divWadUp(initialLeverage));
        stable.mint(borrower2, orders[1].divWadUp(initialLeverage));
        stable.mint(borrower3, orders[2].divWadUp(initialLeverage));

        // Create 3 filled orders with alice w/ 3 different borrowers
        _createLendOrder(alice, orders[0]);
        vm.startPrank(borrower);
        stable.approve(address(bloomPool), orders[0].divWadUp(initialLeverage));
        bloomPool.fillOrder(alice, orders[0]);
        _createLendOrder(alice, orders[1]);
        vm.startPrank(borrower2);
        stable.approve(address(bloomPool), orders[1].divWadUp(initialLeverage));
        bloomPool.fillOrder(alice, orders[1]);
        _createLendOrder(alice, orders[2]);
        vm.startPrank(borrower3);
        stable.approve(address(bloomPool), orders[2].divWadUp(initialLeverage));
        bloomPool.fillOrder(alice, orders[2]);

        // Kill the orders
        vm.startPrank(alice);
        uint256 amountKilled = bloomPool.killMatchOrder(killAmount);

        uint256 borrowersKilled;
        if (amountKilled >= orders[2] && amountKilled < orders[2] + orders[1]) {
            borrowersKilled = 1;
        } else if (amountKilled >= orders[2] + orders[1] && amountKilled < orders[0] + orders[1] + orders[2]) {
            borrowersKilled = 2;
        } else if (amountKilled >= orders[0] + orders[1] + orders[2]) {
            borrowersKilled = 3;
        } else {
            borrowersKilled = 0;
        }

        assertEq(bloomPool.amountMatched(alice), orders[0] + orders[1] + orders[2] - amountKilled);
        assertEq(bloomPool.matchedDepth(), orders[0] + orders[1] + orders[2] - amountKilled);
        assertEq(stable.balanceOf(alice), amountKilled);

        if (borrowersKilled == 0) {
            assertEq(bloomPool.idleCapital(borrower3), killAmount.divWad(initialLeverage));
            assertEq(bloomPool.matchedOrder(alice, 2).lCollateral, orders[2] - amountKilled);
        } else if (borrowersKilled == 1) {
            assertEq(bloomPool.idleCapital(borrower3), orders[2].divWad(initialLeverage));
            assertEq(bloomPool.matchedOrder(alice, 1).lCollateral, orders[2] + orders[1] - amountKilled);
        } else if (borrowersKilled == 2) {
            assertEq(bloomPool.idleCapital(borrower3), orders[2].divWad(initialLeverage));
            assertEq(bloomPool.idleCapital(borrower2), orders[1].divWad(initialLeverage));
            assertEq(bloomPool.matchedOrder(alice, 0).lCollateral, orders[0] + orders[1] + orders[2] - amountKilled);
        } else if (borrowersKilled == 3) {
            assertEq(bloomPool.idleCapital(borrower3), orders[2].divWad(initialLeverage));
            assertEq(bloomPool.idleCapital(borrower2), orders[1].divWad(initialLeverage));
            assertEq(bloomPool.idleCapital(borrower), orders[0].divWad(initialLeverage));
        }
    }

    function testFuzz_WithdrawIdleCapital(uint256 orderSize, uint256 killAmount, uint256 withdrawAmount) public {
        orderSize = bound(orderSize, 1e6, 1_000_000e6);
        killAmount = bound(killAmount, 1e6, orderSize);
        vm.assume(withdrawAmount <= killAmount.divWad(initialLeverage));

        _createLendOrder(alice, orderSize);
        vm.startPrank(borrower);

        uint256 borrowAmount = orderSize.divWadUp(initialLeverage);
        stable.mint(borrower, borrowAmount);
        stable.approve(address(bloomPool), borrowAmount);
        bloomPool.fillOrder(alice, orderSize);

        vm.startPrank(alice);
        bloomPool.killMatchOrder(killAmount);

        uint256 idleCapital = bloomPool.idleCapital(borrower);
        uint256 expectedIdleCapital = killAmount.divWad(initialLeverage);
        assertEq(idleCapital, expectedIdleCapital);

        uint256 borrowBalanceBefore = stable.balanceOf(borrower);

        vm.startPrank(borrower);

        if (withdrawAmount == 0) {
            vm.expectRevert(Errors.ZeroAmount.selector);
        } else {
            vm.expectEmit(true, false, false, true);
            emit IOrderbook.IdleCapitalWithdrawn(borrower, withdrawAmount);
        }
        bloomPool.withdrawIdleCapital(withdrawAmount);

        assertEq(bloomPool.idleCapital(borrower), expectedIdleCapital - withdrawAmount);
        assertEq(stable.balanceOf(borrower), borrowBalanceBefore + withdrawAmount);
    }

    function testFuzz_FillOrderWithIdleCapital(uint256 orderSize) public {
        orderSize = bound(orderSize, 1e6, 1_000_000e6);

        _createLendOrder(alice, orderSize);

        uint256 borrowAmount = orderSize.divWadUp(initialLeverage);

        vm.startPrank(borrower);
        stable.mint(borrower, borrowAmount);
        stable.approve(address(bloomPool), borrowAmount);
        bloomPool.fillOrder(alice, orderSize);

        vm.startPrank(alice);
        bloomPool.killMatchOrder(orderSize);
        _createLendOrder(alice, orderSize);

        // Scaled down the other way
        uint256 expectedUsedIdleCapital = orderSize.divWad(initialLeverage);
        // Add dust to the borrowers balance
        stable.mint(borrower, 1);

        vm.startPrank(borrower);
        stable.approve(address(bloomPool), 1);
        vm.expectEmit(true, false, false, true);
        emit IOrderbook.IdleCapitalDecreased(borrower, expectedUsedIdleCapital);
        bloomPool.fillOrder(alice, orderSize);

        uint256 idleCapital = bloomPool.idleCapital(borrower);
        assertEq(idleCapital, 0);
    }
}
