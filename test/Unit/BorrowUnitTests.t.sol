// // SPDX-License-Identifier: MIT
// /*
// ██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
// ██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
// ██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
// ██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
// ██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
// ╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
// */
// pragma solidity 0.8.27;

// import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";
// import {ERC1155} from "@solady/tokens/ERC1155.sol";

// import {BloomPool} from "@bloom-v2/BloomPool.sol";
// import {BloomOracle} from "@bloom-v2/oracle/BloomOracle.sol";
// import {ChainlinkOracle} from "@bloom-v2/oracle/chainlink/ChainlinkOracle.sol";
// import {CrossAdapter} from "@bloom-v2/oracle/CrossAdapter.sol";

// import {BloomTestSetup} from "../BloomTestSetup.t.sol";
// import {MockBorrowModule} from "../mocks/MockBorrowModule.sol";
// import {MockPriceFeed} from "../mocks/MockPriceFeed.sol";

// contract BorrowUnitTests is BloomTestSetup {
//     using FpMath for uint256;

//     MockBorrowModule internal mockBorrowModule;
//     BloomOracle internal bloomOracle;
//     MockPriceFeed internal usdcPriceFeed;

//     function setUp() public override {
//         super.setUp();

//         // deploy Bloom Oracle
//         bloomOracle = new BloomOracle(address(owner));

//         vm.startPrank(owner);
//         usdcPriceFeed = new MockPriceFeed(8);
//         usdcPriceFeed.setLatestRoundData(1, 1e8, 0, block.timestamp, 1);
//         vm.stopPrank();

//         ChainlinkOracle chainlinkOracle1 =
//             new ChainlinkOracle(address(billToken), address(usd), address(priceFeed), 1 days);

//         ChainlinkOracle chainlinkOracle2 =
//             new ChainlinkOracle(address(stable), address(usd), address(usdcPriceFeed), 1 days);

//         CrossAdapter crossAdapter = new CrossAdapter(
//             address(billToken), address(usd), address(stable), address(chainlinkOracle1), address(chainlinkOracle2)
//         );

//         vm.startPrank(owner);
//         bloomOracle.setConfig(address(billToken), address(usd), address(chainlinkOracle1));
//         bloomOracle.setConfig(address(stable), address(usd), address(chainlinkOracle2));
//         bloomOracle.setConfig(address(billToken), address(stable), address(crossAdapter));

//         // deploy mock borrow module
//         mockBorrowModule =
//             new MockBorrowModule(address(bloomPool), address(bloomOracle), address(billToken), 50e18, 0.995e18, owner);

//         bloomPool.addBorrowModule(address(mockBorrowModule));
//     }

//     function testBorrowSingleBorrower() public {
//         uint256 amount = 100e6;

//         _createLendOrder(alice, amount);
//         lenders.push(alice);

//         uint256 borrowAmount = 2e6;
//         stable.mint(borrower1, borrowAmount);

//         vm.startPrank(owner);
//         mockBorrowModule.whitelistBorrower(borrower1, true);
//         vm.stopPrank();

//         vm.startPrank(borrower1);
//         stable.approve(address(mockBorrowModule), borrowAmount);
//         bloomPool.borrow(lenders, address(mockBorrowModule), amount);

//         uint256 lastMintedTby = mockBorrowModule.lastMintedId();

//         assertEq(bloomPool.lastMintedId(), lastMintedTby);
//         assertEq(billToken.balanceOf(address(mockBorrowModule)), 1.02e18);
//         assertEq(stable.balanceOf(address(mockBorrowModule)), 0);

//         // Assert that the state variables are updated correctly
//         assertEq(mockBorrowModule.tbyCollateral(lastMintedTby).rwaAmount, 1.02e18);
//         assertEq(mockBorrowModule.rwaPrice(lastMintedTby).startPrice, 100e18);
//         assertEq(mockBorrowModule.tbyMaturity(lastMintedTby).start, block.timestamp);
//         assertEq(mockBorrowModule.tbyMaturity(lastMintedTby).end, block.timestamp + 180 days);
//     }

//     function testRepaySingleBorrower() public {
//         uint256 amount = 100e6;

//         _createLendOrder(alice, amount);
//         lenders.push(alice);

//         uint256 borrowAmount = 2e6;
//         stable.mint(borrower1, borrowAmount);

//         vm.startPrank(owner);
//         mockBorrowModule.whitelistBorrower(borrower1, true);
//         vm.stopPrank();

//         vm.startPrank(borrower1);
//         stable.approve(address(mockBorrowModule), borrowAmount);
//         bloomPool.borrow(lenders, address(mockBorrowModule), amount);

//         // 5% increase in price ( borrower should earn .125% yield; lender should earn 4.975% yield)
//         uint256 expectedLenderReturn = 104.975e6;
//         uint256 expectedBorrowerReturn = 2.125e6;
//         _skipAndUpdatePrice(180 days, 105e8, 1);

//         vm.startPrank(owner);
//         usdcPriceFeed.setLatestRoundData(2, 1e8, 0, block.timestamp, 1);
//         vm.stopPrank();

