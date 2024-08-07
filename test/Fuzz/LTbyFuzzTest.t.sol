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
import {LTby} from "@bloom-v2/token/LTby.sol";
import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

contract LTbyFuzzTest is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function testFuzzOpen(uint256 amount) public {
        vm.startPrank(address(bloomPool));
        ltby.open(alice, amount);
        assertEq(ltby.balanceOf(alice, 0), amount);
        assertEq(ltby.openBalance(alice), amount);
    }

    function testFuzzStage(uint256 openAmount, uint256 matchAmount) public {
        vm.assume(openAmount >= matchAmount);

        vm.startPrank(address(bloomPool));
        ltby.open(alice, openAmount);
        ltby.stage(alice, matchAmount);

        // Open balance should be reduced by the match amount
        assertEq(ltby.openBalance(alice), openAmount - matchAmount);
        assertEq(ltby.matchedBalance(alice), matchAmount);
    }

    function testFuzzOpenClose(uint256 openAmount, uint256 closeAmount) public {
        vm.assume(openAmount >= closeAmount);

        vm.startPrank(address(bloomPool));
        ltby.open(alice, openAmount);
        ltby.close(alice, 0, closeAmount);
        assertEq(ltby.openBalance(alice), openAmount - closeAmount);
    }

    function testFuzzMatchClose(
        uint256 openAmount,
        uint256 matchAmount,
        uint256 closeAmount
    ) public {
        vm.assume(openAmount >= matchAmount);
        vm.assume(matchAmount >= closeAmount);

        vm.startPrank(address(bloomPool));
        ltby.open(alice, openAmount);
        ltby.stage(alice, matchAmount);
        ltby.close(alice, 1, closeAmount);
        assertEq(ltby.matchedBalance(alice), matchAmount - closeAmount);
    }
}
