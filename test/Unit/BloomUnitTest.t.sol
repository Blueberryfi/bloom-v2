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
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

contract BloomUnitTest is BloomTestSetup {
    using FpMath for uint256;

    // Events
    event BorrowerKyced(address indexed account, bool isKyced);
    event MarketMakerKyced(address indexed account, bool isKyced);

    function setUp() public override {
        super.setUp();
    }

    function testDeployment() public {
        BloomPool newPool = new BloomPool(
            address(stable), address(billToken), address(priceFeed), initialLeverage, initialSpread, owner
        );
        assertNotEq(address(newPool), address(0));
    }

    function testSetPriceFeedNonOwner() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.setPriceFeed(address(1));
        assertEq(bloomPool.rwaPriceFeed(), address(priceFeed));
    }
}
