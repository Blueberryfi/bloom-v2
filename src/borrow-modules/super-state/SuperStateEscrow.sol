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

import {ISuperstateToken} from "../../interfaces/super-state/ISuperstateToken.sol";
import {IRedemptionIdle} from "../../interfaces/super-state/IRedemptionIdle.sol";
import {BorrowModule} from "../BorrowModule.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";

interface IBorrowerAccount {
    function borrower() external view returns (address);
}

contract SuperStateEscrow is IBorrowerAccount {
    using FpMath for uint256;

    address internal _borrower;
    address internal _borrowModule;
    address internal _underlying;
    address internal _superstateToken;
    address internal _redemptionContract;

    mapping(uint256 => uint256) internal _tbyIdToRwaAmount;

    modifier onlyBorrowModule() {
        require(msg.sender == _borrowModule, "Only the borrow module can call this function");
        _;
    }

    constructor(address borrower_, address redemptionContract_) {
        _borrower = borrower_;
        _borrowModule = msg.sender;

        BorrowModule borrowModule = BorrowModule(payable(msg.sender));
        _underlying = borrowModule.asset();
        _superstateToken = borrowModule.rwa();
        _redemptionContract = redemptionContract_;
    }

    function borrower() external view returns (address) {
        return _borrower;
    }

    function executePurchase(uint256 totalCollateral) external onlyBorrowModule returns (uint256) {
        IERC20 stablecoin = IERC20(_underlying);
        stablecoin.approve(_superstateToken, totalCollateral);
        stablecoin.transferFrom(_borrower, address(this), totalCollateral);
        return _subscribe(totalCollateral);
    }

    function executeRepayment(uint256 amount) external onlyBorrowModule returns (uint256) {
        IERC20 superstateToken = IERC20(_superstateToken);
        uint256 ustbToSpend = FpMath.min(_tbyIdToRwaAmount[amount], amount);
        superstateToken.approve(_borrowModule, ustbToSpend);
        return _redeem(ustbToSpend);
    }

    function _subscribe(uint256 stableAmount) internal returns (uint256) {
        ISuperstateToken superstateToken = ISuperstateToken(_superstateToken);
        uint256 ustbBefore = superstateToken.balanceOf(address(this));
        superstateToken.subscribe(stableAmount, _underlying);
        uint256 ustbAfter = superstateToken.balanceOf(address(this));
        return ustbAfter - ustbBefore;
    }

    function _redeem(uint256 amount) internal returns (uint256) {
        IERC20 stablecoin = IERC20(_underlying);
        uint256 usdcBefore = stablecoin.balanceOf(address(this));
        IRedemptionIdle(_redemptionContract).redeem(amount);
        uint256 usdcReceived = stablecoin.balanceOf(address(this)) - usdcBefore;
        stablecoin.transfer(msg.sender, usdcReceived);
        return usdcReceived;
    }
}
