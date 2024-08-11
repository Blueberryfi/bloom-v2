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

contract LTbyUnitTest is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function testConstructor() public {
        LTby newLtby = new LTby(address(bloomPool), 18);
        assertEq(newLtby.bloomPool(), address(bloomPool));
        assertEq(newLtby.decimals(), 18);
    }

    function testBloomPool() public view {
        assertEq(ltby.bloomPool(), address(bloomPool));
    }

    function testDecimals() public view {
        assertEq(ltby.decimals(), bloomPool.assetDecimals());
    }

    function testName() public view {
        assertEq(ltby.name(), "Lender TBY");
    }

    function testSymbol() public view {
        assertEq(ltby.symbol(), "lTBY");
    }

    function testUri() public view {
        assertEq(ltby.uri(1), "https://bloom.garden/live");
    }

    function testNonBloomCaller() public {
        vm.startPrank(rando);

        // Revert open
        vm.expectRevert(Errors.NotBloom.selector);
        ltby.mint(0, alice, 1e6);
    }
}
