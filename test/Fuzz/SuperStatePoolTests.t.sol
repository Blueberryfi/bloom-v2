// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {BloomPool, IBloomPool} from "@bloom-v2/pools/BloomPool.sol";
import {SuperStatePool} from "@bloom-v2/pools/super-state/SuperStatePool.sol";
import {SuperStateEscrow} from "@bloom-v2/pools/super-state/SuperStateEscrow.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {IRedemptionIdle} from "@bloom-v2/interfaces/super-state/IRedemptionIdle.sol";
import {IUstbExtension} from "../utils/super-state/interfaces/IUstbExtension.sol";
import {SuperStateSetup} from "../utils/super-state/SuperStateSetup.t.sol";
import {console2} from "forge-std/console2.sol";

contract SuperStatePoolTests is SuperStateSetup {
    using FpMath for uint256;

    function testBorrowSingleLenderSingleBorrower(uint256 amount, uint256 borrowAmount) public {
        amount = bound(amount, 1e6, 10_000_000e6);
        borrowAmount = bound(borrowAmount, 1e6, amount);
        uint256 leftoverStable = amount - borrowAmount;

        // Ensure that stable amounts left in alices open orders is greater than 1 USDC
        vm.assume(leftoverStable >= 1e6);

        _initBorrowers();
        _createLendOrder(alice, amount);
        lenders.push(alice);

        uint256 borrowerCollateral = borrowAmount.divWadUp(ustbPool.leverage());
        uint256 totalCollateral = borrowerCollateral + borrowAmount;

        // Calculated the expected purchase amount
        (uint256 expectedUstb,,) =
            IUstbExtension(address(billToken)).calculateSuperstateTokenOut(totalCollateral, address(stable));

        _dealUSDC(borrower1, borrowerCollateral);

        address account = ustbPool.borrowersAccount(borrower1);

        vm.startPrank(borrower1);
        stable.approve(address(ustbPool), borrowAmount);
        bloomRouter.borrow(lenders, address(ustbPool), borrowAmount);
        vm.stopPrank();

        // Validate token balances
        assertEq(stable.balanceOf(borrower1), 0);
        assertEq(stable.balanceOf(address(ustbPool)), 0);
        assertEq(stable.balanceOf(address(bloomRouter)), leftoverStable);
        assertEq(billToken.balanceOf(account), expectedUstb);

        // Validate Router State
        assertEq(bloomRouter.amountOpen(alice), leftoverStable);
        assertEq(bloomRouter.openDepth(), leftoverStable);
        assertEq(bloomRouter.lastMintedId(), 0);
        assertEq(bloomRouter.poolFromTbyId(0), address(ustbPool));
        assertEq(bloomRouter.lastMintedId(), ustbPool.lastMintedId());

        // Validate Pool State
        assertEq(ustbPool.borrowerAmount(borrower1, 0), borrowerCollateral);
        assertEq(ustbPool.totalBorrowed(0), borrowerCollateral);

        BloomPool.TbyCollateral memory collateral = ustbPool.tbyCollateral(0);
        assertEq(collateral.assetAmount, 0);
        assertEq(collateral.rwaAmount, expectedUstb);
        assertEq(ustbPool.ustbPurchased(borrower1, 0), expectedUstb);
    }

    function testBorrowSingleLenderMultipleBorrowers(uint256 amount, uint256 borrow1Amount, uint256 borrow2Amount) public {
        amount = bound(amount, 10e6, 10_000_000e6);
        borrow1Amount = bound(borrow1Amount, 1e6, amount - 1e6);
        borrow2Amount = bound(borrow2Amount, 1e6, amount - borrow1Amount);
        uint256 leftoverStable = amount - borrow1Amount - borrow2Amount;
        vm.assume(leftoverStable >= 1e6 || leftoverStable == 0);

        _initBorrowers();
        _createLendOrder(alice, amount);
        lenders.push(alice);

        uint256 borrower1Collateral = borrow1Amount.divWadUp(ustbPool.leverage());
        uint256 borrower2Collateral = borrow2Amount.divWadUp(ustbPool.leverage());
        uint256 totalCollateral1 = borrow1Amount + borrower1Collateral;
        uint256 totalCollateral2 = borrow2Amount + borrower2Collateral;

        // Calculated the expected purchase amount
        (uint256 expectedUstb1,,) =
            IUstbExtension(address(billToken)).calculateSuperstateTokenOut(totalCollateral1, address(stable));
        (uint256 expectedUstb2,,) =
            IUstbExtension(address(billToken)).calculateSuperstateTokenOut(totalCollateral2, address(stable));

        _dealUSDC(borrower1, borrower1Collateral);
        _dealUSDC(borrower2, borrower2Collateral);

        address account1 = ustbPool.borrowersAccount(borrower1);
        address account2 = ustbPool.borrowersAccount(borrower2);

        vm.startPrank(borrower1);
        stable.approve(address(ustbPool), borrow1Amount);
        bloomRouter.borrow(lenders, address(ustbPool), borrow1Amount);
        vm.stopPrank();

        vm.startPrank(borrower2);
        stable.approve(address(ustbPool), borrow2Amount);
        bloomRouter.borrow(lenders, address(ustbPool), borrow2Amount);
        vm.stopPrank();

        // Validate token balances
        assertEq(stable.balanceOf(borrower1), 0);
        assertEq(stable.balanceOf(borrower2), 0);
        assertEq(stable.balanceOf(address(ustbPool)), 0);
        assertEq(stable.balanceOf(address(bloomRouter)), leftoverStable);
        assertEq(billToken.balanceOf(account1), expectedUstb1);
        assertEq(billToken.balanceOf(account2), expectedUstb2);

        // Validate pool state
        assertEq(ustbPool.borrowerAmount(borrower1, 0), borrower1Collateral);
        assertEq(ustbPool.borrowerAmount(borrower2, 0), borrower2Collateral);

        uint256 totalBorrowed = borrower1Collateral + borrower2Collateral;
        assertEq(ustbPool.totalBorrowed(0), totalBorrowed);

        BloomPool.TbyCollateral memory collateral = ustbPool.tbyCollateral(0);
        assertEq(collateral.assetAmount, 0);
        assertEq(collateral.rwaAmount, expectedUstb1 + expectedUstb2);
        assertEq(ustbPool.ustbPurchased(borrower1, 0), expectedUstb1);
        assertEq(ustbPool.ustbPurchased(borrower2, 0), expectedUstb2);
    }

    function testBorrowMultipleLenders(uint256 amount1, uint256 amount2, uint256 amount3, uint256 borrowAmount) public {
        amount1 = bound(amount1, 1e6, 1_000_000e6);
        amount2 = bound(amount2, 1e6, 1_000_000e6);
        amount3 = bound(amount3, 1e6, 1_000_000e6);
        uint256 totalAmount = amount1 + amount2 + amount3;
        borrowAmount = bound(borrowAmount, amount1 + amount2 + 1e6, totalAmount);
        vm.assume(totalAmount - borrowAmount >= 1e6);

        console2.log("borrowAmount", borrowAmount);

        _initBorrowers();
        _createLendOrder(alice, amount1);
        _createLendOrder(bob, amount2);
        _createLendOrder(rando, amount3);
        lenders.push(alice);
        lenders.push(bob);
        lenders.push(rando);

        uint256 borrowerCollateral = borrowAmount.divWadUp(ustbPool.leverage());
        console2.log("borrowerCollateral", borrowerCollateral);
        uint256 totalCollateral = borrowerCollateral + borrowAmount;

        _dealUSDC(borrower1, borrowerCollateral);

        address account = ustbPool.borrowersAccount(borrower1);

        vm.startPrank(borrower1);
        stable.approve(address(ustbPool), borrowerCollateral);
        bloomRouter.borrow(lenders, address(ustbPool), borrowAmount);
        vm.stopPrank();

        (uint256 expectedUstb,,) = IUstbExtension(address(billToken)).calculateSuperstateTokenOut(totalCollateral, address(stable));

        // Validate token balances
        assertEq(stable.balanceOf(borrower1), 0);
        assertEq(stable.balanceOf(address(ustbPool)), 0);
        assertEq(stable.balanceOf(address(bloomRouter)), totalAmount - borrowAmount);
        assertEq(billToken.balanceOf(account), expectedUstb);

        // Validate open order state
        assertEq(bloomRouter.amountOpen(alice), 0);
        assertEq(bloomRouter.amountOpen(bob), 0);
        assertEq(bloomRouter.amountOpen(rando), totalAmount - borrowAmount);

        // Validate Pool State
        assertEq(ustbPool.borrowerAmount(borrower1, 0), borrowerCollateral);
        assertEq(ustbPool.totalBorrowed(0), borrowerCollateral);

        BloomPool.TbyCollateral memory collateral = ustbPool.tbyCollateral(0);
        assertEq(collateral.assetAmount, 0);
        assertEq(collateral.rwaAmount, expectedUstb);
        assertEq(ustbPool.ustbPurchased(borrower1, 0), expectedUstb);
    }

    function _initBorrowers() internal {
        SuperStateEscrow borrower1Account = _createBorrowerAccount(borrower1);
        _kycWithSuperState(address(borrower1Account));
        SuperStateEscrow borrower2Account = _createBorrowerAccount(borrower2);
        _kycWithSuperState(address(borrower2Account));
    }
}
