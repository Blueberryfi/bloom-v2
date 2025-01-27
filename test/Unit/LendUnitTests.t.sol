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

import {BloomErrors} from "@bloom-v2/helpers/BloomErrors.sol";
import {BloomRouter} from "@bloom-v2/BloomRouter.sol";
import {IBloomRouter} from "@bloom-v2/interfaces/IBloomRouter.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract LendUnitTests is BloomTestSetup {
    function setUp() public {
        _setUp(address(0), address(0));
    }

    function testLendOrder() public {
        uint256 amount = 1e6;
        stable.mint(alice, amount);

        uint256 preAliceBalance = stable.balanceOf(alice);

        vm.startPrank(alice);
        stable.approve(address(bloomRouter), amount);
        bloomRouter.lendOrder(amount);
        vm.stopPrank();

        // Alice Balance Decreases
        assertEq(stable.balanceOf(alice), preAliceBalance - amount);
        // Bloom Pool Balance Increases
        assertEq(stable.balanceOf(address(bloomRouter)), amount);

        // Order state increases
        assertEq(bloomRouter.amountOpen(alice), amount);
        assertEq(bloomRouter.openDepth(), amount);

        // Last Minted Id does not change
        assertEq(bloomRouter.lastMintedId(), type(uint256).max);
    }

    function testLendOrderMultipleSameUser() public {
        uint256 amount = 1e6;

        // Create 2 lend orders of the same amount for the same user
        _createLendOrder(alice, amount);
        _createLendOrder(alice, amount);

        assertEq(bloomRouter.amountOpen(alice), amount * 2);
        assertEq(bloomRouter.openDepth(), amount * 2);
    }

    function testLendOrderMultipleDifferentUsers() public {
        uint256 amount = 1e6;

        // Create 3 lend orders of the same amount for different users
        _createLendOrder(alice, amount);
        _createLendOrder(bob, amount);
        _createLendOrder(rando, amount);

        assertEq(bloomRouter.amountOpen(alice), amount);
        assertEq(bloomRouter.amountOpen(bob), amount);
        assertEq(bloomRouter.amountOpen(rando), amount);
        assertEq(bloomRouter.openDepth(), amount * 3);
    }

    function testKillOrderSingleUser() public {
        uint256 amount = 1e6;
        _createLendOrder(alice, amount);

        // Kill the lend order
        vm.startPrank(alice);
        bloomRouter.killOpenOrder(amount);
        vm.stopPrank();

        // Order state decreases
        assertEq(bloomRouter.amountOpen(alice), 0);
        assertEq(bloomRouter.openDepth(), 0);

        // Alice's balance increases
        assertEq(stable.balanceOf(alice), amount);
        // Bloom Pool's balance decreases
        assertEq(stable.balanceOf(address(bloomRouter)), 0);
    }

    function testKillOrderMultipleUsers() public {
        uint256 amount1 = 1e6;
        uint256 amount2 = 2e6;
        uint256 amount3 = 3e6;

        // Create 3 lend orders of different amounts for different users
        _createLendOrder(alice, amount1);
        _createLendOrder(bob, amount2);
        _createLendOrder(rando, amount3);

        // Kill the first lend order
        vm.startPrank(alice);
        bloomRouter.killOpenOrder(amount1);
        vm.stopPrank();

        // Order state decreases
        assertEq(bloomRouter.amountOpen(alice), 0);
        assertEq(bloomRouter.openDepth(), amount2 + amount3);
        // Verify Alice's balance increases
        assertEq(stable.balanceOf(alice), amount1);

        // Kill the second lend order
        vm.startPrank(bob);
        bloomRouter.killOpenOrder(amount2);
        vm.stopPrank();

        // Order state decreases
        assertEq(bloomRouter.amountOpen(bob), 0);
        assertEq(bloomRouter.openDepth(), amount3);
        // Verify Bob's balance increases
        assertEq(stable.balanceOf(bob), amount2);

        // Kill the third lend order
        vm.startPrank(rando);
        bloomRouter.killOpenOrder(amount3);
        vm.stopPrank();

        // Order state decreases
        assertEq(bloomRouter.amountOpen(rando), 0);
        assertEq(bloomRouter.openDepth(), 0);
        // Verify Rando's balance increases
        assertEq(stable.balanceOf(rando), amount3);
    }

    function testLendOrderWithCustomDecimals() public {
        for (uint8 i = 2; i <= 18; i++) {
            uint256 amount = 10 ** i;

            MockERC20 token = new MockERC20("Mock token", "MTK", i);
            BloomRouter pool = new BloomRouter(address(token), amount, owner);

            token.mint(alice, amount);

            // Open the lend order
            vm.startPrank(alice);
            token.approve(address(pool), amount);
            pool.lendOrder(amount);
            vm.stopPrank();

            assertEq(pool.amountOpen(alice), amount);
            assertEq(pool.openDepth(), amount);

            assertEq(token.balanceOf(address(pool)), amount);
            assertEq(token.balanceOf(alice), 0);

            // Kill the lend order
            vm.startPrank(alice);
            pool.killOpenOrder(amount);
            vm.stopPrank();

            assertEq(pool.amountOpen(alice), 0);
            assertEq(pool.openDepth(), 0);

            assertEq(token.balanceOf(alice), amount);
            assertEq(token.balanceOf(address(pool)), 0);
        }
    }

    function testZeroAmount() public {
        vm.expectRevert(BloomErrors.ZeroAmount.selector);
        bloomRouter.lendOrder(0);
    }

    function testMinOrderSize() public {
        uint256 amount = bloomRouter.minOrderSize() - 1;
        stable.mint(alice, amount);

        vm.startPrank(alice);
        stable.approve(address(bloomRouter), amount);

        vm.expectRevert(BloomErrors.OrderBelowMinSize.selector);
        bloomRouter.lendOrder(amount);
    }

    function testUpdateMinOrderSize() public {
        // Should revert if not owner
        vm.startPrank(rando);
        vm.expectRevert();
        bloomRouter.setMinOrderSize(2e6);
        vm.stopPrank();

        vm.startPrank(owner);

        // Should revert if minOrderSize is 0
        vm.expectRevert(Errors.ZeroAmount.selector);
        bloomRouter.setMinOrderSize(0);

        // Should set the min order size successfully
        bloomRouter.setMinOrderSize(2e6);
        vm.stopPrank();

        assertEq(bloomRouter.minOrderSize(), 2e6);
    }
}
