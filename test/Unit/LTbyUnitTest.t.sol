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

    function testOpenUri() public view {
        assertEq(ltby.uri(uint256(IOrderbook.OrderType.OPEN)), "https://bloom.garden/open");
    }

    function testMatchedUri() public view {
        assertEq(ltby.uri(uint256(IOrderbook.OrderType.MATCHED)), "https://bloom.garden/matched");
    }

    function testLiveUri() public view {
        assertEq(ltby.uri(uint256(IOrderbook.OrderType.LIVE)), "https://bloom.garden/live");
    }

    function testNonBloomCaller() public {
        vm.startPrank(rando);

        // Revert open
        vm.expectRevert(Errors.NotBloom.selector);
        ltby.open(alice, 1e6);

        // Revert stage
        vm.expectRevert(Errors.NotBloom.selector);
        ltby.stage(alice, 1e6);

        // Revert close
        vm.expectRevert(Errors.NotBloom.selector);
        ltby.close(alice, 0, 1e6);
    }
}
