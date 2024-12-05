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

import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {CCIPReceiverModule} from "@bloom-v2/borrow-modules/cross-chain/CCIPReceiverModule.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {MockAMM} from "./MockAMM.sol";

contract MockCCIPDstModule is CCIPReceiverModule {
    using SafeERC20 for IERC20;

    MockAMM public mockAmm;

    constructor(
        address asset_,
        address rwa_,
        address linkToken_,
        uint64 srcChainId_,
        address ccipRouter,
        address ccipSender_,
        address amm_,
        address owner_
    ) CCIPReceiverModule(asset_, rwa_, linkToken_, srcChainId_, ccipRouter, ccipSender_, owner_) {
        require(amm_ != address(0), Errors.ZeroAddress());
        mockAmm = MockAMM(amm_);
    }

    function _purchaseRwa(address, /*borrower*/ uint256 assetAmount, uint256 rwaAmount) internal virtual override {
        IERC20(_asset).forceApprove(address(mockAmm), assetAmount);
        mockAmm.swap(_asset, _rwa, assetAmount, rwaAmount);
    }

    function _repayRwa(address, /*borrower*/ uint256 rwaAmount, uint256 assetAmount) internal virtual override {
        IERC20(_asset).forceApprove(address(mockAmm), assetAmount);
        mockAmm.swap(_rwa, _asset, rwaAmount, assetAmount);
    }
}
