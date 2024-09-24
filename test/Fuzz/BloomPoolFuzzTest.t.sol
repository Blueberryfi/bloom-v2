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

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";

contract BloomPoolFuzzTest is BloomTestSetup {
    using FpMath for uint256;

    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);
        bloomPool.whitelistBorrower(borrower, true);
        bloomPool.whitelistMarketMaker(marketMaker, true);
    }

    function testFuzz_SwapInSingleOrder(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000_000_000e6);
        _createLendOrder(alice, amount);
        _fillOrder(alice, amount);
        lenders.push(alice);

        // Calculate the amount of tokens needed to swap in
        uint256 borrowConverted = amount.divWad(initialLeverage);
        uint256 assetsNeeded = amount + amount.divWad(initialLeverage);

        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (assetsNeeded * (10 ** (18 - stable.decimals()))).divWadUp(answerScaled);

        vm.startPrank(marketMaker);

        // Mint RWA Tokens to the market maker
        billToken.mint(marketMaker, rwaAmount);
        billToken.approve(address(bloomPool), rwaAmount);

        // The whole order should be swapped in
        vm.expectEmit(true, true, true, true);
        emit IBloomPool.MarketMakerSwappedIn(0, marketMaker, rwaAmount, assetsNeeded);
        bloomPool.swapIn(lenders, assetsNeeded);

        // Validate Token Balances
        // Allow for Some dust in the bloomPool due to decimal rounding
        assert(stable.balanceOf(address(bloomPool)) == 1 || stable.balanceOf(address(bloomPool)) == 0);
        assertEq(stable.balanceOf(marketMaker), assetsNeeded);
        assertEq(billToken.balanceOf(address(bloomPool)), rwaAmount);

        // Validate State Changes
        assertEq(bloomPool.matchedDepth(), 0);
        assertEq(bloomPool.matchedOrderCount(alice), 0);

        assertEq(bloomPool.tbyCollateral(0).assetAmount, 0);
        assertEq(bloomPool.tbyCollateral(0).currentRwaAmount, rwaAmount);

        assertEq(bloomPool.tbyRwaPricing(0).startPrice, answerScaled);
        assertEq(bloomPool.tbyRwaPricing(0).endPrice, 0);

        assertEq(bloomPool.tbyMaturity(0).start, block.timestamp);
        assertEq(bloomPool.tbyMaturity(0).end, block.timestamp + 180 days);

        assertEq(bloomPool.borrowerAmount(borrower, 0), borrowConverted);
        assertEq(bloomPool.totalBorrowed(0), borrowConverted);
        assertEq(bloomPool.isTbyRedeemable(0), false);

        assertEq(tby.balanceOf(alice, 0), amount);
        assertEq(bloomPool.getRate(0), FpMath.WAD);
    }

    function testFuzz_SwapInMultiOrders(uint256[3] memory amounts, uint256 swapAmount) public {
        amounts[0] = bound(amounts[0], 1e6, 100_000_000_000e6);
        amounts[1] = bound(amounts[1], 1e6, 100_000_000_000e6);
        amounts[2] = bound(amounts[2], 1e6, 100_000_000_000e6);

        _createLendOrder(alice, amounts[0]);
        uint256 borrowAmount0 = _fillOrder(alice, amounts[0]);
        uint256 order0 = amounts[0] + borrowAmount0;
        lenders.push(alice);

        _createLendOrder(bob, amounts[1]);
        uint256 borrowAmount1 = _fillOrder(bob, amounts[1]);
        uint256 order1 = amounts[1] + borrowAmount1;
        lenders.push(bob);

        _createLendOrder(rando, amounts[2]);
        uint256 borrowAmount2 = _fillOrder(rando, amounts[2]);
        uint256 order2 = amounts[2] + borrowAmount2;
        lenders.push(rando);

        // Calculate the amount of tokens needed to swap in
        uint256 totalAmounts = amounts[0] + borrowAmount0 + amounts[1] + borrowAmount1 + amounts[2] + borrowAmount2;

        vm.assume(totalAmounts >= swapAmount);
        vm.assume(swapAmount > 0);

        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (swapAmount * (10 ** (18 - stable.decimals()))).divWadUp(answerScaled);

        vm.startPrank(marketMaker);
        // Mint RWA Tokens to the market maker
        billToken.mint(marketMaker, rwaAmount);
        billToken.approve(address(bloomPool), rwaAmount);

        (uint256 id, uint256 amountSwapped) = bloomPool.swapIn(lenders, swapAmount);

        uint256 expectedStableBalance = order0 + order1 + order2 - amountSwapped;
        // Validate Token Balances
        assertEq(stable.balanceOf(address(bloomPool)), expectedStableBalance);
        assertEq(stable.balanceOf(marketMaker), amountSwapped);
        assertEq(billToken.balanceOf(address(bloomPool)), rwaAmount);

        uint256 expectedAliceTby;
        uint256 expectedAliceOrderCount;

        uint256 expectedBobTby;
        uint256 expectedBobOrderCount;

        uint256 expectedRandoTby;
        uint256 expectedRandoOrderCount;

        uint256 expectedBorrowerAmount;

        if (swapAmount >= order0 && swapAmount < order0 + order1) {
            // 1 full order removed: Just Alice
            expectedAliceTby = amounts[0];
            expectedBorrowerAmount = borrowAmount0;

            uint256 order1Amount = swapAmount - order0;
            expectedBobTby = (order1Amount * amounts[1]) / order1;
            expectedBorrowerAmount += swapAmount - expectedBobTby;

            expectedBobOrderCount = 1;
            expectedRandoOrderCount = 1;
        } else if (swapAmount >= order0 + order1 && swapAmount < totalAmounts) {
            // 2 full orders removed: Alice and Bob
            expectedAliceTby = amounts[0];
            expectedBorrowerAmount = borrowAmount0;

            expectedBobTby = amounts[1];
            expectedBorrowerAmount += borrowAmount1;

            uint256 order2Amount = swapAmount - (order0 + order1);
            expectedRandoTby = (order2Amount * amounts[2]) / order2;
            expectedBorrowerAmount += swapAmount - expectedRandoTby;

            expectedRandoOrderCount = 1;
        } else if (swapAmount == totalAmounts) {
            // 3 Full orders removed: Alice, Bob and Rando
            expectedAliceTby = amounts[0];
            expectedBorrowerAmount = borrowAmount0;

            expectedBobTby = amounts[1];
            expectedBorrowerAmount += borrowAmount1;

            expectedRandoTby = amounts[2];
            expectedBorrowerAmount += borrowAmount2;
        } else {
            // If no full orders were removed
            expectedAliceTby = (swapAmount * amounts[0]) / order0;
            expectedBorrowerAmount = swapAmount - expectedAliceTby;

            expectedAliceOrderCount = 1;
            expectedBobOrderCount = 1;
            expectedRandoOrderCount = 1;
        }

        // Validate user order counts
        assertEq(bloomPool.matchedOrderCount(alice), expectedAliceOrderCount);
        assertEq(bloomPool.matchedOrderCount(bob), expectedBobOrderCount);
        assertEq(bloomPool.matchedOrderCount(rando), expectedRandoOrderCount);

        // Validate user Tby balance
        assertEq(tby.balanceOf(alice, id), expectedAliceTby);
        assertEq(tby.balanceOf(bob, id), expectedBobTby);
        assertEq(tby.balanceOf(rando, id), expectedRandoTby);

        // Expected Matched Depth should equal the sum of all lend orders minus the added balance for all lenders
        uint256 expectedMatchedDepth = amounts[0] + amounts[1] + amounts[2]
            - (tby.balanceOf(alice, id) + tby.balanceOf(bob, id) + tby.balanceOf(rando, id));
        assertEq(bloomPool.matchedDepth(), expectedMatchedDepth);

        assertEq(bloomPool.tbyCollateral(0).assetAmount, 0);
        assertEq(bloomPool.tbyCollateral(0).currentRwaAmount, rwaAmount);

        assertApproxEqRelDecimal(bloomPool.borrowerAmount(borrower, 0), expectedBorrowerAmount, 0.9999e18, 6);
        assertApproxEqRelDecimal(bloomPool.totalBorrowed(0), expectedBorrowerAmount, 0.9999e18, 6);
        assertEq(bloomPool.isTbyRedeemable(0), false);
        assertEq(bloomPool.lastMintedId(), 0);
    }

    function testFuzz_SwapOut(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000_000_000e6);
        _createLendOrder(alice, amount);
        uint256 borrowAmount = _fillOrder(alice, amount);
        lenders.push(alice);
        uint256 totalCapital = amount + borrowAmount;

        uint256 startingTime = vm.getBlockTimestamp();

        _swapIn(totalCapital);

        // Fast forward to just before the TBY matures & update price feed
        _skipAndUpdatePrice(180 days, 112e8, 2);

        uint256 amountNeeeded = (totalCapital * 112e18) / 110e18;
        uint256 rwaBalance = billToken.balanceOf(address(bloomPool));

        vm.startPrank(marketMaker);
        stable.mint(marketMaker, amountNeeeded);
        stable.approve(address(bloomPool), amountNeeeded);

        vm.expectEmit(true, true, false, true);
        emit IBloomPool.MarketMakerSwappedOut(0, marketMaker, rwaBalance, amountNeeeded);
        uint256 assetAmount = bloomPool.swapOut(0, rwaBalance);

        // Validate Token Balances
        assertEq(stable.balanceOf(address(bloomPool)), amountNeeeded);
        assertEq(stable.balanceOf(address(bloomPool)), assetAmount);
        assertEq(billToken.balanceOf(address(bloomPool)), 0);

        // Validate TBY State
        IBloomPool.TbyCollateral memory collateral = bloomPool.tbyCollateral(0);
        assertEq(collateral.assetAmount, amountNeeeded);
        assertEq(collateral.currentRwaAmount, 0);
        assertEq(collateral.originalRwaAmount, rwaBalance);

        IBloomPool.TbyMaturity memory maturity = bloomPool.tbyMaturity(0);
        assertEq(maturity.start, startingTime);
        assertEq(maturity.end, startingTime + 180 days);

        IBloomPool.RwaPrice memory rwaPricing = bloomPool.tbyRwaPricing(0);
        assertEq(rwaPricing.startPrice, 110e18);
        assertEq(rwaPricing.endPrice, 112e18);

        // Validate Lender and Borrower returns
        uint256 tbyRate = bloomPool.getRate(0);
        uint256 tbyAmount = tby.totalSupply(0);

        uint256 expectedLenderReturns = tbyAmount.mulWad(tbyRate);
        uint256 expectedBorrowerReturns = amountNeeeded - expectedLenderReturns;

        assertEq(bloomPool.lenderReturns(0), expectedLenderReturns);
        assertEq(bloomPool.borrowerReturns(0), expectedBorrowerReturns);
    }

    function testFuzz_Redemptions(uint256[3] memory amounts) public {
        amounts[0] = bound(amounts[0], 1e6, 100_000_000_000e6);
        amounts[1] = bound(amounts[1], 1e6, 100_000_000_000e6);
        amounts[2] = bound(amounts[2], 1e6, 100_000_000_000e6);

        _createLendOrder(alice, amounts[0]);
        _fillOrder(alice, amounts[0]);
        lenders.push(alice);

        _createLendOrder(bob, amounts[1]);
        _fillOrder(bob, amounts[1]);
        lenders.push(bob);

        _createLendOrder(rando, amounts[2]);
        _fillOrder(rando, amounts[2]);
        lenders.push(rando);

        uint256 stableBalance = stable.balanceOf(address(bloomPool));
        _swapIn(stableBalance);

        // Fast forward to just before the TBY matures & update price feed
        _skipAndUpdatePrice(180 days, 112e8, 2);

        uint256 amountNeeeded = (stableBalance * 112e18) / 110e18;
        uint256 rwaBalance = billToken.balanceOf(address(bloomPool));

        vm.startPrank(marketMaker);
        stable.mint(marketMaker, amountNeeeded);
        stable.approve(address(bloomPool), amountNeeeded);

        vm.expectEmit(true, true, false, true);
        emit IBloomPool.MarketMakerSwappedOut(0, marketMaker, rwaBalance, amountNeeeded);
        bloomPool.swapOut(0, rwaBalance);

        vm.startPrank(alice);
        bloomPool.redeemLender(0, tby.balanceOf(alice, 0));
        vm.stopPrank();

        vm.startPrank(bob);
        bloomPool.redeemLender(0, tby.balanceOf(bob, 0));
        vm.stopPrank();

        vm.startPrank(rando);
        bloomPool.redeemLender(0, tby.balanceOf(rando, 0));
        vm.stopPrank();

        uint256 borrowerReturns = bloomPool.borrowerReturns(0);

        vm.startPrank(borrower);
        bloomPool.redeemBorrower(0);
        vm.stopPrank();

        assertEq(stable.balanceOf(address(bloomPool)), 0);

        uint256 tbyRate = bloomPool.getRate(0);
        assertApproxEqRelDecimal(stable.balanceOf(alice), amounts[0] * tbyRate / 1e18, 0.0001e18, 6);
        assertApproxEqRelDecimal(stable.balanceOf(bob), amounts[1] * tbyRate / 1e18, 0.0001e18, 6);
        assertApproxEqRelDecimal(stable.balanceOf(rando), amounts[2] * tbyRate / 1e18, 0.0001e18, 6);
        assertEq(stable.balanceOf(borrower), borrowerReturns);

        IBloomPool.TbyCollateral memory collateral = bloomPool.tbyCollateral(0);
        assertEq(collateral.assetAmount, 0);
        assertEq(collateral.currentRwaAmount, 0);
        assertEq(collateral.originalRwaAmount, rwaBalance);
    }

    function testFuzz_SwapOutAndRedeemWithPriceDrop(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000_000_000e6);
        _createLendOrder(alice, amount);
        _fillOrder(alice, amount);
        lenders.push(alice);

        uint256 stableBalance = stable.balanceOf(address(bloomPool));
        _swapIn(stableBalance);

        // Fast forward to the maturity of the TBY and increase the price.
        _skipAndUpdatePrice(180 days, 112e8, 2);

        uint256 amountNeeeded = (stableBalance * 112e18) / 110e18;
        uint256 rwaBalance = billToken.balanceOf(address(bloomPool));

        vm.startPrank(marketMaker);
        stable.mint(marketMaker, amountNeeeded);
        stable.approve(address(bloomPool), amountNeeeded);

        // Complete half of the needed swap
        bloomPool.swapOut(0, rwaBalance / 2);

        // Validate that users cannot redeem their TBYs
        assertEq(bloomPool.isTbyRedeemable(0), false);

        // Fast forward to after the TBY has matured but before all of the RWA has been swapped out.
        // Have a dramatic price drop
        _skipAndUpdatePrice(1 days, 50e8, 2);
        uint256 remainingBalance = billToken.balanceOf(address(bloomPool));

        vm.startPrank(marketMaker);
        bloomPool.swapOut(0, remainingBalance);

        assertEq(bloomPool.isTbyRedeemable(0), true);

        IBloomPool.TbyCollateral memory collateral = bloomPool.tbyCollateral(0);

        uint256 tbyTotalSupply = tby.totalSupply(0);
        uint256 tbyRate = bloomPool.getRate(0);
        uint256 expectedLenderReturns = tbyTotalSupply.mulWad(tbyRate);
        uint256 expectedBorrowerReturns = collateral.assetAmount - expectedLenderReturns;

        assertEq(collateral.currentRwaAmount, 0);

        assertApproxEqRelDecimal(bloomPool.lenderReturns(0), expectedLenderReturns, 0.0001e18, 6);
        assertApproxEqRelDecimal(bloomPool.borrowerReturns(0), expectedBorrowerReturns, 0.0001e18, 6);

        // Complete the swaps
        vm.startPrank(alice);
        bloomPool.redeemLender(0, tby.balanceOf(alice, 0));
        vm.stopPrank();

        vm.startPrank(borrower);
        bloomPool.redeemBorrower(0);
        vm.stopPrank();

        assertApproxEqRelDecimal(stable.balanceOf(alice), amount * tbyRate / 1e18, 0.0001e18, 6);
    }

    function testFuzz_SwapInMultidayOrder(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000_000_000e6);
        _createLendOrder(alice, amount);
        _fillOrder(alice, amount);
        lenders.push(alice);

        // Swap in 1/4 of the stable balance
        uint256 stableBalance = stable.balanceOf(address(bloomPool));
        (uint256 id, uint256 assetAmount) = _swapIn(stableBalance / 4);

        uint256 rwaBalance = billToken.balanceOf(address(bloomPool));

        assertEq(bloomPool.tbyCollateral(id).assetAmount, 0);
        assertEq(bloomPool.tbyCollateral(id).currentRwaAmount, rwaBalance);

        assertEq(bloomPool.tbyRwaPricing(id).startPrice, 110e18);
        assertEq(bloomPool.tbyRwaPricing(id).endPrice, 0);

        assertEq(bloomPool.tbyMaturity(id).start, block.timestamp);
        assertEq(bloomPool.tbyMaturity(id).end, block.timestamp + 180 days);

        // Fast forward 1 day, increase the price feed by .1e8 and wap the remaining stable balance
        _skipAndUpdatePrice(1 days, 110.8e8, 2);
        (uint256 id2, uint256 assetAmount2) = _swapIn(stableBalance - assetAmount);
        uint256 rwaBalance2 = billToken.balanceOf(address(bloomPool));

        assertEq(id2, id);
        assertEq(assetAmount2, stableBalance - assetAmount);

        assertEq(bloomPool.tbyCollateral(id).assetAmount, 0);
        assertEq(bloomPool.tbyCollateral(id).currentRwaAmount, rwaBalance2);

        uint256 totalValue = rwaBalance.mulWad(110e18) + (rwaBalance2 - rwaBalance).mulWad(110.8e18);
        uint256 normalizedPrice = totalValue.divWad(rwaBalance2);

        assertEq(bloomPool.tbyRwaPricing(id).startPrice, normalizedPrice);
        assertEq(bloomPool.tbyRwaPricing(id).endPrice, 0);
    }

    function testFuzz_MultipleTbyRedemptions(uint256 tbys, uint256 amount) public {
        tbys = bound(tbys, 1, 5);
        amount = bound(amount, 1e6, 100_000_000e6);

        lenders.push(alice);
        lenders.push(bob);
        lenders.push(rando);

        uint256 endingBalance = amount;
        for (uint256 i = 0; i < tbys; i++) {
            _createLendOrder(alice, amount);
            _createLendOrder(bob, amount);
            _createLendOrder(rando, amount);

            uint256 totalCollateral = amount + amount + amount;
            totalCollateral += _fillOrder(alice, amount);
            totalCollateral += _fillOrder(bob, amount);
            totalCollateral += _fillOrder(rando, amount);

            // Create new TBYs
            _swapIn(totalCollateral);

            assertEq(bloomPool.lastMintedId(), i);
            assertEq(tby.balanceOf(alice, i), amount);
            assertEq(tby.balanceOf(bob, i), amount);
            assertEq(tby.balanceOf(rando, i), amount);

            // mature TBYs but keep the price the same
            _skipAndUpdatePrice(180 days, 110e8, 2);
            _swapOut(i, totalCollateral);

            // redeem all of the TBYs
            vm.startPrank(alice);
            bloomPool.redeemLender(i, amount);
            vm.stopPrank();

            vm.startPrank(bob);
            bloomPool.redeemLender(i, amount);
            vm.stopPrank();

            vm.startPrank(rando);
            bloomPool.redeemLender(i, amount);
            vm.stopPrank();

            assertEq(tby.balanceOf(alice, i), 0);
            assertEq(tby.balanceOf(bob, i), 0);
            assertEq(tby.balanceOf(rando, i), 0);

            assertEq(stable.balanceOf(alice), endingBalance);
            assertEq(stable.balanceOf(bob), endingBalance);
            assertEq(stable.balanceOf(rando), endingBalance);

            endingBalance += amount;
        }
    }

    function testFuzz_RedemptionsWithMultipleBorrowers(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000_000e6);

        address borrower2 = makeAddr("borrower2");
        address borrower3 = makeAddr("borrower3");
        bloomPool.whitelistBorrower(borrower2, true);
        bloomPool.whitelistBorrower(borrower3, true);

        _createLendOrder(alice, amount);
        lenders.push(alice);

        uint256 totalCollateral = amount;
        totalCollateral += _fillOrder(alice, amount / 3);
        totalCollateral += _fillOrderWithCustomBorrower(alice, amount / 3, borrower2);
        totalCollateral += _fillOrderWithCustomBorrower(alice, amount / 3, borrower3);

        _swapIn(totalCollateral);
        _skipAndUpdatePrice(180 days, 115e8, 2);

        uint256 stableNeeded = (amount * 3 * 115e18) / 110e18;

        _swapOut(0, stableNeeded);

        // Validate that all redemptions for borrowers are identical
        uint256 expectedBorrowerRedemption = bloomPool.borrowerReturns(0) / 3;

        vm.startPrank(borrower);
        bloomPool.redeemBorrower(0);
        vm.stopPrank();
        assertEq(stable.balanceOf(borrower), expectedBorrowerRedemption);

        vm.startPrank(borrower2);
        bloomPool.redeemBorrower(0);
        vm.stopPrank();
        _isEqualWithDust(stable.balanceOf(borrower2), expectedBorrowerRedemption);

        vm.startPrank(borrower3);
        bloomPool.redeemBorrower(0);
        vm.stopPrank();
        _isEqualWithDust(stable.balanceOf(borrower3), expectedBorrowerRedemption);

        assertEq(bloomPool.borrowerReturns(0), 0);

        /// try to have borrower redeem twice
        vm.startPrank(borrower);
        vm.expectRevert(Errors.TotalBorrowedZero.selector);
        bloomPool.redeemBorrower(0);
        vm.stopPrank();
    }

    function testFuzz_SwapOutWithTwoBorrowersAndOneCancels(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000_000e6);
        vm.assume(amount % 2 == 0);

        address borrower2 = makeAddr("borrower2");
        bloomPool.whitelistBorrower(borrower2, true);

        _createLendOrder(alice, amount);
        lenders.push(alice);

        uint256 totalCollateral = amount;
        uint256 borrowAmount = _fillOrder(alice, amount / 2);
        totalCollateral += borrowAmount;
        totalCollateral += _fillOrderWithCustomBorrower(alice, amount / 2, borrower2);

        // Borrower2 cancels order
        vm.startPrank(borrower2);
        bloomPool.killBorrowerMatch(alice);
        vm.stopPrank();

        // Validate that the order is cancelled
        assertEq(bloomPool.amountOpen(alice), amount / 2);
        assertEq(bloomPool.amountMatched(alice), amount / 2);
        IOrderbook.MatchOrder memory borrower2Order = bloomPool.matchedOrder(alice, 1);
        assertEq(borrower2Order.borrower, address(0));
        assertEq(borrower2Order.lCollateral, 0);
        assertEq(borrower2Order.bCollateral, 0);

        _swapIn(totalCollateral);
        _skipAndUpdatePrice(180 days, 115e8, 2);

        assertEq(tby.balanceOf(alice, 0), amount / 2);

        // Check borrower data
        uint256 totalBorrowed = bloomPool.totalBorrowed(0);
        assertEq(totalBorrowed, borrowAmount);
        assertEq(bloomPool.borrowerAmount(borrower, 0), borrowAmount);
        assertEq(bloomPool.borrowerAmount(borrower2, 0), 0);
    }
}
