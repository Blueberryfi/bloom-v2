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
import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract LendUnitTests is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function testLendOrder() public {
        uint256 amount = 1e6;
        stable.mint(alice, amount);

        uint256 preAliceBalance = stable.balanceOf(alice);

        vm.startPrank(alice);
        stable.approve(address(bloomPool), amount);
        bloomPool.lendOrder(amount);
        vm.stopPrank();

        // Alice Balance Decreases
        assertEq(stable.balanceOf(alice), preAliceBalance - amount);
        // Bloom Pool Balance Increases
        assertEq(stable.balanceOf(address(bloomPool)), amount);

        // Order state increases
        assertEq(bloomPool.amountOpen(alice), amount);
        assertEq(bloomPool.openDepth(), amount);

        // Last Minted Id does not change
        assertEq(bloomPool.lastMintedId(), type(uint256).max);
    }

    function testLendOrderMultipleSameUser() public {
        uint256 amount = 1e6;

        // Create 2 lend orders of the same amount for the same user
        _createLendOrder(alice, amount);
        _createLendOrder(alice, amount);

        assertEq(bloomPool.amountOpen(alice), amount * 2);
        assertEq(bloomPool.openDepth(), amount * 2);
    }

    function testLendOrderMultipleDifferentUsers() public {
        uint256 amount = 1e6;

        // Create 3 lend orders of the same amount for different users
        _createLendOrder(alice, amount);
        _createLendOrder(bob, amount);
        _createLendOrder(rando, amount);

        assertEq(bloomPool.amountOpen(alice), amount);
        assertEq(bloomPool.amountOpen(bob), amount);
        assertEq(bloomPool.amountOpen(rando), amount);
        assertEq(bloomPool.openDepth(), amount * 3);
    }

    function testKillOrderSingleUser() public {
        uint256 amount = 1e6;
        _createLendOrder(alice, amount);

        // Kill the lend order
        vm.startPrank(alice);
        bloomPool.killOpenOrder(amount);
        vm.stopPrank();

        // Order state decreases
        assertEq(bloomPool.amountOpen(alice), 0);
        assertEq(bloomPool.openDepth(), 0);

        // Alice's balance increases
        assertEq(stable.balanceOf(alice), amount);
        // Bloom Pool's balance decreases
        assertEq(stable.balanceOf(address(bloomPool)), 0);
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
        bloomPool.killOpenOrder(amount1);
        vm.stopPrank();

        // Order state decreases
        assertEq(bloomPool.amountOpen(alice), 0);
        assertEq(bloomPool.openDepth(), amount2 + amount3);
        // Verify Alice's balance increases
        assertEq(stable.balanceOf(alice), amount1);

        // Kill the second lend order
        vm.startPrank(bob);
        bloomPool.killOpenOrder(amount2);
        vm.stopPrank();

        // Order state decreases
        assertEq(bloomPool.amountOpen(bob), 0);
        assertEq(bloomPool.openDepth(), amount3);
        // Verify Bob's balance increases
        assertEq(stable.balanceOf(bob), amount2);

        // Kill the third lend order
        vm.startPrank(rando);
        bloomPool.killOpenOrder(amount3);
        vm.stopPrank();

        // Order state decreases
        assertEq(bloomPool.amountOpen(rando), 0);
        assertEq(bloomPool.openDepth(), 0);
        // Verify Rando's balance increases
        assertEq(stable.balanceOf(rando), amount3);
    }

    function testLendOrderWithCustomDecimals() public {
        for (uint8 i = 2; i <= 18; i++) {
            uint256 amount = 10 ** i;

            MockERC20 token = new MockERC20("Mock token", "MTK", i);
            BloomPool pool = new BloomPool(address(token), amount, owner);

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
        bloomPool.lendOrder(0);
    }

    function testMinOrderSize() public {
        uint256 amount = bloomPool.minOrderSize() - 1;
        stable.mint(alice, amount);

        vm.startPrank(alice);
        stable.approve(address(bloomPool), amount);

        vm.expectRevert(BloomErrors.OrderBelowMinSize.selector);
        bloomPool.lendOrder(amount);
    }
}
