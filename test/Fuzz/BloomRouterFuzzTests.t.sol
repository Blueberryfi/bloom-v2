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

import {BloomRouter} from "@bloom-v2/BloomRouter.sol";
import {IBloomRouter} from "@bloom-v2/interfaces/IBloomRouter.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";
import {MockBloomPool} from "../mocks/MockBloomPool.sol";

contract BloomRouterFuzzTests is BloomTestSetup {
    function setUp() public {
        _setUp(address(0), address(0));
    }

    function testLendOrder(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e6);
        stable.mint(alice, amount);

        uint256 preAliceBalance = stable.balanceOf(alice);

        vm.startPrank(alice);
        stable.approve(address(bloomRouter), amount);
        bloomRouter.lendOrder(amount);
        vm.stopPrank();

        // Alice Balance Decreases
        assertEq(stable.balanceOf(alice), preAliceBalance - amount);
        // Bloom Pool Balance Increases
        assertEq(stable.balanceOf(address(bloomRouter)), amount);

        // Order state increases
        assertEq(bloomRouter.amountOpen(alice), amount);
        assertEq(bloomRouter.openDepth(), amount);

        // Last Minted Id does not change
        assertEq(bloomRouter.lastMintedId(), type(uint256).max);
    }

    function testDiffDecimals(uint256 stableDecimals, uint256 rwaDecimals) public {
        stableDecimals = bound(stableDecimals, 4, 18);
        rwaDecimals = bound(rwaDecimals, 4, 18);
        uint256 minOrderSize = 10 ** stableDecimals;

        // setup tokens, price feeds, and borrow module
        vm.startPrank(owner);

        MockERC20 s = new MockERC20("Stable", "STABLE", uint8(stableDecimals));
        MockERC20 r = new MockERC20("RWA", "RWA", uint8(rwaDecimals));

        BloomRouter router = new BloomRouter(address(s), minOrderSize, owner);

        // setup borrow module
        MockBloomPool pool = new MockBloomPool(
            "Mock Bloom Pool",
            "Test",
            address(router),
            address(r),
            address(priceFeed),
            uint8(stableDecimals),
            50e18,
            0.995e18,
            owner
        );
        pool.whitelistBorrower(borrower1, true);
        // Add module to pool
        router.addPool(address(pool));

        // Alice lends
        uint256 amount = 100 * 10 ** stableDecimals;
        vm.startPrank(alice);
        s.mint(alice, amount);
        s.approve(address(router), amount);
        router.lendOrder(amount);
        lenders.push(alice);

        // borrower borrows
        vm.startPrank(borrower1);
        uint256 bCollateral = 2 * 10 ** stableDecimals;
        s.mint(borrower1, bCollateral);
        s.approve(address(pool), bCollateral);
        router.borrow(lenders, address(pool), amount);

        assertEq(pool.balanceOf(alice, 0), amount);
        assertEq(pool.tbyCollateral(0).rwaAmount, 102 * 10 ** (rwaDecimals - 2));

        _skipAndUpdatePrice(180 days, 105e8, 2);

        assertEq(pool.getRate(0), 1.04975e18);

        router.repay(0);

        assertEq(pool.tbyCollateral(0).assetAmount, 1071 * 10 ** (stableDecimals - 1));
        assertEq(pool.tbyCollateral(0).rwaAmount, 0);

        uint256 expectedLenderReturn = 104975 * 10 ** (stableDecimals - 3);
        uint256 expectedBorrowerReturn = 2125 * 10 ** (stableDecimals - 3);

        assertEq(pool.lenderReturns(0), expectedLenderReturn);
        assertEq(pool.borrowerReturns(0), expectedBorrowerReturn);

        vm.startPrank(alice);
        pool.setApprovalForAll(address(router), true);
        router.redeemLender(0, pool.balanceOf(alice, 0));

        assertEq(s.balanceOf(alice), expectedLenderReturn);
        assertEq(s.balanceOf(address(pool)), expectedBorrowerReturn);

        vm.startPrank(borrower1);
        router.redeemBorrower(0);

        assertEq(s.balanceOf(borrower1), expectedBorrowerReturn);

        assertEq(pool.tbyCollateral(0).assetAmount, 0);
        assertEq(s.balanceOf(address(pool)), 0);
    }
}
