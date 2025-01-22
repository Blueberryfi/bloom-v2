// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IUstbExtension {
    function calculateSuperstateTokenOut(uint256 inAmount, address stablecoin)
        external
        view
        returns (uint256 superstateTokenOutAmount, uint256 stablecoinInAmountAfterFee, uint256 feeOnStablecoinInAmount);
    function allowListV2() external view returns (address);
}
