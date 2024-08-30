// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {IPoolStorage} from "@bloom-v2/interfaces/IPoolStorage.sol";

contract PoolStorageUnitTest is BloomTestSetup {
    function setUp() public override {
        super.setUp();
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

    function testSetBorrowerWhitelist() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.whitelistBorrower(borrower, true);
        assertEq(bloomPool.isKYCedBorrower(borrower), false);

        /// Expect success if owner calls
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit IPoolStorage.BorrowerKyced(borrower, true);
        bloomPool.whitelistBorrower(borrower, true);
        assertEq(bloomPool.isKYCedBorrower(borrower), true);

        /// Successfully remove borrower from whitelist
        vm.expectEmit(true, false, false, false);
        emit IPoolStorage.BorrowerKyced(borrower, false);
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
        emit IPoolStorage.MarketMakerKyced(marketMaker, true);
        bloomPool.whitelistMarketMaker(marketMaker, true);
        assertEq(bloomPool.isKYCedMarketMaker(marketMaker), true);

        /// Successfully remove Market Maker from whitelist
        vm.expectEmit(true, false, false, false);
        emit IPoolStorage.MarketMakerKyced(marketMaker, false);
        bloomPool.whitelistMarketMaker(marketMaker, false);
        assertEq(bloomPool.isKYCedMarketMaker(marketMaker), false);
    }

    function testSetLeverageNonOwner() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.setLeverage(0.025e18);
        assertEq(bloomPool.leverage(), initialLeverage);
    }

    function testSetSpreadNonOwner() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.setSpread(0.95e18);
        assertEq(bloomPool.spread(), initialSpread);
    }
}
