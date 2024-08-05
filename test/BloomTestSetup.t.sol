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

import {Test, console} from "forge-std/Test.sol";

import {BloomFactory} from "@bloom-v2/BloomFactory.sol";
import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {LTby} from "@bloom-v2/token/LTby.sol";
import {BTby} from "@bloom-v2/token/BTby.sol";

import {MockERC20} from "./mocks/MockERC20.sol";

abstract contract BloomTestSetup is Test {
    BloomFactory internal bloomFactory;
    BloomPool internal bloomPool;
    LTby internal ltby;
    BTby internal btby;
    MockERC20 internal stable;
    MockERC20 internal billToken;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal borrower = makeAddr("borrower");
    address internal marketMaker = makeAddr("marketMaker");
    address internal rando = makeAddr("rando");

    uint16 internal initialLeverageBps = 200;
    uint16 internal constant BPS = 10000;

    function setUp() public virtual {
        bloomFactory = new BloomFactory(owner);
        stable = new MockERC20("Mock USDC", "USDC", 6);
        billToken = new MockERC20("Mock T-Bill Token", "bIb01", 18);

        vm.prank(owner);
        bloomPool = bloomFactory.createBloomPool(
            address(stable),
            address(billToken),
            initialLeverageBps
        );
        vm.stopPrank();

        ltby = LTby(bloomPool.lTby());
        btby = BTby(bloomPool.bTby());
        assertNotEq(address(bloomPool), address(0));
    }

    function _createLendOrder(address account, uint256 amount) internal {
        stable.mint(account, amount);
        vm.startPrank(account);
        stable.approve(address(bloomPool), amount);
        bloomPool.lendOrder(amount);
        vm.stopPrank();
    }
}
