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
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

import {BloomFactory} from "@bloom-v2/BloomFactory.sol";
import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {Tby} from "@bloom-v2/token/Tby.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

abstract contract BloomTestSetup is Test {
    using FpMath for uint256;

    BloomFactory internal bloomFactory;
    BloomPool internal bloomPool;
    Tby internal tby;
    MockERC20 internal stable;
    MockERC20 internal billToken;
    MockPriceFeed internal priceFeed;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal borrower = makeAddr("borrower");
    address internal marketMaker = makeAddr("marketMaker");
    address internal rando = makeAddr("rando");

    uint256 internal initialLeverage = 50e18;
    uint256 internal initialSpread = 0.995e18;

    address[] public lenders;
    address[] public borrowers;
    address[] public filledOrders;
    uint256[] public filledAmounts;

    function setUp() public virtual {
        bloomFactory = new BloomFactory(owner);
        stable = new MockERC20("Mock USDC", "USDC", 6);
        billToken = new MockERC20("Mock T-Bill Token", "bIb01", 18);

        // Start at a non-0 block timestamp
        skip(1 weeks);

        vm.startPrank(owner);
        priceFeed = new MockPriceFeed(8);
        priceFeed.setLatestRoundData(1, 110e8, 0, block.timestamp, 1);

        bloomPool = bloomFactory.createBloomPool(
            address(stable), address(billToken), address(priceFeed), initialLeverage, initialSpread
        );
        vm.stopPrank();

        tby = Tby(bloomPool.tby());
        assertNotEq(address(bloomPool), address(0));
    }

    function _createLendOrder(address account, uint256 amount) internal {
        stable.mint(account, amount);
        vm.startPrank(account);
        stable.approve(address(bloomPool), amount);
        bloomPool.lendOrder(amount);
        vm.stopPrank();
    }

    function _fillOrder(address lender, uint256 amount) internal returns (uint256 borrowAmount) {
        borrowAmount = amount.divWad(initialLeverage);
        stable.mint(borrower, borrowAmount);
        vm.startPrank(borrower);
        stable.approve(address(bloomPool), borrowAmount);
        bloomPool.fillOrder(lender, amount);
        vm.stopPrank();
    }

    function _swapIn(uint256 stableAmount) internal returns (uint256 id, uint256 assetAmount) {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (stableAmount * (10 ** (18 - stable.decimals()))).divWadUp(answerScaled);

        vm.startPrank(marketMaker);
        billToken.mint(marketMaker, rwaAmount);
        billToken.approve(address(bloomPool), rwaAmount);
        return bloomPool.swapIn(lenders, stableAmount);
    }

    function _swapOut(uint256 id, uint256 stableAmount) internal returns (uint256 assetAmount) {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        uint256 answerScaled = uint256(answer) * (10 ** (18 - priceFeed.decimals()));
        uint256 rwaAmount = (stableAmount * (10 ** (18 - stable.decimals()))).divWadUp(answerScaled);

        vm.startPrank(marketMaker);
        stable.mint(marketMaker, stableAmount);
        stable.approve(address(bloomPool), stableAmount);
        return bloomPool.swapOut(id, rwaAmount);
    }

    function _skipAndUpdatePrice(uint256 time, uint256 price, uint80 roundId) internal {
        vm.startPrank(owner);
        skip(time);
        priceFeed.setLatestRoundData(roundId, int256(price), block.timestamp, block.timestamp, roundId);
        vm.stopPrank();
    }
}