//         // validate the rate
//         assertEq(mockBorrowModule.getRate(0), 1.04975e18);

//         // repay the borrow
//         vm.startPrank(borrower1);
//         bloomPool.repay(0);

//         // validate balances
//         assertEq(stable.balanceOf(address(mockBorrowModule)), 107.1e6); // 102 USDC * 5% increase = 107.1 USDC
//         assertEq(billToken.balanceOf(address(mockBorrowModule)), 0);

//         // validate state variables
//         assertEq(mockBorrowModule.tbyCollateral(0).rwaAmount, 0);
//         assertEq(mockBorrowModule.tbyCollateral(0).assetAmount, 107.1e6);
//         assertEq(mockBorrowModule.rwaPrice(0).startPrice, 100e18);
//         assertEq(mockBorrowModule.rwaPrice(0).endPrice, 105e18);

//         // validate lender and borrower returns
//         assertEq(mockBorrowModule.lenderReturns(0), expectedLenderReturn);
//         assertEq(mockBorrowModule.borrowerReturns(0), expectedBorrowerReturn);

//         // Redeem the lender and borrowers funds
//         vm.startPrank(alice);
//         ERC1155(tby).setApprovalForAll(address(bloomPool), true);
//         bloomPool.redeemLender(0, tby.balanceOf(address(alice), 0));
//         vm.startPrank(borrower1);
//         bloomPool.redeemBorrower(0);

//         assertEq(stable.balanceOf(alice), expectedLenderReturn);
//         assertEq(stable.balanceOf(borrower1), expectedBorrowerReturn);

//         assertEq(mockBorrowModule.lenderReturns(0), 0);
//         assertEq(mockBorrowModule.borrowerReturns(0), 0);
//     }

//     function testMultipleBorrowerModules() public {
//         vm.startPrank(owner);
//         MockBorrowModule mockBorrowModule2 =
//             new MockBorrowModule(address(bloomPool), address(bloomOracle), address(billToken), 50e18, 0.995e18, owner);

//         bloomPool.addBorrowModule(address(mockBorrowModule2));

//         MockBorrowModule mockBorrowModule3 =
//             new MockBorrowModule(address(bloomPool), address(bloomOracle), address(billToken), 50e18, 0.995e18, owner);

//         bloomPool.addBorrowModule(address(mockBorrowModule3));

//         uint256 amount = 300e6;

//         _createLendOrder(alice, amount);
//         lenders.push(alice);

//         vm.startPrank(owner);
//         mockBorrowModule.whitelistBorrower(borrower1, true);
//         mockBorrowModule2.whitelistBorrower(borrower1, true);
//         mockBorrowModule3.whitelistBorrower(borrower1, true);

//         vm.startPrank(borrower1);
//         stable.approve(address(mockBorrowModule), amount);
//         stable.approve(address(mockBorrowModule2), amount);
//         stable.approve(address(mockBorrowModule3), amount);
//         stable.mint(borrower1, 1000e6);

//         bloomPool.borrow(lenders, address(mockBorrowModule), 50e6);
//         bloomPool.borrow(lenders, address(mockBorrowModule2), 50e6);
//         bloomPool.borrow(lenders, address(mockBorrowModule3), 50e6);

//         assertEq(bloomPool.tbyModule(0), address(mockBorrowModule));
//         assertEq(bloomPool.tbyModule(1), address(mockBorrowModule2));
//         assertEq(bloomPool.tbyModule(2), address(mockBorrowModule3));

//         assertEq(tby.balanceOf(alice, 0), 50e6);
//         assertEq(tby.balanceOf(alice, 1), 50e6);
//         assertEq(tby.balanceOf(alice, 2), 50e6);

//         assertEq(mockBorrowModule.borrowerAmount(borrower1, 0), 1e6);
//         assertEq(mockBorrowModule2.borrowerAmount(borrower1, 1), 1e6);
//         assertEq(mockBorrowModule3.borrowerAmount(borrower1, 2), 1e6);

//         _skipAndUpdatePrice(1 days, 100e8, 1);
//         vm.startPrank(owner);
//         usdcPriceFeed.setLatestRoundData(2, 1e8, 0, block.timestamp, 1);
//         vm.stopPrank();

//         vm.startPrank(borrower1);
//         (uint256 tbyId,,) = bloomPool.borrow(lenders, address(mockBorrowModule2), 50e6);

//         assertEq(tbyId, 1);
//         assertEq(tby.balanceOf(alice, 1), 100e6);
//         assertEq(mockBorrowModule2.borrowerAmount(borrower1, 1), 2e6);

//         _skipAndUpdatePrice(2 days, 105e8, 2);
//         vm.startPrank(owner);
//         usdcPriceFeed.setLatestRoundData(3, 1e8, 0, block.timestamp, 1);
//         vm.stopPrank();

//         vm.startPrank(borrower1);
//         (tbyId,,) = bloomPool.borrow(lenders, address(mockBorrowModule), 50e6);

//         assertEq(tbyId, 3);
//         assertEq(tby.balanceOf(alice, 3), 50e6);
//         assertEq(mockBorrowModule.borrowerAmount(borrower1, 3), 1e6);
//     }
// }
