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

import {BloomTestSetup} from "../BloomTestSetup.t.sol";

contract FactoryUnitTest is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function test_FactoryCheck() public view {
        assertEq(bloomFactory.isFromFactory(address(bloomPool)), true);
        assertEq(bloomFactory.isFromFactory(owner), false);
    }

    function test_FactoryOwner() public view {
        assertEq(bloomFactory.owner(), owner);
    }

    function test_CreateBloomPoolRevert() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomFactory.createBloomPool(address(stable), address(billToken), address(priceFeed), 1e18, 200);
    }
}
