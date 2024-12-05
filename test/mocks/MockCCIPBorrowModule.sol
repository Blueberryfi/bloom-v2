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

import {CCIPSenderModule} from "@bloom-v2/borrow-modules/cross-chain/CCIPSenderModule.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockCCIPBorrowModule is CCIPSenderModule {
    constructor(
        address bloomPool,
        address bloomOracle,
        address rwa,
        uint256 initLeverage,
        uint256 initSpread,
        uint64 dstChainId,
        address ccipRouter,
        address ccipReceiver,
        address owner
    )
        CCIPSenderModule(bloomPool, bloomOracle, rwa, initLeverage, initSpread, dstChainId, ccipRouter, ccipReceiver, owner)
    {}

    function _afterBorrowMessage(uint256 rwaAmount) internal virtual override {
        MockERC20(address(_rwa)).mint(address(this), rwaAmount);
    }

    function _beforeRepayMessage(uint256 rwaAmount) internal virtual override {
        MockERC20(address(_rwa)).burn(address(this), rwaAmount);
    }
}
