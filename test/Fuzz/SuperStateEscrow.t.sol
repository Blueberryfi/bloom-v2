// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {BloomPool, IBloomPool} from "@bloom-v2/pools/BloomPool.sol";
import {SuperStatePool} from "@bloom-v2/pools/super-state/SuperStatePool.sol";
import {SuperStateEscrow} from "@bloom-v2/pools/super-state/SuperStateEscrow.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {IRedemptionIdle} from "@bloom-v2/interfaces/super-state/IRedemptionIdle.sol";
import {IUstbExtension} from "../utils/super-state/interfaces/IUstbExtension.sol";
import {SuperStateSetup} from "../utils/super-state/SuperStateSetup.t.sol";

contract SuperStateEscrowTest is SuperStateSetup {
    function testExecutePurchase(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e6);

        SuperStateEscrow escrow = _createBorrowerAccount(borrower1);
        _dealUSDC(address(ustbPool), amount);

        vm.startPrank(address(ustbPool));
        stable.approve(address(escrow), amount);
        vm.stopPrank();

        // Should revert if the borrower tries to purchase
        vm.startPrank(borrower1);
        vm.expectRevert(Errors.InvalidSender.selector);
        escrow.executePurchase(amount);
        vm.stopPrank();

        // KYC the escrow account within USTB
        _kycWithSuperState(address(escrow));

        // Calculated the expected purchase amount
        (uint256 expectedUstb,,) =
            IUstbExtension(address(billToken)).calculateSuperstateTokenOut(amount, address(stable));

        // Execute purchase
        vm.startPrank(address(ustbPool));
        uint256 ustbPurchased = escrow.executePurchase(amount);
        vm.stopPrank();

        // Verify results
        assertEq(billToken.balanceOf(address(escrow)), expectedUstb);
        assertEq(ustbPurchased, expectedUstb);
        assertEq(stable.balanceOf(address(escrow)), 0);
        assertEq(stable.balanceOf(address(ustbPool)), 0);
    }

    function testExecuteRepayment(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e6);

        SuperStateEscrow escrow = _createBorrowerAccount(borrower1);
        _dealUSDC(address(ustbPool), amount);

        vm.startPrank(address(ustbPool));
        stable.approve(address(escrow), amount);
        vm.stopPrank();

        // Should revert if the borrower tries to purchase
        vm.startPrank(borrower1);
        vm.expectRevert(Errors.InvalidSender.selector);
        escrow.executePurchase(amount);
        vm.stopPrank();

        // KYC the escrow account within USTB
        _kycWithSuperState(address(escrow));

        // Execute purchase
        vm.startPrank(address(ustbPool));
        uint256 ustbPurchased = escrow.executePurchase(amount);
        vm.stopPrank();

        // Should revert if the borrower tries to repay
        vm.startPrank(borrower1);
        vm.expectRevert(Errors.InvalidSender.selector);
        escrow.executeRepayment(ustbPurchased);
        vm.stopPrank();

        // Calculated the expected stablecoin returned amount
        (uint256 expectedStable,) = IRedemptionIdle(REDEMPTION_CONTRACT).calculateUsdcOut(ustbPurchased);

        // Execute repayment
        vm.startPrank(address(ustbPool));
        uint256 stableReturned = escrow.executeRepayment(ustbPurchased);
        vm.stopPrank();

        // Verify results
        assertEq(stable.balanceOf(address(ustbPool)), expectedStable);
        assertEq(stable.balanceOf(address(escrow)), 0);
        assertEq(billToken.balanceOf(address(escrow)), 0);
        assertEq(stableReturned, expectedStable);
    }
}
