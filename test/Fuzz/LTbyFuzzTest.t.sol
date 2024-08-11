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

contract LTbyFuzzTest is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function testMint(uint256 amount) public {
        vm.startPrank(address(bloomPool));
        ltby.mint(0, alice, amount);

        assertEq(ltby.balanceOf(alice, 0), amount);
        assertEq(ltby.totalSupply(0), amount);
    }

    function testBurn(uint256 startAmount, uint256 burnAmount) public {
        vm.assume(startAmount >= burnAmount);
        vm.startPrank(address(bloomPool));

        ltby.mint(0, alice, startAmount);
        ltby.burn(0, alice, burnAmount);

        uint256 expected = startAmount - burnAmount;
        assertEq(ltby.balanceOf(alice, 0), expected);
        assertEq(ltby.totalSupply(0), expected);
    }
}
