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

import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";
import {ChainlinkOracle} from "@bloom-v2/oracle/chainlink/ChainlinkOracle.sol";
import {CrossAdapter} from "@bloom-v2/oracle/CrossAdapter.sol";
import {BloomOracle} from "@bloom-v2/oracle/BloomOracle.sol";
import {Tby} from "@bloom-v2/token/Tby.sol";

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";
import {MockBorrowModule} from "../mocks/MockBorrowModule.sol";

contract BloomPoolFuzzTests is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function testLendOrder(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e6);
        stable.mint(alice, amount);

        uint256 preAliceBalance = stable.balanceOf(alice);

        vm.startPrank(alice);
        stable.approve(address(bloomPool), amount);
        bloomPool.lendOrder(amount);
        vm.stopPrank();

        // Alice Balance Decreases
        assertEq(stable.balanceOf(alice), preAliceBalance - amount);
        // Bloom Pool Balance Increases
        assertEq(stable.balanceOf(address(bloomPool)), amount);

        // Order state increases
        assertEq(bloomPool.amountOpen(alice), amount);
        assertEq(bloomPool.openDepth(), amount);

        // Last Minted Id does not change
        assertEq(bloomPool.lastMintedId(), type(uint256).max);
    }

    function testDiffDecimals(uint256 stableDecimals, uint256 rwaDecimals) public {
        stableDecimals = bound(stableDecimals, 4, 18);
        rwaDecimals = bound(rwaDecimals, 4, 18);
        uint256 minOrderSize = 10 ** stableDecimals;

        // setup tokens, price feeds, and borrow module
        vm.startPrank(owner);

        MockERC20 s = new MockERC20("Stable", "STABLE", uint8(stableDecimals));
        MockERC20 r = new MockERC20("RWA", "RWA", uint8(rwaDecimals));

        BloomPool pool = new BloomPool(address(s), minOrderSize, owner);
        Tby newTby = Tby(pool.tby());

        // setup price feeds
        MockPriceFeed sUsdFeed = new MockPriceFeed(8);
        sUsdFeed.setLatestRoundData(1, 1e8, 0, block.timestamp, 1);
        MockPriceFeed rUsdFeed = new MockPriceFeed(8);
        rUsdFeed.setLatestRoundData(1, 100e8, 0, block.timestamp, 1);

        // setup adapters
        ChainlinkOracle sOracle = new ChainlinkOracle(address(s), address(usd), address(sUsdFeed), 1 days);
        ChainlinkOracle rOracle = new ChainlinkOracle(address(r), address(usd), address(rUsdFeed), 1 days);
        CrossAdapter adapter =
            new CrossAdapter(address(r), address(usd), address(s), address(rOracle), address(sOracle));

        // setup bloom oracle
        BloomOracle bloomOracle = new BloomOracle(address(owner));
        bloomOracle.setConfig(address(r), address(usd), address(rOracle));
        bloomOracle.setConfig(address(s), address(usd), address(sOracle));
        bloomOracle.setConfig(address(r), address(s), address(adapter));

        // setup borrow module
        MockBorrowModule borrowModule =
            new MockBorrowModule(address(pool), address(bloomOracle), address(r), 50e18, 0.995e18, owner);
        borrowModule.whitelistBorrower(borrower1, true);
        // Add module to pool
        pool.addBorrowModule(address(borrowModule));

        // Alice lends
        uint256 amount = 100 * 10 ** stableDecimals;
        vm.startPrank(alice);
        s.mint(alice, amount);
        s.approve(address(pool), amount);
        pool.lendOrder(amount);
        lenders.push(alice);

        // borrower borrows
        vm.startPrank(borrower1);
        uint256 bCollateral = 2 * 10 ** stableDecimals;
        s.mint(borrower1, bCollateral);
        s.approve(address(borrowModule), bCollateral);
        pool.borrow(lenders, address(borrowModule), amount);

        assertEq(newTby.balanceOf(alice, 0), amount);
        assertEq(borrowModule.tbyCollateral(0).rwaAmount, 102 * 10 ** (rwaDecimals - 2));

        skip(180 days);
        vm.startPrank(owner);
        sUsdFeed.setLatestRoundData(2, 1e8, 0, block.timestamp, 2);
        rUsdFeed.setLatestRoundData(2, 105e8, 0, block.timestamp, 2);
        vm.stopPrank();

        assertEq(borrowModule.getRate(0), 1.04975e18);

        pool.repay(0);

        assertEq(borrowModule.tbyCollateral(0).assetAmount, 1071 * 10 ** (stableDecimals - 1));
        assertEq(borrowModule.tbyCollateral(0).rwaAmount, 0);

        uint256 expectedLenderReturn = 104975 * 10 ** (stableDecimals - 3);
        uint256 expectedBorrowerReturn = 2125 * 10 ** (stableDecimals - 3);

        assertEq(borrowModule.lenderReturns(0), expectedLenderReturn);
        assertEq(borrowModule.borrowerReturns(0), expectedBorrowerReturn);

        vm.startPrank(alice);
        Tby(newTby).setApprovalForAll(address(pool), true);
        pool.redeemLender(0, newTby.balanceOf(alice, 0));

        assertEq(s.balanceOf(alice), expectedLenderReturn);
        assertEq(s.balanceOf(address(borrowModule)), expectedBorrowerReturn);

        vm.startPrank(borrower1);
        pool.redeemBorrower(0);

        assertEq(s.balanceOf(borrower1), expectedBorrowerReturn);

        assertEq(borrowModule.tbyCollateral(0).assetAmount, 0);
        assertEq(s.balanceOf(address(borrowModule)), 0);
    }
}
