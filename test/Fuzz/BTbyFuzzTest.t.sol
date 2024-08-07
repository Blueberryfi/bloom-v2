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

import {IBTBY} from "@bloom-v2/interfaces/IBTBY.sol";

contract BTbyFuzzTest is BloomTestSetup {
    address[] private addresses;
    uint256[] private amounts;

    function setUp() public override {
        super.setUp();
    }

    function testFuzzMint(uint256 idleCapital, uint256 mintAmount) public {
        vm.assume(mintAmount > 0);
        addresses.push(alice);
        amounts.push(idleCapital);

        vm.startPrank(address(bloomPool));
        // Increase the idle capital of bTby
        btby.increaseIdleCapital(addresses, amounts);
        // Mint bTby tokens
        uint256 mintReturn = btby.mint(alice, mintAmount);

        // Because idle capital is used to mint tokens first, if the mint amount is greater
        //    than or equal to the idle capital, the increase in token balance should be 0.
        if (idleCapital >= mintAmount) {
            idleCapital -= mintAmount;
            mintAmount = 0;
        } else {
            mintAmount -= idleCapital;
            idleCapital = 0;
        }

        assertEq(mintAmount, mintReturn);
        assertEq(btby.balanceOf(alice), mintAmount);
        assertEq(btby.idleCapital(alice), idleCapital);
    }

    function testFuzzBurn(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount >= burnAmount);

        vm.startPrank(address(bloomPool));
        btby.mint(alice, mintAmount);
        btby.burn(alice, burnAmount);

        assertEq(btby.balanceOf(alice), mintAmount - burnAmount);
    }

    function testFuzzIdleCapital(
        uint256 idelCap,
        uint256 withdrawAmount,
        bool maxTest
    ) public {
        vm.assume(idelCap > 0);
        vm.assume(withdrawAmount > 0);
        vm.assume(withdrawAmount < type(uint256).max);

        addresses.push(alice);
        amounts.push(idelCap);

        vm.startPrank(address(bloomPool));
        stable.mint(address(bloomPool), idelCap);
        btby.mint(alice, idelCap);

        vm.expectEmit(false, false, false, true);
        emit IBTBY.IdleCapitalIncreased(alice, idelCap);
        btby.increaseIdleCapital(addresses, amounts);

        vm.startPrank(address(alice));

        if (withdrawAmount > idelCap) {
            vm.expectRevert(Errors.InsufficientBalance.selector);
            btby.withdrawIdleCapital(withdrawAmount);
            withdrawAmount = 0;
        } else {
            vm.expectEmit(true, false, false, true);

            if (maxTest) {
                emit IBTBY.IdleCapitalWithdrawn(alice, idelCap);
                btby.withdrawIdleCapital(type(uint256).max);
                withdrawAmount = idelCap;
            } else {
                emit IBTBY.IdleCapitalWithdrawn(alice, withdrawAmount);
                btby.withdrawIdleCapital(withdrawAmount);
            }
        }

        assertEq(btby.idleCapital(alice), idelCap - withdrawAmount);
        assertEq(
            stable.balanceOf(address(bloomPool)),
            idelCap - withdrawAmount
        );
    }
}
