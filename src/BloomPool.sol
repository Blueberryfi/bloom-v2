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

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {Orderbook} from "@bloom-v2/Orderbook.sol";

/**
 * @title BloomPool
 * @notice RWA pool contract facilitating the creation of Term Bound Yield Tokens through lending underlying tokens
 *         to market markers for 6 month terms.
 */
contract BloomPool is Orderbook, Ownable2Step {
    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(
        address asset_,
        address rwa_,
        uint16 initLeverageBps,
        address owner_
    ) Ownable(owner_) Orderbook(asset_, rwa_, initLeverageBps) {}

    /*///////////////////////////////////////////////////////////////
                                Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Whitelists an address to be a KYCed borrower.
     * @dev Only the owner can call this function.
     * @param account The address of the borrower to whitelist.
     */
    function whitelistBorrower(address account) external onlyOwner {
        _borrowers[account] = true;
        emit BorrowerKYCed(account);
    }

    /**
     * @notice Whitelists an address to be a KYCed borrower.
     * @dev Only the owner can call this function.
     * @param account The address of the borrower to whitelist.
     */
    function whitelistMarketMaker(address account) external onlyOwner {
        _marketMakers[account] = true;
        emit MarketMakerKYCed(account);
    }

    /**
     * @notice Updates the leverage value for future borrower fills
     * @param leverageBps_ Updated leverage Bips
     */
    function setLeverageBps(uint16 leverageBps_) external onlyOwner {
        require(
            leverageBps_ > 0 && leverageBps_ <= 100,
            Errors.InvalidLeverage()
        );
        _leverageBps = leverageBps_;
        emit LeverageBpsSet(leverageBps_);
    }
}
