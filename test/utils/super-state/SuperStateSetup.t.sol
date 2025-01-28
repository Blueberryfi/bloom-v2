// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BloomTestSetup} from "../../BloomTestSetup.t.sol";
import {BloomPool, IBloomPool} from "@bloom-v2/pools/BloomPool.sol";
import {SuperStatePool} from "@bloom-v2/pools/super-state/SuperStatePool.sol";
import {SuperStateEscrow} from "@bloom-v2/pools/super-state/SuperStateEscrow.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {IRedemptionIdle} from "@bloom-v2/interfaces/super-state/IRedemptionIdle.sol";
import {IUstbExtension} from "./interfaces/IUstbExtension.sol";
import {ISuperStateAllowListV2} from "./interfaces/ISuperStateAllowListV2.sol";

abstract contract SuperStateSetup is BloomTestSetup {
    uint256 internal mainnetFork;
    SuperStatePool internal ustbPool;

    address internal constant REDEMPTION_CONTRACT = 0x4c21B7577C8FE8b0B0669165ee7C8f67fa1454Cf;
    address internal constant USDC_WHALE = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;
    address internal constant SUPERSTATE_ADMIN = 0x7747940aDBc7191f877a9B90596E0DA4f8deb2Fe;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("ETH_RPC_URL"));
        vm.selectFork(mainnetFork);

        _setUp(
            address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), // USDC - Mainnet
            address(0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e) // SuperState USTB - Mainnet
        );

        ustbPool = new SuperStatePool(
            "Term Bound Yield - SuperState USTB",
            "USTB",
            address(bloomRouter),
            address(billToken),
            6,
            50e18,
            0.9e18,
            address(owner),
            REDEMPTION_CONTRACT
        );

        vm.startPrank(owner);
        bloomRouter.addPool(address(ustbPool));
        vm.stopPrank();

        vm.rollFork(21675390);
    }

    function testForkSetup() public {
        // Verify that the fork is working
        assertTrue(block.number > 0);
        assertTrue(block.timestamp > 0);
        assertTrue(block.chainid == 1);
    }

    function _createBorrowerAccount(address borrower) internal returns (SuperStateEscrow) {
        vm.startPrank(owner);
        address borrowerAccount = ustbPool.createBorrowerAccount(borrower);
        vm.stopPrank();
        return SuperStateEscrow(borrowerAccount);
    }

    function _kycWithSuperState(address account) internal {
        vm.startPrank(SUPERSTATE_ADMIN);
        address allowListv2 = IUstbExtension(address(billToken)).allowListV2();
        ISuperStateAllowListV2.EntityId entityId = ISuperStateAllowListV2.EntityId.wrap(118);
        ISuperStateAllowListV2(allowListv2).setEntityIdForAddress(entityId, address(account));
        ISuperStateAllowListV2(allowListv2).setEntityAllowedForFund(entityId, "USTB", true);
        vm.stopPrank();
    }

    function _dealUSDC(address to, uint256 amount) internal virtual override {
        vm.startPrank(USDC_WHALE);
        stable.transfer(to, amount);
        vm.stopPrank();
    }
}
