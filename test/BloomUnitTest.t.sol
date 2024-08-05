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
import {BloomTestSetup} from "./BloomTestSetup.t.sol";

contract BloomUnitTest is BloomTestSetup {
    // Events
    event BorrowerKYCed(address indexed account);
    event MarketMakerKYCed(address indexed account);

    function setUp() public override {
        super.setUp();
    }

    function testDeployment() public {
        BloomPool newPool = new BloomPool(
            address(stable),
            address(billToken),
            initialLeverageBps,
            owner
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

    function test_LeverageBps() public view {
        assertEq(bloomPool.leverageBps(), initialLeverageBps);
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
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        bloomFactory.createBloomPool(address(stable), address(billToken), 200);
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

    function testSetLeverageNonOwner() public {
        /// Expect revert if not owner calls
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        bloomPool.setLeverageBps(200);
        assertEq(bloomPool.leverageBps(), initialLeverageBps);
    }

    function testLendOrderZero() public {
        vm.expectRevert(Errors.ZeroAmount.selector);
        bloomPool.lendOrder(0);
        assertEq(bloomPool.openDepth(), 0);
    }

    function testFillOrderZero() public {
        _createLendOrder(alice, 100e6);

        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower);

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
}
