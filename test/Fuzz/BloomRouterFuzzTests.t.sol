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
        _dealUSDC(alice, amount);

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
}
