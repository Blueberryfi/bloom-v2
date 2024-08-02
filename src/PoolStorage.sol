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

import {IPoolStorage} from "@bloom-v2/interfaces/IPoolStorage.sol";
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

/**
 * @title Pool Storage
 * @notice Global Storage for Bloom Pools
 */
abstract contract PoolStorage is IPoolStorage {
    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the underlying asset of the Pool.
    address internal immutable _asset;

    /// @notice Decimals of the underlying asset of the Pool.
    uint8 internal immutable _assetDecimals;

    /// @notice Address of the RWA token of the Pool.
    address internal immutable _rwa;

    /// @notice Decimals of the RWA token of the Pool.
    uint8 internal immutable _rwaDecimals;

    /// @notice Mapping of KYCed borrowers.
    mapping(address => bool) internal _borrowers;

    /// @notice Mapping of KYCed market makers.
    mapping(address => bool) internal _marketMakers;

    /*///////////////////////////////////////////////////////////////
                            Modifiers    
    //////////////////////////////////////////////////////////////*/

    modifier KycBorrower() {
        require(_borrowers[msg.sender], Errors.KYCFailed());
        _;
    }

    modifier KycMarketMaker() {
        require(_marketMakers[msg.sender], Errors.KYCFailed());
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(address asset_, address rwa_) {
        _asset = asset_;
        _rwa = rwa_;
    }

    /*///////////////////////////////////////////////////////////////
                            Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPoolStorage
    function asset() external view returns (address) {
        return _asset;
    }

    /// @inheritdoc IPoolStorage
    function rwa() external view returns (address) {
        return _rwa;
    }

    /// @inheritdoc IPoolStorage
    function isKYCedBorrower(
        address account
    ) external view override returns (bool) {
        return _borrowers[account];
    }

    /// @inheritdoc IPoolStorage
    function isKYCedMarketMaker(
        address account
    ) external view override returns (bool) {
        return _marketMakers[account];
    }
}
