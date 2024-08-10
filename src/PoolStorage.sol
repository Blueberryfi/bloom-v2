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

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {LTby} from "@bloom-v2/token/LTby.sol";
import {BTby} from "@bloom-v2/token/BTby.sol";
import {IPoolStorage} from "@bloom-v2/interfaces/IPoolStorage.sol";
import {IOracle} from "@bloom-v2/interfaces/IOracle.sol";

/**
 * @title Pool Storage
 * @notice Global Storage for Bloom Pools
 */
abstract contract PoolStorage is IPoolStorage {
    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Addresss of the lTby token
    LTby internal _lTby;

    /// @notice Addresss of the bTby token
    BTby internal _bTby;

    /// @notice Address of the Oracle contract.
    IOracle internal immutable _oracle;

    /// @notice Address of the underlying asset of the Pool.
    address internal immutable _asset;

    /// @notice Decimals of the underlying asset of the Pool.
    uint8 internal immutable _assetDecimals;

    /// @notice Address of the RWA token of the Pool.
    address internal immutable _rwa;

    /// @notice Decimals of the RWA token of the Pool.
    uint8 internal immutable _rwaDecimals;

    /// @notice Leverage value for the borrower. scaled by 1e18 (50x leverage == 2% == 0.02e18)
    uint256 internal _leverage;

    /// @notice Mapping of KYCed borrowers.
    mapping(address => bool) internal _borrowers;

    /// @notice Mapping of KYCed market makers.
    mapping(address => bool) internal _marketMakers;

    /*///////////////////////////////////////////////////////////////
                            Modifiers    
    //////////////////////////////////////////////////////////////*/

    modifier KycBorrower() {
        require(isKYCedBorrower(msg.sender), Errors.KYCFailed());
        _;
    }

    modifier KycMarketMaker() {
        require(isKYCedMarketMaker(msg.sender), Errors.KYCFailed());
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(address asset_, address rwa_, address oracle_) {
        _asset = asset_;
        _rwa = rwa_;

        uint8 decimals = IERC20Metadata(asset_).decimals();
        _lTby = new LTby(address(this), oracle_, decimals);
        _bTby = new BTby(address(this), decimals);

        _assetDecimals = decimals;
        _rwaDecimals = IERC20Metadata(rwa_).decimals();

        _oracle = IOracle(oracle_);
    }

    /*///////////////////////////////////////////////////////////////
                            Functions    
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPoolStorage
    function lTby() external view returns (address) {
        return address(_lTby);
    }

    /// @inheritdoc IPoolStorage
    function bTby() external view returns (address) {
        return address(_bTby);
    }

    /// @inheritdoc IPoolStorage
    function oracle() external view override returns (address) {
        return address(_oracle);
    }

    /// @inheritdoc IPoolStorage
    function asset() external view returns (address) {
        return _asset;
    }

    /// @inheritdoc IPoolStorage
    function assetDecimals() external view override returns (uint8) {
        return _assetDecimals;
    }

    /// @inheritdoc IPoolStorage
    function rwa() external view returns (address) {
        return _rwa;
    }

    /// @inheritdoc IPoolStorage
    function rwaDecimals() external view override returns (uint8) {
        return _rwaDecimals;
    }

    /// @inheritdoc IPoolStorage
    function isKYCedBorrower(
        address account
    ) public view override returns (bool) {
        return _borrowers[account];
    }

    /// @inheritdoc IPoolStorage
    function isKYCedMarketMaker(
        address account
    ) public view override returns (bool) {
        return _marketMakers[account];
    }
}
