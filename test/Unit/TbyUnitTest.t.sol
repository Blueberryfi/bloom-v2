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

import {Test} from "forge-std/Test.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {Tby} from "@bloom-v2/token/Tby.sol";
import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

contract TbyUnitTest is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function testConstructor() public {
        Tby newTby = new Tby(address(bloomPool), 18);
        assertEq(newTby.bloomPool(), address(bloomPool));
        assertEq(newTby.decimals(), 18);
    }

    function testBloomPool() public view {
        assertEq(tby.bloomPool(), address(bloomPool));
    }

    function testDecimals() public view {
        assertEq(tby.decimals(), bloomPool.assetDecimals());
    }

    function testName() public view {
        assertEq(tby.name(), "Term Bound Yield");
    }

    function testSymbol() public view {
        assertEq(tby.symbol(), "TBY");
    }

    function testUri() public view {
        assertEq(tby.uri(1), "https://bloom.garden/live");
    }

    function testNonBloomCaller() public {
        vm.startPrank(rando);

        // Revert open
        vm.expectRevert(Errors.NotBloom.selector);
        tby.mint(0, alice, 1e6);
    }
}
