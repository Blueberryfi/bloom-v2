// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {Tby} from "@bloom-v2/token/Tby.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

abstract contract BloomTestSetup is Test {
    using FpMath for uint256;

    BloomPool internal bloomPool;
    Tby internal tby;
    MockERC20 internal stable;
    MockERC20 internal billToken;
    MockPriceFeed internal priceFeed;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal borrower1 = makeAddr("borrower1");
    address internal borrower2 = makeAddr("borrower2");
    address internal rando = makeAddr("rando");

    uint256 internal initialLeverage = 50e18;
    uint256 internal initialSpread = 0.995e18;

    address[] public lenders;
    address[] public borrowers;
    address[] public filledOrders;
    uint256[] public filledAmounts;

    address internal constant usd = address(0x0000000000000000000000000000000000000348);

    function setUp() public virtual {
        stable = new MockERC20("Mock USDC", "USDC", 6);
        billToken = new MockERC20("Mock T-Bill Token", "bIb01", 18);

        // Start at a non-0 block timestamp
        skip(1 weeks);

        vm.startPrank(owner);
        priceFeed = new MockPriceFeed(8);
        priceFeed.setLatestRoundData(1, 100e8, 0, block.timestamp, 1);

        bloomPool = new BloomPool(address(stable), 1e6, owner);
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

    function _initBorrow(address borrower, uint256 amount) internal returns (uint256 borrowAmount) {
        borrowAmount = amount.divWad(initialLeverage);
        stable.mint(borrower, borrowAmount);
        vm.startPrank(borrower);
        stable.approve(address(bloomPool), borrowAmount);
        bloomPool.borrow(lenders, borrower, amount);
        vm.stopPrank();
    }

    function _skipAndUpdatePrice(uint256 time, uint256 price, uint80 roundId) internal {
        vm.startPrank(owner);
        skip(time);
        priceFeed.setLatestRoundData(roundId, int256(price), block.timestamp, block.timestamp, roundId);
        vm.stopPrank();
    }
}
