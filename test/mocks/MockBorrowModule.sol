// // SPDX-License-Identifier: MIT
// /*
// ██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
// ██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
// ██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
// ██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
// ██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
// ╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
// */
// pragma solidity 0.8.27;

// import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
// import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// import {BloomOracle} from "@bloom-v2/oracle/BloomOracle.sol";
// import {BorrowModule} from "@bloom-v2/borrow-modules/BorrowModule.sol";

// import {MockAMM} from "./MockAMM.sol";
// import {MockERC20} from "./MockERC20.sol";

// /**
//  * @title MockBorrowModule
//  * @notice An extremely simplified mock borrow module for testing purposes.
//  */
// contract MockBorrowModule is BorrowModule {
//     using SafeERC20 for IERC20;

//     MockAMM internal immutable _amm;

//     constructor(
//         address bloomPool_,
//         address bloomOracle_,
//         address rwa_,
//         uint256 initLeverage,
//         uint256 initSpread,
//         address owner_
//     ) BorrowModule(bloomPool_, bloomOracle_, rwa_, initLeverage, initSpread, owner_) {
//         _amm = new MockAMM();
//     }

//     /**
//      * @notice Purchases the RWA tokens with the underlying asset collateral and stores them within the contract.
//      * @dev This function needs to be implemented by the specific protocol that is being used to purchase the RWA tokens.
//      *      Integration instructions:
//      *         1. Approval has already been set on the BloomPool for the borrow module to spend. This is where the source of funds are coming from.
//      *         2. The borrow module will need to swap the underlying asset collateral for the RWA token.
//      *         3. RWA token should be held within the borrow module's contract.
//      * @param totalCollateral The total amount of collateral being swapped in.
//      * @return The amount of RWA tokens purchased.
//      */
//     function _purchaseRwa(
//         address,
//         /*borrower*/
//         uint256 totalCollateral
//     ) internal override returns (uint256) {
//         IERC20(_asset).forceApprove(address(_amm), totalCollateral);
//         uint256 rwaAmount = _bloomOracle.getQuote(totalCollateral, address(_asset), address(_rwa));
//         _amm.swap(address(_asset), address(_rwa), totalCollateral, rwaAmount);
//         return rwaAmount;
//     }

//     /**
//      * @notice Repays the RWA tokens to the issuer in exchange for the underlying asset collateral.
//      * @dev This function needs to be implemented by the specific protocol that is being used to repay the RWA tokens.
//      *      Integration instructions:
//      *         1. Source of funds are coming from the Borrow Module.
//      *         2. The borrow module will need to swap the RWA token for the underlying asset collateral.
//      *         3. Underlying asset should be held within the borrow module's contract.
//      * @param amount The amount of RWA tokens being repaid.
//      * @return The amount of underlying asset collateral being received.
//      */
//     function _repayRwa(uint256 amount) internal override returns (uint256) {
//         IERC20(_rwa).forceApprove(address(_amm), amount);
//         uint256 assetAmount = _bloomOracle.getQuote(amount, address(_rwa), address(_asset));
//         _amm.swap(address(_rwa), address(_asset), amount, assetAmount);
//         return assetAmount;
//     }

//     /**
//      * @notice Returns the amount of RWA tokens that are being swapped out of the pool.
//      * @dev The out of the box implementation returns all of the RWA tokens that are currently held within the contract.
//      *      Depending on the specific protocol that is being used to purchase the RWA tokens, this function may need to be overridden.
//      * @param tbyId The id of the TBY to get the RWA swap amount for.
//      * @return The amount of RWA tokens being swapped out.
//      */
//     function _getRwaSwapAmount(uint256 tbyId) internal view override returns (uint256) {
//         return _idToCollateral[tbyId].rwaAmount;
//     }
// }
