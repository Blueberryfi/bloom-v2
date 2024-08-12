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

    constructor(address asset_, address rwa_, uint256 initLeverage, address owner_)
        Ownable(owner_)
        Orderbook(asset_, rwa_, initLeverage)
    {
        require(owner_ != address(0), Errors.ZeroAddress());
        require(initLeverage >= 1e18 && initLeverage < 100e18, Errors.InvalidLeverage());
    }

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
     * @notice Updates the leverage for future borrower fills
     * @dev Leverage is scaled to 1e18. (20x leverage = 20e18)
     * @param leverage Updated leverage
     */
    function setLeverage(uint256 leverage) external onlyOwner {
        require(leverage >= 1e18 && leverage < 100e18, Errors.InvalidLeverage());
        _leverage = leverage;
        emit LeverageSet(leverage);
    }
}
