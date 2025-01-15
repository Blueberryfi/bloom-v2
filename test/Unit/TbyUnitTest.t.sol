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

// import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
// import {Tby} from "@bloom-v2/token/Tby.sol";
// import {BloomTestSetup} from "../BloomTestSetup.t.sol";

// contract TbyUnitTest is BloomTestSetup {
//     function setUp() public override {
//         super.setUp();
//     }

//     function testConstructor() public {
//         Tby newTby = new Tby(address(bloomPool), 18);
//         assertEq(newTby.bloomPool(), address(bloomPool));
//         assertEq(newTby.decimals(), 18);
//     }

//     function testBloomPool() public {
//         assertEq(tby.bloomPool(), address(bloomPool));
//     }

//     function testDecimals() public {
//         assertEq(tby.decimals(), bloomPool.assetDecimals());
//     }

//     function testName() public {
//         assertEq(tby.name(), "Term Bound Yield");
//     }

//     function testSymbol() public {
//         assertEq(tby.symbol(), "TBY");
//     }

//     function testUri() public {
//         assertEq(tby.uri(1), "https://bloom.garden/live");
//     }

//     function testNonBloomCaller() public {
//         vm.startPrank(rando);

//         // Revert open
//         vm.expectRevert(Errors.NotBloom.selector);
//         tby.mint(0, alice, 1e6);
//     }
// }
