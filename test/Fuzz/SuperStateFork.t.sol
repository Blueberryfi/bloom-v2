// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BloomTestSetup} from "../BloomTestSetup.t.sol";
import {BloomPool, IBloomPool} from "@bloom-v2/pools/BloomPool.sol";
import {SuperStatePool} from "@bloom-v2/pools/super-state/SuperStatePool.sol";
import {SuperStateEscrow} from "@bloom-v2/pools/super-state/SuperStateEscrow.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

interface IUstbExtension {
    function calculateSuperstateTokenOut(uint256 inAmount, address stablecoin)
        external
        view
        returns (uint256 superstateTokenOutAmount, uint256 stablecoinInAmountAfterFee, uint256 feeOnStablecoinInAmount);
    function allowListV2() external view returns (address);
}

interface ISuperStateAllowListV2 {
    type EntityId is uint256;

    function setEntityAllowedForFund(EntityId entityId, string calldata fundSymbol, bool isAllowed) external;
    function setEntityIdForAddress(EntityId entityId, address addr) external;
}

interface ISuperStateRedemption {
    function calculateUsdcOut(uint256 superstateTokenInAmount)
        external
        view
        returns (uint256 usdcOutAmount, uint256 usdPerUstbChainlinkRaw);
}

contract SuperStateForkTest is BloomTestSetup {
    uint256 internal mainnetFork;
    SuperStatePool internal ustbPool;

    address internal constant REDEMPTION_CONTRACT = 0x4c21B7577C8FE8b0B0669165ee7C8f67fa1454Cf;
    address internal constant USDC_WHALE = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;
    address internal constant PRICE_FEED = 0xE4fA682f94610cCd170680cc3B045d77D9E528a8;
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
            PRICE_FEED,
            6,
            50e18,
            0.9e18,
            address(owner),
            REDEMPTION_CONTRACT
        );

        vm.rollFork(21675390);
    }

    function testForkSetup() public {
        // Verify that the fork is working
        assertTrue(block.number > 0);
        assertTrue(block.timestamp > 0);
        assertTrue(block.chainid == 1);
    }

    function testNewBorrower() public {
        // Should revert if alice tries to create a new borrower account
        vm.startPrank(alice);
        vm.expectRevert();
        ustbPool.createNewBorrowerAccount(alice);
        vm.stopPrank();

        // Should revert with zero address
        vm.startPrank(owner);
        vm.expectRevert(Errors.ZeroAddress.selector);
        ustbPool.createNewBorrowerAccount(address(0));
        vm.stopPrank();

        // Should succeed if the owner creates a new borrower account
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IBloomPool.BorrowerKyced(borrower1, true);
        address borrower1Account = ustbPool.createNewBorrowerAccount(borrower1);
        vm.stopPrank();

        // Verify that the borrower account was created
        assertEq(ustbPool.borrowersAccount(borrower1), borrower1Account);
        assertNotEq(borrower1Account, borrower1);

        // Validate the Escrow accounts state
        SuperStateEscrow escrow = SuperStateEscrow(borrower1Account);

        assertEq(escrow.borrower(), borrower1);
        assertEq(escrow.bloomPool(), address(ustbPool));
        assertEq(escrow.asset(), address(stable));
        assertEq(escrow.superstateToken(), address(billToken));
        assertEq(escrow.redemptionContract(), REDEMPTION_CONTRACT);
    }

    function testDuplicateBorrower() public {
        // Should revert if the borrower already has an account
        vm.startPrank(owner);
        ustbPool.createNewBorrowerAccount(borrower1);
        vm.stopPrank();

        // Should revert if the borrower already has an account
        vm.startPrank(owner);
        vm.expectRevert(SuperStatePool.ExistingAccount.selector);
        ustbPool.createNewBorrowerAccount(borrower1);
        vm.stopPrank();
    }

    function testSweep() public {
        SuperStateEscrow escrow = _createBorrowerAccount(borrower1);
        _dealUSDC(address(escrow), 100e6);

        // Should revert if a random address tries to sweep
        vm.startPrank(rando);
        vm.expectRevert(Errors.InvalidSender.selector);
        escrow.sweep();
        vm.stopPrank();

        // Should succeed if the borrower sweeps
        vm.startPrank(borrower1);
        escrow.sweep();
        vm.stopPrank();

        // Verify that the USDC was swept
        assertEq(stable.balanceOf(address(escrow)), 0);
        assertEq(stable.balanceOf(address(borrower1)), 100e6);
    }

    function testExecutePurchase(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e6);

        SuperStateEscrow escrow = _createBorrowerAccount(borrower1);
        _dealUSDC(address(ustbPool), amount);

        vm.startPrank(address(ustbPool));
        stable.approve(address(escrow), amount);
        vm.stopPrank();

        // Should revert if the borrower tries to purchase
        vm.startPrank(borrower1);
        vm.expectRevert(Errors.InvalidSender.selector);
        escrow.executePurchase(amount);
        vm.stopPrank();

        // KYC the escrow account within USTB
        _kycWithSuperState(address(escrow));

        // Calculated the expected purchase amount
        (uint256 expectedUstb,,) =
            IUstbExtension(address(billToken)).calculateSuperstateTokenOut(amount, address(stable));

        // Execute purchase
        vm.startPrank(address(ustbPool));
        uint256 ustbPurchased = escrow.executePurchase(amount);
        vm.stopPrank();

        // Verify results
        assertEq(billToken.balanceOf(address(escrow)), expectedUstb);
        assertEq(ustbPurchased, expectedUstb);
        assertEq(stable.balanceOf(address(escrow)), 0);
        assertEq(stable.balanceOf(address(ustbPool)), 0);
    }

    function testExecuteRepayment(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e6);

        SuperStateEscrow escrow = _createBorrowerAccount(borrower1);
        _dealUSDC(address(ustbPool), amount);

        vm.startPrank(address(ustbPool));
        stable.approve(address(escrow), amount);
        vm.stopPrank();

        // Should revert if the borrower tries to purchase
        vm.startPrank(borrower1);
        vm.expectRevert(Errors.InvalidSender.selector);
        escrow.executePurchase(amount);
        vm.stopPrank();

        // KYC the escrow account within USTB
        _kycWithSuperState(address(escrow));

        // Execute purchase
        vm.startPrank(address(ustbPool));
        uint256 ustbPurchased = escrow.executePurchase(amount);
        vm.stopPrank();

        // Should revert if the borrower tries to repay
        vm.startPrank(borrower1);
        vm.expectRevert(Errors.InvalidSender.selector);
        escrow.executeRepayment(ustbPurchased);
        vm.stopPrank();

        // Calculated the expected stablecoin returned amount
        (uint256 expectedStable,) = ISuperStateRedemption(REDEMPTION_CONTRACT).calculateUsdcOut(ustbPurchased);

        // Execute repayment
        vm.startPrank(address(ustbPool));
        uint256 stableReturned = escrow.executeRepayment(ustbPurchased);
        vm.stopPrank();

        // Verify results
        assertEq(stable.balanceOf(address(ustbPool)), expectedStable);
        assertEq(stable.balanceOf(address(escrow)), 0);
        assertEq(billToken.balanceOf(address(escrow)), 0);
        assertEq(stableReturned, expectedStable);
    }

    function _createBorrowerAccount(address borrower) internal returns (SuperStateEscrow) {
        vm.startPrank(owner);
        address borrowerAccount = ustbPool.createNewBorrowerAccount(borrower);
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

    function _dealUSDC(address to, uint256 amount) internal {
        vm.startPrank(USDC_WHALE);
        stable.transfer(to, amount);
        vm.stopPrank();
    }
}
