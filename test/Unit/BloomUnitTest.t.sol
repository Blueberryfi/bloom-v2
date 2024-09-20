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
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";

contract BloomUnitTest is BloomTestSetup {
    using FpMath for uint256;

    function setUp() public override {
        super.setUp();
    }

    function testDeployment() public {
        BloomPool newPool = new BloomPool(
            address(stable), address(billToken), address(priceFeed), 1 days, initialLeverage, initialSpread, owner
        );
        assertNotEq(address(newPool), address(0));
        assertEq(newPool.rwaPriceFeed().priceFeed, address(priceFeed));
        assertEq(newPool.futureMaturity(), 180 days);
    }

    function testSetPriceFeedNonOwner() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.setPriceFeed(address(1), 2 days);
        assertEq(bloomPool.rwaPriceFeed().priceFeed, address(priceFeed));
        assertEq(bloomPool.rwaPriceFeed().updateInterval, 1 days);
    }

    function testSetMaturityNonOwner() public {
        /// Expect revert if not owner calls
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        bloomPool.setMaturity(10 days);
        assertEq(bloomPool.futureMaturity(), 180 days);
    }

    function testSetPriceFeedSuccess() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit IBloomPool.RwaPriceFeedSet(address(priceFeed));
        bloomPool.setPriceFeed(address(priceFeed), 1 days);
    }

    function testSetPriceFeedRevert() public {
        vm.startPrank(owner);
        // Revert if price is 0
        priceFeed.setLatestRoundData(0, 0, 0, 0, 0);
        vm.expectRevert(Errors.InvalidPriceFeed.selector);
        bloomPool.setPriceFeed(address(priceFeed), 1 days);

        // Revert if feed hasnt been updated in a while
        priceFeed.setLatestRoundData(0, 1, 0, 0, 0);
        vm.expectRevert(Errors.OutOfDate.selector);
        bloomPool.setPriceFeed(address(priceFeed), 1 days);

        // Revert if feed hasnt has the wrong round id
        priceFeed.setLatestRoundData(1, 1, 0, 0, 0);
        vm.expectRevert(Errors.OutOfDate.selector);
        bloomPool.setPriceFeed(address(priceFeed), 1 days);
    }

    function testSetMaturitySuccess() public {
        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit IBloomPool.TbyMaturitySet(10 days);
        bloomPool.setMaturity(10 days);
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

    function testGetRate() public {
        vm.startPrank(owner);
        bloomPool.whitelistMarketMaker(marketMaker, true);
        bloomPool.whitelistBorrower(borrower, true);

        _createLendOrder(alice, 110e6);
        _fillOrder(alice, 110e6);
        lenders.push(alice);
        _swapIn(1e18);

        assertEq(bloomPool.getRate(0), FpMath.WAD);

        // Move time forward & update price feed
        uint256 newRate = 115e8;
        _skipAndUpdatePrice(3 days, newRate, 1);

        uint256 priceAppreciation = (uint256(newRate).divWad(110e8)) - FpMath.WAD;
        uint256 expectedRate = FpMath.WAD + ((priceAppreciation).mulWad(initialSpread));
        assertEq(bloomPool.getRate(0), expectedRate);
    }

    function testSwapOutAmount0() public {
        vm.startPrank(owner);
        bloomPool.whitelistMarketMaker(marketMaker, true);
        bloomPool.whitelistBorrower(borrower, true);

        _createLendOrder(alice, 110e6);
        _fillOrder(alice, 110e6);
        lenders.push(alice);
        _swapIn(1e18);

        vm.startPrank(marketMaker);
        vm.expectRevert(Errors.ZeroAmount.selector);
        bloomPool.swapOut(0, 0);
    }

    function testSwapOutNonMaturedTby() public {
        vm.startPrank(owner);
        bloomPool.whitelistMarketMaker(marketMaker, true);
        bloomPool.whitelistBorrower(borrower, true);

        _createLendOrder(alice, 110e6);
        _fillOrder(alice, 110e6);
        lenders.push(alice);
        _swapIn(1e18);

        // Fast forward to just before the TBY matures & update price feed
        _skipAndUpdatePrice(179 days, 112e8, 2);

        vm.startPrank(marketMaker);
        vm.expectRevert(Errors.TBYNotMatured.selector);
        bloomPool.swapOut(0, 110e6);
    }

    function testSwapInAndOut() public {
        vm.startPrank(owner);
        bloomPool.whitelistMarketMaker(marketMaker, true);
        bloomPool.whitelistBorrower(borrower, true);

        _createLendOrder(alice, 110e6);
        uint256 borrowAmount = _fillOrder(alice, 110e6);
        lenders.push(alice);
        uint256 totalStableCollateral = 110e6 + borrowAmount;
        _swapIn(totalStableCollateral);

        assertEq(bloomPool.getRate(0), FpMath.WAD);

        uint256 expectedRwa = (totalStableCollateral * (10 ** (18 - 6))).divWadUp(110e18);

        assertEq(stable.balanceOf(address(bloomPool)), 0);
        assertEq(billToken.balanceOf(address(bloomPool)), expectedRwa);

        IBloomPool.TbyCollateral memory startCollateral = bloomPool.tbyCollateral(0);
        assertEq(startCollateral.rwaAmount, expectedRwa);
        assertEq(startCollateral.assetAmount, 0);

        _skipAndUpdatePrice(180 days, 110e8, 2);
        vm.startPrank(marketMaker);
        stable.approve(address(bloomPool), totalStableCollateral);
        bloomPool.swapOut(0, expectedRwa);

        assertEq(billToken.balanceOf(address(bloomPool)), 0);
        assertEq(stable.balanceOf(address(bloomPool)), totalStableCollateral);
        assertEq(billToken.balanceOf(marketMaker), expectedRwa);

        IBloomPool.TbyCollateral memory endCollateral = bloomPool.tbyCollateral(0);
        assertEq(endCollateral.rwaAmount, 0);
        assertEq(endCollateral.assetAmount, totalStableCollateral);
        assertEq(bloomPool.isTbyRedeemable(0), true);
    }

    function testTokenIdIncrement() public {
        vm.startPrank(owner);
        bloomPool.whitelistMarketMaker(marketMaker, true);
        bloomPool.whitelistBorrower(borrower, true);

        _createLendOrder(alice, 110e6);
        uint256 borrowAmount = _fillOrder(alice, 110e6);
        lenders.push(alice);

        uint256 totalStableCollateral = 110e6 + borrowAmount;
        uint256 swapClip = totalStableCollateral / 4;

        // First 2 clips should mint the same token id
        _swapIn(swapClip);
        assertEq(bloomPool.lastMintedId(), 0);

        _skipAndUpdatePrice(1 days, 110e8, 2);

        _swapIn(swapClip);
        assertEq(bloomPool.lastMintedId(), 0);

        // Next clip should mint a new token id
        _skipAndUpdatePrice(1 days + 30 minutes, 110e8, 3);

        _swapIn(swapClip);
        assertEq(bloomPool.lastMintedId(), 1);

        // Final clip should mint a new token id
        _skipAndUpdatePrice(3 days, 110e8, 4);

        _swapIn(swapClip);
        assertEq(bloomPool.lastMintedId(), 2);

        // Check that 3 different ids are minted
        assertGt(tby.balanceOf(alice, 0), 0);
        assertGt(tby.balanceOf(alice, 1), 0);
        assertGt(tby.balanceOf(alice, 2), 0);
    }

    function testTbyMaturityUpdateDoesntAffectExistingTby() public {
        vm.startPrank(owner);
        bloomPool.whitelistMarketMaker(marketMaker, true);
        bloomPool.whitelistBorrower(borrower, true);

        _createLendOrder(alice, 110e6);
        _fillOrder(alice, 110e6);
        lenders.push(alice);
        _swapIn(55e6);

        uint256 expectedTby0Maturity = bloomPool.tbyMaturity(0).end;
        // Fast forward 1 day & update price feed
        _skipAndUpdatePrice(1 days, 110e8, 2);

        // update maturity to 10 days
        vm.startPrank(owner);
        bloomPool.setMaturity(10 days);
        vm.stopPrank();

        // Complete swap and validate that the maturity is still 180 days
        _swapIn(55e6);
        assertEq(bloomPool.tbyMaturity(0).end, expectedTby0Maturity);

        // Fast forward 1 month & update price feed
        _skipAndUpdatePrice(30 days, 111e8, 3);

        // Mint a new TBY
        _createLendOrder(alice, 111e6);
        _fillOrder(alice, 111e6);
        _swapIn(111e6);

        // Validate that the maturity of the first TBY is still 180 days
        assertEq(bloomPool.tbyMaturity(0).end, expectedTby0Maturity);
        // Validate that the maturity of the second TBY is 10 days
        assertEq(bloomPool.tbyMaturity(1).end, block.timestamp + 10 days);
    }

    function testSwapOutExtraCall() external {
        vm.startPrank(owner);
        bloomPool.whitelistMarketMaker(marketMaker, true);
        bloomPool.whitelistBorrower(borrower, true);

        uint256 lendamt = 1000e6;
        _createLendOrder(alice, lendamt);
        _createLendOrder(bob, lendamt);

        _fillOrder(alice, lendamt);
        _fillOrder(bob, lendamt);

        lenders.push(alice);
        lenders.push(bob);

        uint256 swapamt = 20000e18;
        _swapIn(swapamt);
        vm.stopPrank();

        assert(stable.balanceOf(address(bloomPool)) == 0);
        assert(stable.balanceOf(address(marketMaker)) == 2040000000);
        assert(billToken.balanceOf(address(bloomPool)) == 18545454545454545455);
        assert(tby.balanceOf(address(bloomPool), 0) == 0);
        uint256 DEFAULT_MATURITY = 180 days;

        skip(DEFAULT_MATURITY);

        vm.startPrank(owner);
        priceFeed.setLatestRoundData(1, 110e8, 0, block.timestamp, 1);

        _swapOut(0, 300e6);

        // sending additional tokens but can be any value.
        _swapOut(0, 2700e6);
    }
}
