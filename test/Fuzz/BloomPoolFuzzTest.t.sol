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

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";

contract BloomPoolFuzzTest is BloomTestSetup {
    using FpMath for uint256;

    address[] public lenders;
    address[] public borrowers;
    address[] public filledOrders;
    uint256[] public filledAmounts;

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
        uint256 rwaAmount = (assetsNeeded * (10 ** 18 - stable.decimals())).divWadUp(answerScaled);

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
        assertEq(bloomPool.tbyCollateral(0).rwaAmount, rwaAmount);

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

        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (swapAmount * (10 ** 18 - stable.decimals())).divWadUp(answerScaled);

        vm.startPrank(marketMaker);

        // Mint RWA Tokens to the market maker
        billToken.mint(marketMaker, rwaAmount);
        billToken.approve(address(bloomPool), rwaAmount);
        
        (uint256 id, uint256 amountSwapped) = bloomPool.swapIn(lenders, swapAmount);

        // (, answer,,,) = priceFeed.latestRoundData();
        // answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        // rwaAmount = (amountSwapped * (10 ** 18 - stable.decimals())).divWadUp(answerScaled);

        uint256 expectedStableBalance = order0 + order1 + order2 - amountSwapped;
        // Validate Token Balances
        // assertEq(stable.balanceOf(address(bloomPool)), expectedStableBalance);
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
            expectedBobTby = order1Amount * amounts[1] / order1;
            expectedBorrowerAmount += (order1Amount - expectedBobTby);

            expectedBobOrderCount = 1;
            expectedRandoOrderCount = 1;
        } else if (swapAmount >= order0 + order1 && swapAmount < totalAmounts) {
            // 2 full orders removed: Alice and Bob
            expectedAliceTby = amounts[0];
            expectedBorrowerAmount = borrowAmount0;

            expectedBobTby = amounts[1];
            expectedBorrowerAmount += borrowAmount1;

            uint256 order2Amount = swapAmount - (order0 + order1);
            expectedRandoTby = order2Amount * amounts[2] / order2;
            expectedBorrowerAmount += (order2Amount - expectedRandoTby);

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
            expectedAliceTby = swapAmount * amounts[0] / (amounts[0] + borrowAmount0);
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
        // assertEq(tby.balanceOf(alice, id), expectedAliceTby);
        // assertEq(tby.balanceOf(bob, id), expectedBobTby);
        // assertEq(tby.balanceOf(rando, id), expectedRandoTby);

        // Expected Matched Depth should equal the sum of all lend orders minus the added balance for all lenders
        uint256 expectedMatchedDepth = amounts[0] + amounts[1] + amounts[2]
            - (tby.balanceOf(alice, id) + tby.balanceOf(bob, id) + tby.balanceOf(rando, id));
        assertEq(bloomPool.matchedDepth(), expectedMatchedDepth);

        assertEq(bloomPool.tbyCollateral(0).assetAmount, 0);
        assertEq(bloomPool.tbyCollateral(0).rwaAmount, rwaAmount);

        // assertEq(bloomPool.borrowerAmount(borrower, 0), expectedBorrowerAmount);
        // assertEq(bloomPool.totalBorrowed(0), expectedBorrowerAmount);
        assertEq(bloomPool.isTbyRedeemable(0), false);
    }
}