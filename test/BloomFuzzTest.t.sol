// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity ^0.8.26;

import {BloomTestSetup} from "./BloomTestSetup.t.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {IPoolStorage} from "@bloom-v2/interfaces/IPoolStorage.sol";
import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

contract BloomFuzzTest is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_SetLeverage(uint16 leverage) public {
        vm.startPrank(owner);

        bool changed = true;
        if (leverage == 0 || leverage > 100) {
            vm.expectRevert(Errors.InvalidLeverage.selector);
            changed = false;
        } else {
            vm.expectEmit(false, false, false, true);
            emit IPoolStorage.LeverageBpsSet(leverage);
        }
        bloomPool.setLeverageBps(leverage);

        changed
            ? assertEq(bloomPool.leverageBps(), leverage)
            : assertEq(bloomPool.leverageBps(), initialLeverageBps);
    }

    function testFuzz_LendOrder(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000_000e6);

        vm.startPrank(alice);
        stable.mint(alice, amount);
        stable.approve(address(bloomPool), amount);

        vm.expectEmit(true, false, false, true);
        emit IOrderbook.OrderCreated(alice, amount);
        bloomPool.lendOrder(amount);

        assertEq(bloomPool.openDepth(), amount);
        assertEq(
            ltby.balanceOf(alice, uint256(IOrderbook.OrderType.OPEN)),
            amount
        );
        assertEq(ltby.openBalance(alice), amount);
    }
}
