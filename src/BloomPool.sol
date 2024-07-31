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

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {Orderbook} from "@bloom-v2/Orderbook.sol";

/**
 * @title BloomPool
 * @notice RWA pool contract facilitating the creation of Term Bound Yield Tokens through lending underlying tokens
 *         to market markers for 6 month terms.
 */
contract BloomPool is Orderbook, Ownable2Step {
    constructor(
        address asset_,
        address rwa_,
        uint8 initLeverageBps,
        address owner
    ) Ownable(owner) Orderbook(asset_, rwa_, initLeverageBps) {}

    function whitelistBorrower(address account) external onlyOwner {
        _borrowers[account] = true;
    }

    function whitelistMarketMaker(address account) external onlyOwner {
        _marketMakers[account] = true;
    }
}
