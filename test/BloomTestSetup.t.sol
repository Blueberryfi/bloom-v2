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

import {BloomRouter} from "@bloom-v2/BloomRouter.sol";
import {Tby} from "@bloom-v2/token/Tby.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

abstract contract BloomTestSetup is Test {
    using FpMath for uint256;

    BloomRouter internal bloomRouter;
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

    function _setUp(address stable_, address billToken_) internal {
        _setupStable(stable_);
        _setupBillToken(billToken_);

        // Start at a non-0 block timestamp
        skip(1 weeks);

        vm.startPrank(owner);
        priceFeed = new MockPriceFeed(8);
        priceFeed.setLatestRoundData(1, 100e8, 0, block.timestamp, 1);

        bloomRouter = new BloomRouter(address(stable), 1e6, owner);
        vm.stopPrank();
        assertNotEq(address(bloomRouter), address(0));
    }

    function _createLendOrder(address account, uint256 amount) internal {
        _dealUSDC(account, amount);
        vm.startPrank(account);
        stable.approve(address(bloomRouter), amount);
        bloomRouter.lendOrder(amount);
        vm.stopPrank();
    }

    function _initBorrow(address borrower, address pool, uint256 amount) internal returns (uint256 borrowAmount) {
        borrowAmount = amount.divWad(initialLeverage);
        _dealUSDC(borrower, borrowAmount);
        vm.startPrank(borrower);
        stable.approve(address(bloomRouter), borrowAmount);
        bloomRouter.borrow(lenders, pool, amount);
        vm.stopPrank();
    }

    function _skipAndUpdatePrice(uint256 time, uint256 price, uint80 roundId) internal {
        vm.startPrank(owner);
        skip(time);
        priceFeed.setLatestRoundData(roundId, int256(price), block.timestamp, block.timestamp, roundId);
        vm.stopPrank();
    }

    function _setupStable(address stable_) internal {
        if (stable_ == address(0)) {
            stable = new MockERC20("Mock USDC", "USDC", 6);
        } else {
            stable = MockERC20(stable_);
        }
    }

    function _setupBillToken(address billToken_) internal {
        if (billToken_ == address(0)) {
            billToken = new MockERC20("Mock T-Bill Token", "bIb01", 18);
        } else {
            billToken = MockERC20(billToken_);
        }
    }

    function _dealUSDC(address account, uint256 amount) internal virtual {
        stable.mint(account, amount);
    }
}
