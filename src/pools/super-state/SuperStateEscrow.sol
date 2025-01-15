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

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {BloomPool} from "@bloom-v2/pools/BloomPool.sol";
import {IRedemptionIdle} from "@bloom-v2/interfaces/super-state/IRedemptionIdle.sol";
import {ISuperstateToken} from "@bloom-v2/interfaces/super-state/ISuperstateToken.sol";
import {ISuperStateEscrow} from "@bloom-v2/interfaces/super-state/ISuperStateEscrow.sol";

/**
 * @title SuperStateEscrow
 * @notice To interact with SuperState, senders addresses must be unique to the verified borrower. In other words, each borrower
 *         must have their own escrow contract in order to allow for atomic borrowing and repaying of SuperState's USTB.
 */
contract SuperStateEscrow is ISuperStateEscrow {
    /*///////////////////////////////////////////////////////////////
                        Constants & Immutables
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the borrower associated with this escrow contract.
    address internal immutable _borrower;

    /// @notice The address of the Bloom Pool which created this escrow contract.
    address internal immutable _bloomPool;

    /// @notice The address of the underlying asset.
    address internal immutable _asset;

    /// @notice The address of the SuperstateToken (USTB).
    address internal immutable _superstateToken;

    /// @notice The address of SuperState's redemption contract.
    address internal immutable _redemptionContract;

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that ensures that only the Bloom Pool can call a function.
    modifier onlyPool() {
        require(msg.sender == _bloomPool, Errors.InvalidSender());
        _;
    }

    /// @notice Modifier that ensures that only the borrower can call a function.
    modifier onlyBorrower() {
        require(msg.sender == _borrower, Errors.InvalidSender());
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/

    constructor(address borrower_, address redemptionContract_) {
        BloomPool pool = BloomPool(payable(msg.sender));
        _borrower = borrower_;
        _bloomPool = address(pool);
        _asset = pool.asset();
        _superstateToken = pool.rwa();
        _redemptionContract = redemptionContract_;
    }

    /*///////////////////////////////////////////////////////////////
                            External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows the Bloom Pool to purchase USTB on behalf of the borrower.
     * @param totalCollateral The amount of stablecoin being used to purchase USTB.
     * @return The amount of USTB purchased.
     */
    function executePurchase(uint256 totalCollateral) external onlyPool returns (uint256) {
        IERC20 stablecoin = IERC20(_asset);
        stablecoin.approve(_superstateToken, totalCollateral);
        stablecoin.transferFrom(_borrower, address(this), totalCollateral);
        return _subscribe(totalCollateral);
    }

    /**
     * @notice Allows the Bloom Pool to repay the USTB on behalf of the borrower.
     * @param ustbAmount The amount of USTB being repaid.
     * @return The amount of stablecoin received.
     */
    function executeRepayment(uint256 ustbAmount) external onlyPool returns (uint256) {
        IERC20 ustb = IERC20(_superstateToken);
        ustb.approve(_bloomPool, ustbAmount);
        return _redeem(ustbAmount);
    }

    /**
     * @notice Allows the borrower to sweep any remaining stablecoin in the escrow contract.
     * @dev This function can only be called by the borrower.
     * @dev The escrow contract should never have any stablecoin balance unless SuperState reimburses the borrowers
     *      fees given a large volume of transactions over the course of the protocol's lifetime.
     */
    function sweep() external onlyBorrower {
        IERC20 stablecoin = IERC20(_asset);
        stablecoin.transfer(_borrower, stablecoin.balanceOf(address(this)));
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal logic for purchasing USTB.
     * @param stableAmount The amount of stablecoin being used to purchase USTB.
     * @return The amount of USTB purchased.
     */
    function _subscribe(uint256 stableAmount) internal returns (uint256) {
        ISuperstateToken ustb = ISuperstateToken(_superstateToken);
        uint256 ustbBefore = ustb.balanceOf(address(this));
        ustb.subscribe(stableAmount, _asset);
        uint256 ustbAfter = ustb.balanceOf(address(this));
        return ustbAfter - ustbBefore;
    }

    /**
     * @notice Internal logic for redeeming USTB.
     * @dev This function transfers the stablecoin back to the Bloom Pool.
     * @param amount The amount of USTB being redeemed.
     * @return The amount of stablecoin received.
     */
    function _redeem(uint256 amount) internal returns (uint256) {
        IERC20 stablecoin = IERC20(_asset);
        uint256 usdcBefore = stablecoin.balanceOf(address(this));
        IRedemptionIdle(_redemptionContract).redeem(amount);
        uint256 usdcReceived = stablecoin.balanceOf(address(this)) - usdcBefore;
        stablecoin.transfer(msg.sender, usdcReceived);
        return usdcReceived;
    }

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperStateEscrow
    function borrower() external view returns (address) {
        return _borrower;
    }

    /// @inheritdoc ISuperStateEscrow
    function borrowModule() external view returns (address) {
        return _bloomPool;
    }

    /// @inheritdoc ISuperStateEscrow
    function asset() external view returns (address) {
        return _asset;
    }

    /// @inheritdoc ISuperStateEscrow
    function superstateToken() external view returns (address) {
        return _superstateToken;
    }

    /// @inheritdoc ISuperStateEscrow
    function redemptionContract() external view returns (address) {
        return _redemptionContract;
    }
}
