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
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";

contract BloomUnitTest is BloomTestSetup {
    using FpMath for uint256;

    address[] public lenders;

    function setUp() public override {
        super.setUp();
    }

    function testDeployment() public {
        BloomPool newPool = new BloomPool(
            address(stable), address(billToken), address(priceFeed), initialLeverage, initialSpread, owner
        );
        assertNotEq(address(newPool), address(0));
        assertEq(newPool.rwaPriceFeed(), address(priceFeed));
    }

    function testSetPriceFeedNonOwner() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.setPriceFeed(address(1));
        assertEq(bloomPool.rwaPriceFeed(), address(priceFeed));
    }

    function testSetPriceFeedSuccess() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit IBloomPool.RwaPriceFeedSet(address(priceFeed));
        bloomPool.setPriceFeed(address(priceFeed));
    }

    function testSetPriceFeedRevert() public {
        vm.startPrank(owner);
        // Revert if price is 0
        priceFeed.setLatestRoundData(0, 0, 0, 0, 0);
        vm.expectRevert(Errors.InvalidPriceFeed.selector);
        bloomPool.setPriceFeed(address(priceFeed));

        // Revert if feed hasnt been updated in a while
        priceFeed.setLatestRoundData(0, 1, 0, 0, 0);
        vm.expectRevert(Errors.OutOfDate.selector);
        bloomPool.setPriceFeed(address(priceFeed));
    }

    function testInvalidTbyRate() public {
        vm.expectRevert(Errors.InvalidTby.selector);
        bloomPool.getRate(0);
    }

    function testNonRedeemableBorrower() public {
        vm.expectRevert(Errors.TBYNotRedeemable.selector);
        bloomPool.redeemBorrower(0);
    }

    function testNonKycMarketMaker() public {
        vm.expectRevert(Errors.KYCFailed.selector);
        lenders.push(alice);
        bloomPool.swapIn(lenders, 0);
    }
}
