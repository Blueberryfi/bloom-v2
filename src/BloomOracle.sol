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

import {IOracle} from "@bloom-v2/interfaces/IOracle.sol";

// x -->
/**
 * @title Oracle
 * @notice Oracle contract for Bloom V2, pricing assets in terms of USD scaled to 1e18.
 */
contract BloomOracle is IOracle, Ownable2Step {
    /*///////////////////////////////////////////////////////////////
                            Storage
    //////////////////////////////////////////////////////////////*/
    mapping(address => uint256) private _tbyRatePerSecond;

    mapping(address => address) private _tokenToPriceFeed;

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(address owner_) Ownable(owner_) {
        require(owner_ != address(0), Errors.ZeroAddress());
    }

    function getPrice(address asset) external view override returns (uint256) {}

    function tbyRatePerSecond(address asset) external view override returns (uint256) {
        return _tbyRatePerSecond[asset];
    }

    /**
     * @notice Sets the rate per second of the TBY value acrual.
     * @param rate The new rate per second of the TBY
     */
    function setTbyRate(address lTBY, uint256 rate) external onlyOwner {
        require(lTBY != address(0), Errors.ZeroAddress());
        _tbyRatePerSecond[lTBY] = rate;
    }
}
