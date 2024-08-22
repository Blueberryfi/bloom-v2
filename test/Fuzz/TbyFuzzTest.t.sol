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

import {BloomTestSetup} from "../BloomTestSetup.t.sol";

contract TbyFuzzTest is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function testMint(uint256 amount) public {
        vm.startPrank(address(bloomPool));
        tby.mint(0, alice, amount);

        assertEq(tby.balanceOf(alice, 0), amount);
        assertEq(tby.totalSupply(0), amount);
    }

    function testBurn(uint256 startAmount, uint256 burnAmount) public {
        vm.assume(startAmount >= burnAmount);
        vm.startPrank(address(bloomPool));

        tby.mint(0, alice, startAmount);

        tby.burn(0, alice, burnAmount);

        uint256 expected = startAmount - burnAmount;
        assertEq(tby.balanceOf(alice, 0), expected);
        assertEq(tby.totalSupply(0), expected);
    }
}
