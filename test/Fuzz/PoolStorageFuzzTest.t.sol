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

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {IPoolStorage} from "@bloom-v2/interfaces/IPoolStorage.sol";

contract PoolStorageFuzzTest is BloomTestSetup {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_SetLeverage(uint256 leverage) public {
        vm.startPrank(owner);

        bool changed = true;
        if (leverage >= 100e18 || leverage < 1e18) {
            vm.expectRevert(Errors.InvalidLeverage.selector);
            changed = false;
        } else {
            vm.expectEmit(false, false, false, true);
            emit IPoolStorage.LeverageSet(leverage);
        }
        bloomPool.setLeverage(leverage);

        changed ? assertEq(bloomPool.leverage(), leverage) : assertEq(bloomPool.leverage(), initialLeverage);
    }

    function testFuzz_SetSpread(uint256 spread) public {
        vm.startPrank(owner);

        bool changed = true;
        if (spread < 0.85e18) {
            vm.expectRevert(Errors.InvalidSpread.selector);
            changed = false;
        } else {
            vm.expectEmit(false, false, false, true);
            emit IPoolStorage.SpreadSet(spread);
        }
        bloomPool.setSpread(spread);

        changed ? assertEq(bloomPool.spread(), spread) : assertEq(bloomPool.spread(), initialSpread);
    }
}
