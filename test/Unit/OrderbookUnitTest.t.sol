// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FixedPointMathLib as Math} from "@solady/utils/FixedPointMathLib.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

contract OrderbookUnitTest is BloomTestSetup {
    using Math for uint256;

    function setUp() public override {
        super.setUp();
    }

    function testLendOrderZero() public {
        vm.expectRevert(Errors.ZeroAmount.selector);
        bloomPool.lendOrder(0);
        assertEq(bloomPool.openDepth(), 0);
    }

    function testFillOrderZero() public {
        _createLendOrder(alice, 100e6);

        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower, true);

        vm.startPrank(borrower);
        // Should revert if amount is zero
        vm.expectRevert(Errors.ZeroAmount.selector);
        bloomPool.fillOrder(alice, 0);
        assertEq(bloomPool.matchedDepth(), 0);

        // Should revert if the order address is zero
        vm.expectRevert(Errors.ZeroAddress.selector);
        bloomPool.fillOrder(address(0), 100e6);
        assertEq(bloomPool.matchedDepth(), 0);
    }

    function testFillOrderNonKYC() public {
        _createLendOrder(alice, 100e6);

        // Should revert if amount is user is not a KYCed borrower
        vm.startPrank(bob);
        vm.expectRevert(Errors.KYCFailed.selector);
        bloomPool.fillOrder(bob, 100e6);
        assertEq(bloomPool.matchedDepth(), 0);
    }

    function testFillOrderLowBalance() public {
        _createLendOrder(alice, 100e6);

        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower, true);

        // Should revert if the borrower has insufficient balance
        vm.startPrank(borrower);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        bloomPool.fillOrder(alice, 100e6);
    }

    function testKillBorrowerOrder() public {
        _createLendOrder(alice, 100e6);

        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower, true);

        _fillOrder(alice, 100e6);

        uint256 borrowerPreBalance = stable.balanceOf(borrower);
        uint256 alicePreBalance = stable.balanceOf(alice);

        IOrderbook.MatchOrder memory matchedOrder = bloomPool.matchedOrder(alice, 0);

        vm.startPrank(borrower);
        bloomPool.killBorrowerMatch(alice);

        IOrderbook.MatchOrder memory postCancelMatchedOrder = bloomPool.matchedOrder(alice, 0);

        // Validate pool state
        assertEq(bloomPool.matchedDepth(), 0);
        assertEq(bloomPool.openDepth(), 100e6);
        assertEq(postCancelMatchedOrder.bCollateral, 0);
        assertEq(postCancelMatchedOrder.lCollateral, 0);
        assertEq(postCancelMatchedOrder.borrower, borrower);

        // Validate balances
        assertEq(stable.balanceOf(borrower), borrowerPreBalance + matchedOrder.bCollateral);
        assertEq(stable.balanceOf(alice), alicePreBalance);
    }

    function testKillBorrowerOrderNoMatch() public {
        _createLendOrder(alice, 100e6);

        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower, true);

        _fillOrder(alice, 100e6);

        // Kill the match order
        vm.startPrank(borrower);
        bloomPool.killBorrowerMatch(alice);

        // Try to kill the match order again to steal funds
        vm.expectRevert(Errors.MatchOrderNotFound.selector);
        bloomPool.killBorrowerMatch(alice);
    }

    function testMaxWithdrawIdleCapital() public {
        _createLendOrder(alice, 100e6);

        vm.prank(owner);
        bloomPool.whitelistBorrower(borrower, true);

        vm.startPrank(borrower);
        uint256 borrowAmount = uint256(100e6).divWadUp(initialLeverage);
        stable.approve(address(bloomPool), borrowAmount);
        stable.mint(borrower, borrowAmount);
        bloomPool.fillOrder(alice, 100e6);

        vm.startPrank(alice);
        bloomPool.killMatchOrder(100e6);

        uint256 idleCapital = bloomPool.idleCapital(borrower);

        uint256 borrowerBalanceBefore = stable.balanceOf(borrower);

        vm.startPrank(borrower);
        vm.expectEmit(true, false, false, true);
        emit IOrderbook.IdleCapitalWithdrawn(borrower, idleCapital);
        bloomPool.withdrawIdleCapital(type(uint256).max);

        assertEq(stable.balanceOf(borrower), borrowerBalanceBefore + idleCapital);
    }
}
