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
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {Tby} from "@bloom-v2/token/Tby.sol";
import {IPoolStorage} from "@bloom-v2/interfaces/IPoolStorage.sol";

/**
 * @title Pool Storage
 * @notice Global Storage for Bloom Pools
 */
abstract contract PoolStorage is IPoolStorage, Ownable2Step {
    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Addresss of the lTby token
    Tby internal _tby;

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

    /// @notice The spread between the rate of the TBY and the rate of the RWA token.
    uint256 internal _spread;

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

    constructor(address asset_, address rwa_, uint256 initLeverage, uint256 initSpread, address owner_)
        Ownable(owner_)
    {
        _asset = asset_;
        _rwa = rwa_;

        uint8 decimals = IERC20Metadata(asset_).decimals();
        _tby = new Tby(address(this), decimals);

        _assetDecimals = decimals;
        _rwaDecimals = IERC20Metadata(rwa_).decimals();

        _setLeverage(initLeverage);
        _setSpread(initSpread);
    }

    /*///////////////////////////////////////////////////////////////
                            Functions    
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Whitelists an address to be a KYCed borrower.
     * @dev Only the owner can call this function.
     * @param account The address of the borrower to whitelist.
     * @param isKyced True to whitelist, false to remove from whitelist.
     */
    function whitelistBorrower(address account, bool isKyced) external onlyOwner {
        _borrowers[account] = isKyced;
        emit BorrowerKyced(account, isKyced);
    }

    /**
     * @notice Whitelists an address to be a KYCed borrower.
     * @dev Only the owner can call this function.
     * @param account The address of the borrower to whitelist.
     * @param isKyced True to whitelist, false to remove from whitelist.
     */
    function whitelistMarketMaker(address account, bool isKyced) external onlyOwner {
        _marketMakers[account] = isKyced;
        emit MarketMakerKyced(account, isKyced);
    }

    /**
     * @notice Updates the leverage for future borrower fills
     * @dev Leverage is scaled to 1e18. (20x leverage = 20e18)
     * @param leverage Updated leverage
     */
    function setLeverage(uint256 leverage) public onlyOwner {
        _setLeverage(leverage);
    }

    /**
     * @notice Updates the spread between the TBY rate and the RWA rate.
     * @param spread_ The new spread value.
     */
    function setSpread(uint256 spread_) public onlyOwner {
        _setSpread(spread_);
    }

    /// @inheritdoc IPoolStorage
    function tby() external view returns (address) {
        return address(_tby);
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
    function isKYCedBorrower(address account) public view override returns (bool) {
        return _borrowers[account];
    }

    /// @inheritdoc IPoolStorage
    function isKYCedMarketMaker(address account) public view override returns (bool) {
        return _marketMakers[account];
    }

    /// @inheritdoc IPoolStorage
    function spread() external view override returns (uint256) {
        return _spread;
    }

    /// @notice Internal logic to set the leverage.
    function _setLeverage(uint256 leverage) internal {
        require(leverage >= 1e18 && leverage < 100e18, Errors.InvalidLeverage());
        _leverage = leverage;
        emit LeverageSet(leverage);
    }

    /// @notice Internal logic to set the spread.
    function _setSpread(uint256 spread_) internal {
        require(spread_ >= 0.85e18, Errors.InvalidSpread());
        _spread = spread_;
        emit SpreadSet(spread_);
    }
}
