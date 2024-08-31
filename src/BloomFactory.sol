// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {BloomPool} from "@bloom-v2/BloomPool.sol";

/**
 * @title BloomFactory
 * @notice Factory contract for creating BloomPool instances
 */
contract BloomFactory is Ownable2Step {
    /*///////////////////////////////////////////////////////////////
                                Events    
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a new BloomPool instance is created
     * @param pool The address of the new BloomPool instance
     * @param asset The underlying asset for the pool
     * @param rwa The RWA token for the pool
     * @param initLeverage The initial leverage for the borrower
     * @param spread The spread between the lender and borrower
     */
    event BloomPoolCreated(address indexed pool, address indexed asset, address indexed rwa, uint256 initLeverage, uint256 spread);

    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of addresses validating if they are from the factory
    mapping(address => bool) private _isFromFactory;

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(address owner_) Ownable(owner_) {
        require(owner_ != address(0), Errors.ZeroAddress());
    }

    /*///////////////////////////////////////////////////////////////
                                Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new BloomPool instance
     * @param asset_ The underlying asset for the pool
     * @param rwa_ The RWA token for the pool
     * @param initLeverage The initial leverage for the borrower
     */
    function createBloomPool(address asset_, address rwa_, address rwaPriceFeed, uint256 initLeverage, uint256 spread)
        external
        onlyOwner
        returns (BloomPool pool)
    {
        pool = new BloomPool(asset_, rwa_, rwaPriceFeed, initLeverage, spread, owner());
        _isFromFactory[address(pool)] = true;
        emit BloomPoolCreated(address(pool), asset_, rwa_, initLeverage, spread);
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
