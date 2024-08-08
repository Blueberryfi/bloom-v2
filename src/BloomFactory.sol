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

import {BloomPool} from "@bloom-v2/BloomPool.sol";

/**
 * @title BloomFactory
 * @notice Factory contract for creating BloomPool instances
 */
contract BloomFactory is Ownable2Step {
    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of addresses validating if they are from the factory
    mapping(address => bool) private _isFromFactory;

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(address owner_) Ownable(owner_) {}

    /*///////////////////////////////////////////////////////////////
                                Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new BloomPool instance
     * @param asset_ The underlying asset for the pool
     * @param rwa_ The RWA token for the pool
     * @param initLeverage The initial leverage for the borrower
     */
    function createBloomPool(address asset_, address rwa_, uint256 initLeverage)
        external
        onlyOwner
        returns (BloomPool pool)
    {
        pool = new BloomPool(asset_, rwa_, initLeverage, owner());
        _isFromFactory[address(pool)] = true;
    }

    /**
     * @notice Checks if an address is from the factory
     * @param account The address to check
     * @return True if the address is from the factory
     */
    function isFromFactory(address account) external view returns (bool) {
        return _isFromFactory[account];
    }
}
