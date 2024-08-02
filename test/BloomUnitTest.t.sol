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
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BloomTestSetup} from "./BloomTestSetup.t.sol";

contract BloomUnitTest is BloomTestSetup {
    // Events
    event BorrowerKYCed(address indexed account);
    event MarketMakerKYCed(address indexed account);

    function setUp() public override {
        super.setUp();
    }

    function testAsset() public view {
        assertEq(bloomPool.asset(), address(stable));
    }

    function testRwa() public view {
        assertEq(bloomPool.rwa(), address(billToken));
    }

    function test_LeverageBps() public view {
        assertEq(bloomPool.leverageBps(), initialLeverageBps);
    }

    function testSetBorrowerWhitelist() public {
        /// Expect revert if not owner calls
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        bloomPool.whitelistBorrower(borrower);
        assertEq(bloomPool.isKYCedBorrower(borrower), false);

        /// Expect success if owner calls
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit BorrowerKYCed(borrower);
        bloomPool.whitelistBorrower(borrower);
        assertEq(bloomPool.isKYCedBorrower(borrower), true);
    }

    function testSetMarketMakerWhitelist() public {
        /// Expect revert if not owner calls
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        bloomPool.whitelistMarketMaker(marketMaker);
        assertEq(bloomPool.isKYCedMarketMaker(marketMaker), false);

        /// Expect success if owner calls
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit MarketMakerKYCed(marketMaker);
        bloomPool.whitelistMarketMaker(marketMaker);
        assertEq(bloomPool.isKYCedMarketMaker(marketMaker), true);
    }
}
