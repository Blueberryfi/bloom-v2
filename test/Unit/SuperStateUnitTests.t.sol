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

import {SuperStateSetup} from "../utils/super-state/SuperStateSetup.t.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {SuperStateEscrow} from "@bloom-v2/pools/super-state/SuperStateEscrow.sol";
import {SuperStatePool} from "@bloom-v2/pools/super-state/SuperStatePool.sol";
import {IBloomPool} from "@bloom-v2/interfaces/IBloomPool.sol";
import {IRedemptionIdle} from "@bloom-v2/interfaces/super-state/IRedemptionIdle.sol";

contract SuperStateUnitTests is SuperStateSetup {
    function testNewBorrower() public {
        // Should revert if alice tries to create a new borrower account
        vm.startPrank(alice);
        vm.expectRevert();
        ustbPool.createBorrowerAccount(alice);
        vm.stopPrank();

        // Should revert with zero address
        vm.startPrank(owner);
        vm.expectRevert(Errors.ZeroAddress.selector);
        ustbPool.createBorrowerAccount(address(0));
        vm.stopPrank();

        // Should succeed if the owner creates a new borrower account
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IBloomPool.BorrowerKyced(borrower1, true);
        address borrower1Account = ustbPool.createBorrowerAccount(borrower1);
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
        ustbPool.createBorrowerAccount(borrower1);
        vm.stopPrank();

        // Should revert if the borrower already has an account
        vm.startPrank(owner);
        vm.expectRevert(SuperStatePool.ExistingAccount.selector);
        ustbPool.createBorrowerAccount(borrower1);
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

    function testPoolConstructor() public {
        assertEq(ustbPool.redemptionContract(), REDEMPTION_CONTRACT);
    }

    function testCreateBorrowerAccount() public {
        // Random user should not be able to create a borrower account
        vm.startPrank(rando);
        vm.expectRevert();
        ustbPool.createBorrowerAccount(borrower1);
        vm.stopPrank();

        // Create borrower account and verify state
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IBloomPool.BorrowerKyced(borrower1, true);
        SuperStateEscrow escrow = SuperStateEscrow(ustbPool.createBorrowerAccount(borrower1));

        assertEq(ustbPool.borrowersAccount(borrower1), address(escrow));
        assertEq(ustbPool.borrowersAccount(borrower2), address(0));
        assertEq(ustbPool.tbyIdToHashedIds(0).length, 0);

        // Verify escrow contract initialization
        assertEq(escrow.borrower(), borrower1);
        assertEq(escrow.bloomPool(), address(ustbPool));
        assertEq(escrow.asset(), address(stable));
        assertEq(escrow.superstateToken(), address(billToken));
        assertEq(escrow.redemptionContract(), REDEMPTION_CONTRACT);

        // Create a second borrower account
        // Test duplicate account creation
        vm.expectRevert(SuperStatePool.ExistingAccount.selector);
        ustbPool.createBorrowerAccount(borrower1);

        // Test creating account for different borrower works
        address escrow2 = ustbPool.createBorrowerAccount(borrower2);
        assertNotEq(escrow2, address(0));
        assertNotEq(address(escrow), escrow2);

        vm.stopPrank();
    }

    function testDuplicateAccount() public {
        vm.startPrank(owner);
        // Create valid account
        ustbPool.createBorrowerAccount(borrower1);
        // Test duplicate account creation
        vm.expectRevert(SuperStatePool.ExistingAccount.selector);
        ustbPool.createBorrowerAccount(borrower1);
    }
}
