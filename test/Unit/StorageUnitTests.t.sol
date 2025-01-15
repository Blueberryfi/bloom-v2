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

// import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";
// import {BloomTestSetup} from "../BloomTestSetup.t.sol";

// contract StorageUnitTests is BloomTestSetup {
//     function setUp() public override {
//         super.setUp();
//     }

//     function testTby() public {
//         assertEq(bloomPool.tby(), address(tby));
//     }

//     function testAsset() public {
//         assertEq(bloomPool.asset(), address(stable));
//     }

//     function testAssetDecimals() public {
//         assertEq(bloomPool.assetDecimals(), stable.decimals());
//     }

//     function testMinOrderSize() public {
//         assertEq(bloomPool.minOrderSize(), 1e6);
//     }

//     function testLastMintedId() public {
//         assertEq(bloomPool.lastMintedId(), type(uint256).max);
//     }
// }
