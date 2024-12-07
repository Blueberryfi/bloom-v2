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

import {BorrowModule} from "@bloom-v2/borrow-modules/BorrowModule.sol";
import {SuperStateEscrow} from "./SuperStateEscrow.sol";
import {IRedemptionIdle} from "../../interfaces/super-state/IRedemptionIdle.sol";

contract SuperStateModule is BorrowModule {
    mapping(address => address) internal _borrowerToAccount;

    mapping(uint256 => bytes32[]) internal _tbyIdToHashedIds;

    /// @notice Mapping of hashed TBY id and borrower address to the account data.
    mapping(bytes32 => AccountData) internal _idToAccountData;

    struct AccountData {
        address escrow;
        uint256 rwaAmount;
    }

    address internal _redemptionContract;

    constructor(
        address bloomPool_,
        address bloomOracle_,
        address rwa_,
        uint256 initLeverage,
        uint256 initSpread,
        address owner_,
        address redemptionContract
    ) BorrowModule(bloomPool_, bloomOracle_, rwa_, initLeverage, initSpread, owner_) {
        _redemptionContract = redemptionContract;
    }

    /**
     * @notice Creates a new borrower account for the given borrower
     * @dev If the borrower has never been whitelisted, this function will also whitelist them
     * @param borrower The address of the borrower
     * @return account The address of the new borrower account
     */
    function createNewBorrowerAccount(address borrower) external onlyOwner returns (address account) {
        require(borrower != address(0), "Borrower cannot be the zero address");
        require(_borrowerToAccount[borrower] == address(0), "Borrower already has an account");

        account = address(new SuperStateEscrow(borrower, _redemptionContract));
        _borrowerToAccount[borrower] = account;
        whitelistBorrower(borrower, true);
    }

    function _purchaseRwa(address borrower, uint256 totalCollateral)
        internal
        virtual
        override
        returns (uint256 rwaAmount)
    {
        SuperStateEscrow escrow = SuperStateEscrow(_borrowerToAccount[borrower]);
        bytes32 hashedId = keccak256(abi.encodePacked(_lastMintedId, borrower));
        AccountData storage data = _idToAccountData[hashedId];

        if (data.escrow == address(0)) {
            data.escrow = address(escrow);
            _tbyIdToHashedIds[_lastMintedId].push(hashedId);
        }

        rwaAmount = escrow.executePurchase(totalCollateral);
        data.rwaAmount += rwaAmount;
    }

    function _repayRwa(uint256 rwaAmount) internal virtual override returns (uint256 totalRepaid) {
        bytes32[] storage hashedIds = _tbyIdToHashedIds[_lastMintedId];
        uint256 len = hashedIds.length;
        if (len == 0) return 0;
        uint256 startIndex = len - 1;
        for (uint256 i = startIndex; i >= 0; --i) {
            AccountData storage data = _idToAccountData[hashedIds[i]];
            uint256 repaid = SuperStateEscrow(data.escrow).executeRepayment(rwaAmount);
            data.rwaAmount -= repaid;
            totalRepaid += repaid;
            if (data.rwaAmount == 0) {
                delete _idToAccountData[hashedIds[i]];
            }
            rwaAmount -= repaid;
            if (rwaAmount == 0) break;
        }
    }

    function _getRwaSwapAmount(uint256 tbyId) internal virtual override returns (uint256 totalRwaAmount) {
        bytes32[] memory hashedIds = _tbyIdToHashedIds[tbyId];
        uint256 ustbBalance = _idToCollateral[tbyId].rwaAmount;
        // Get the total amount of USTB that can be redeemed
        (uint256 maxRedemptionAmount,) = IRedemptionIdle(_redemptionContract).maxUstbRedemptionAmount();

        require(maxRedemptionAmount > 0, "No redeemable liquidity");

        if (maxRedemptionAmount >= ustbBalance) {
            maxRedemptionAmount = ustbBalance;
        }

        uint256 startIndex = hashedIds.length - 1;
        for (uint256 i = startIndex; i >= 0; --i) {
            totalRwaAmount += _idToAccountData[hashedIds[i]].rwaAmount;
            if (totalRwaAmount >= maxRedemptionAmount) {
                return maxRedemptionAmount;
            }
        }
        return totalRwaAmount;
    }
}
