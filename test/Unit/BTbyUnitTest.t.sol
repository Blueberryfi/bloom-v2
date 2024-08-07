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

import {Test} from "forge-std/Test.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {BTby} from "@bloom-v2/token/BTby.sol";

contract BTbyUnitTest is BloomTestSetup {
    address[] private addresses;
    uint256[] private amounts;

    function setUp() public override {
        super.setUp();
    }

    function testConstructor() public {
        BTby newBtby = new BTby(address(bloomPool), 18);
        assertEq(newBtby.bloomPool(), address(bloomPool));
        assertEq(newBtby.decimals(), 18);
    }

    function testBloomPool() public view {
        assertEq(ltby.bloomPool(), address(bloomPool));
    }

    function testDecimals() public view {
        assertEq(ltby.decimals(), bloomPool.assetDecimals());
    }

    function testName() public view {
        assertEq(btby.name(), "Borrower TBY");
    }

    function testSymbol() public view {
        assertEq(btby.symbol(), "bTBY");
    }

    function testNonBloomCaller() public {
        vm.startPrank(rando);
        addresses.push(rando);
        amounts.push(1e6);

        // Revert increase idle capital
        vm.expectRevert(Errors.NotBloom.selector);
        btby.increaseIdleCapital(addresses, amounts);

        // Revert mint
        vm.expectRevert(Errors.NotBloom.selector);
        btby.mint(rando, 1e6);

        // Revert burn
        vm.expectRevert(Errors.NotBloom.selector);
        btby.burn(rando, 1e6);
    }

    function testWithdrawZero() public {
        vm.startPrank(alice);

        // Revert zero
        vm.expectRevert(Errors.ZeroAmount.selector);
        btby.withdrawIdleCapital(0);
    }

    function testWithdrawInsufficient() public {
        vm.startPrank(alice);

        // Revert insufficient
        vm.expectRevert(Errors.InsufficientBalance.selector);
        btby.withdrawIdleCapital(1e6);
    }

    function testTransferRevert() public {
        uint256 amount = 100e6;
        vm.startPrank(address(bloomPool));
        btby.mint(borrower, amount);

        // Revert transfer
        vm.expectRevert(Errors.KYCTokenNotTransferable.selector);
        btby.transfer(rando, amount);
        assertEq(btby.balanceOf(borrower), amount);
        assertEq(btby.balanceOf(rando), 0);

        // Revert transferFrom
        vm.expectRevert(Errors.KYCTokenNotTransferable.selector);
        btby.transferFrom(borrower, rando, amount);
        assertEq(btby.balanceOf(borrower), amount);
        assertEq(btby.balanceOf(rando), 0);
    }

    function testMismatchArray() public {
        addresses.push(alice);
        amounts.push(1e6);
        amounts.push(2e6);

        vm.startPrank(address(bloomPool));
        vm.expectRevert(Errors.ArrayMismatch.selector);
        btby.increaseIdleCapital(addresses, amounts);
    }
}
