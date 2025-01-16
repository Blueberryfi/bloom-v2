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

import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";
import {ERC1155} from "@solady/tokens/ERC1155.sol";

import {BloomRouter} from "@bloom-v2/BloomRouter.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {MockBloomPool} from "../mocks/MockBloomPool.sol";
import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";

contract BorrowUnitTests is BloomTestSetup {
    using FpMath for uint256;

    MockBloomPool internal mockBloomPool;

    function setUp() public override {
        super.setUp();

        // deploy mock borrow module
        mockBloomPool = new MockBloomPool(
            "Test", "TEST", address(bloomRouter), address(billToken), address(priceFeed), 6, 50e18, 0.995e18, owner
        );

        vm.prank(owner);
        bloomRouter.addPool(address(mockBloomPool));
    }

    function testBorrowSingleBorrower() public {
        uint256 amount = 100e6;

        _createLendOrder(alice, amount);
        lenders.push(alice);

        uint256 borrowAmount = 2e6;
        stable.mint(borrower1, borrowAmount);

        vm.startPrank(owner);
        mockBloomPool.whitelistBorrower(borrower1, true);
        vm.stopPrank();

        vm.startPrank(borrower1);
        stable.approve(address(mockBloomPool), borrowAmount);
        bloomRouter.borrow(lenders, address(mockBloomPool), amount);

        uint256 lastMintedTby = mockBloomPool.lastMintedId();

        assertEq(bloomRouter.lastMintedId(), lastMintedTby);
        assertEq(billToken.balanceOf(address(mockBloomPool)), 1.02e18);
        assertEq(stable.balanceOf(address(mockBloomPool)), 0);

        // Assert that the state variables are updated correctly
        assertEq(mockBloomPool.tbyCollateral(lastMintedTby).rwaAmount, 1.02e18);
        assertEq(mockBloomPool.rwaPrice(lastMintedTby).startPrice, 100e18);
        assertEq(mockBloomPool.tbyMaturity(lastMintedTby).start, block.timestamp);
        assertEq(mockBloomPool.tbyMaturity(lastMintedTby).end, block.timestamp + 180 days);
    }

    function testRepaySingleBorrower() public {
        uint256 amount = 100e6;

        _createLendOrder(alice, amount);
        lenders.push(alice);

        uint256 borrowAmount = 2e6;
        stable.mint(borrower1, borrowAmount);

        vm.startPrank(owner);
        mockBloomPool.whitelistBorrower(borrower1, true);
        vm.stopPrank();

        vm.startPrank(borrower1);
        stable.approve(address(mockBloomPool), borrowAmount);
        bloomRouter.borrow(lenders, address(mockBloomPool), amount);

        // 5% increase in price ( borrower should earn .125% yield; lender should earn 4.975% yield)
        uint256 expectedLenderReturn = 104.975e6;
        uint256 expectedBorrowerReturn = 2.125e6;
        _skipAndUpdatePrice(180 days, 105e8, 1);

        // validate the rate
        assertEq(mockBloomPool.getRate(0), 1.04975e18);

        // repay the borrow
        vm.startPrank(borrower1);
        bloomRouter.repay(0);

        // validate balances
        assertEq(stable.balanceOf(address(mockBloomPool)), 107.1e6); // 102 USDC * 5% increase = 107.1 USDC
        assertEq(billToken.balanceOf(address(mockBloomPool)), 0);

        // validate state variables
        assertEq(mockBloomPool.tbyCollateral(0).rwaAmount, 0);
        assertEq(mockBloomPool.tbyCollateral(0).assetAmount, 107.1e6);
        assertEq(mockBloomPool.rwaPrice(0).startPrice, 100e18);
        assertEq(mockBloomPool.rwaPrice(0).endPrice, 105e18);

        // validate lender and borrower returns
        assertEq(mockBloomPool.lenderReturns(0), expectedLenderReturn);
        assertEq(mockBloomPool.borrowerReturns(0), expectedBorrowerReturn);

        // Redeem the lender and borrowers funds
        vm.startPrank(alice);
        mockBloomPool.setApprovalForAll(address(bloomRouter), true);
        bloomRouter.redeemLender(0, mockBloomPool.balanceOf(address(alice), 0));
        vm.startPrank(borrower1);
        bloomRouter.redeemBorrower(0);

        assertEq(stable.balanceOf(alice), expectedLenderReturn);
        assertEq(stable.balanceOf(borrower1), expectedBorrowerReturn);

        assertEq(mockBloomPool.lenderReturns(0), 0);
        assertEq(mockBloomPool.borrowerReturns(0), 0);
    }

    function testMultipleBorrowerModules() public {
        vm.startPrank(owner);
        MockBloomPool mockBloomPool2 = new MockBloomPool(
            "Test 2", "TEST-2", address(bloomRouter), address(billToken), address(priceFeed), 6, 50e18, 0.995e18, owner
        );

        bloomRouter.addPool(address(mockBloomPool2));

        MockBloomPool mockBloomPool3 = new MockBloomPool(
            "Test 3", "TEST-3", address(bloomRouter), address(billToken), address(priceFeed), 6, 50e18, 0.995e18, owner
        );

        bloomRouter.addPool(address(mockBloomPool3));

        uint256 amount = 300e6;

        _createLendOrder(alice, amount);
        lenders.push(alice);

        vm.startPrank(owner);
        mockBloomPool.whitelistBorrower(borrower1, true);
        mockBloomPool2.whitelistBorrower(borrower1, true);
        mockBloomPool3.whitelistBorrower(borrower1, true);

        vm.startPrank(borrower1);
        stable.approve(address(mockBloomPool), amount);
        stable.approve(address(mockBloomPool2), amount);
        stable.approve(address(mockBloomPool3), amount);
        stable.mint(borrower1, 1000e6);

        bloomRouter.borrow(lenders, address(mockBloomPool), 50e6);
        bloomRouter.borrow(lenders, address(mockBloomPool2), 50e6);
        bloomRouter.borrow(lenders, address(mockBloomPool3), 50e6);

        assertEq(bloomRouter.poolFromTbyId(0), address(mockBloomPool));
        assertEq(bloomRouter.poolFromTbyId(1), address(mockBloomPool2));
        assertEq(bloomRouter.poolFromTbyId(2), address(mockBloomPool3));

        assertEq(mockBloomPool.balanceOf(alice, 0), 50e6);
        assertEq(mockBloomPool2.balanceOf(alice, 1), 50e6);
        assertEq(mockBloomPool3.balanceOf(alice, 2), 50e6);

        assertEq(mockBloomPool.borrowerAmount(borrower1, 0), 1e6);
        assertEq(mockBloomPool2.borrowerAmount(borrower1, 1), 1e6);
        assertEq(mockBloomPool3.borrowerAmount(borrower1, 2), 1e6);

        _skipAndUpdatePrice(1 days, 100e8, 1);

        vm.startPrank(borrower1);
        (uint256 tbyId,,) = bloomRouter.borrow(lenders, address(mockBloomPool2), 50e6);

        assertEq(tbyId, 1);
        assertEq(mockBloomPool2.balanceOf(alice, 1), 100e6);
        assertEq(mockBloomPool2.borrowerAmount(borrower1, 1), 2e6);

        _skipAndUpdatePrice(2 days, 105e8, 2);

        vm.startPrank(borrower1);
        (tbyId,,) = bloomRouter.borrow(lenders, address(mockBloomPool), 50e6);

        assertEq(tbyId, 3);
        assertEq(mockBloomPool.balanceOf(alice, 3), 50e6);
        assertEq(mockBloomPool.borrowerAmount(borrower1, 3), 1e6);
    }
}
