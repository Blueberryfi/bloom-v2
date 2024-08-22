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

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {BloomTestSetup} from "../BloomTestSetup.t.sol";

contract BloomUnitTest is BloomTestSetup {
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

    function testAsset() public view {
        assertEq(bloomPool.asset(), address(stable));
    }

    function testAssetDecimals() public view {
        assertEq(bloomPool.assetDecimals(), stable.decimals());
    }

    function testRwa() public view {
        assertEq(bloomPool.rwa(), address(billToken));
    }

    function testRwaDecimals() public view {
        assertEq(bloomPool.rwaDecimals(), billToken.decimals());
    }

    function test_Leverage() public view {
        assertEq(bloomPool.leverage(), initialLeverage);
    }

    function test_Spread() public view {
        assertEq(bloomPool.spread(), initialSpread);
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

    function testSetBorrowerWhitelist() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.whitelistBorrower(borrower, true);
        assertEq(bloomPool.isKYCedBorrower(borrower), false);

        /// Expect success if owner calls
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit BorrowerKyced(borrower, true);
        bloomPool.whitelistBorrower(borrower, true);
        assertEq(bloomPool.isKYCedBorrower(borrower), true);

        /// Successfully remove borrower from whitelist
        vm.expectEmit(true, false, false, false);
        emit BorrowerKyced(borrower, false);
        bloomPool.whitelistBorrower(borrower, false);
        assertEq(bloomPool.isKYCedBorrower(borrower), false);
    }

    function testSetMarketMakerWhitelist() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.whitelistMarketMaker(marketMaker, true);
        assertEq(bloomPool.isKYCedMarketMaker(marketMaker), false);

        /// Expect success if owner calls
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit MarketMakerKyced(marketMaker, true);
        bloomPool.whitelistMarketMaker(marketMaker, true);
        assertEq(bloomPool.isKYCedMarketMaker(marketMaker), true);

        /// Successfully remove Market Maker from whitelist
        vm.expectEmit(true, false, false, false);
        emit MarketMakerKyced(marketMaker, false);
        bloomPool.whitelistMarketMaker(marketMaker, false);
        assertEq(bloomPool.isKYCedMarketMaker(marketMaker), false);
    }

    function testSetLeverageNonOwner() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.setLeverage(0.025e18);
        assertEq(bloomPool.leverage(), initialLeverage);
    }

    function testLendOrderZero() public {
        vm.expectRevert(Errors.ZeroAmount.selector);
        bloomPool.lendOrder(0);
        assertEq(bloomPool.openDepth(), 0);
    }

    function testFillOrderZero() public {
        _createLendOrder(alice, 100e6);

        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower, true);

        vm.startPrank(borrower);
        // Should revert if amount is zero
        vm.expectRevert(Errors.ZeroAmount.selector);
        bloomPool.fillOrder(alice, 0);
        assertEq(bloomPool.matchedDepth(), 0);

        // Should revert if the order address is zero
        vm.expectRevert(Errors.ZeroAddress.selector);
        bloomPool.fillOrder(address(0), 100e6);
        assertEq(bloomPool.matchedDepth(), 0);
    }

    function testFillOrderNonKYC() public {
        _createLendOrder(alice, 100e6);

        // Should revert if amount is user is not a KYCed borrower
        vm.startPrank(bob);
        vm.expectRevert(Errors.KYCFailed.selector);
        bloomPool.fillOrder(bob, 100e6);
        assertEq(bloomPool.matchedDepth(), 0);
    }

    function testFillOrderLowBalance() public {
        _createLendOrder(alice, 100e6);

        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower, true);

        // Should revert if the borrower has insufficient balance
        vm.startPrank(borrower);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        bloomPool.fillOrder(alice, 100e6);
    }
}
