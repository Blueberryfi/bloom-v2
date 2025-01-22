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

import {FixedPointMathLib as FpMath} from "@solady/utils/FixedPointMathLib.sol";
import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {BloomPool} from "@bloom-v2/pools/BloomPool.sol";
import {SuperStateEscrow} from "./SuperStateEscrow.sol";
import {IRedemptionIdle} from "@bloom-v2/interfaces/super-state/IRedemptionIdle.sol";

contract SuperStatePool is BloomPool {
    using FpMath for uint256;
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                                Structs
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Data associated with a borrower's account.
     * @param escrow The address of the escrow contract associated with the borrower.
     * @param rwaAmount The amount of RWA tokens associated with the borrower.
     */
    struct AccountData {
        address escrow;
        uint256 rwaAmount;
    }

    /*///////////////////////////////////////////////////////////////
                                Errors
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a borrower already has an account.
    error ExistingAccount();

    /// @notice Emitted when there is no redeemable liquidity from SuperState's redemption contract.
    error NoRedeemableLiquidity();

    /*///////////////////////////////////////////////////////////////
                                Storage 
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of borrower addresses to their associated escrow addresses.
    mapping(address => address) internal _borrowerToAccount;

    /// @notice Mapping of TBY ids to the hashed ids of the borrower accounts.
    mapping(uint256 => bytes32[]) internal _tbyIdToHashedIds;

    /// @notice Mapping of hashed TBY id and borrower address to the account data.
    mapping(bytes32 => AccountData) internal _idToAccountData;

    /*///////////////////////////////////////////////////////////////
                                Constants
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the redemption contract.
    address internal immutable _redemptionContract;

    /*///////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory name_,
        string memory symbolSuffix_,
        address bloomPool_,
        address rwa_,
        uint8 assetDecimals_,
        uint256 initLeverage,
        uint256 initSpread,
        address owner_,
        address redemptionContract
    ) BloomPool(name_, symbolSuffix_, bloomPool_, rwa_, assetDecimals_, initLeverage, initSpread, owner_) {
        _redemptionContract = redemptionContract;
    }

    /*///////////////////////////////////////////////////////////////
                            External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new borrower account for the given borrower
     * @dev If the borrower has never been whitelisted, this function will also whitelist them
     * @param borrower The address of the borrower
     * @return account The address of the new borrower account
     */
    function createBorrowerAccount(address borrower) external onlyOwner returns (address account) {
        require(borrower != address(0), Errors.ZeroAddress());
        require(_borrowerToAccount[borrower] == address(0), ExistingAccount());

        account = address(new SuperStateEscrow(borrower, _redemptionContract));
        _borrowerToAccount[borrower] = account;
        whitelistBorrower(borrower, true);
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BloomPool
    function _purchaseRwa(address borrower, uint256 totalCollateral)
        internal
        virtual
        override
        returns (uint256 rwaAmount)
    {
        SuperStateEscrow escrow = SuperStateEscrow(_borrowerToAccount[borrower]);
        uint256 tbyId = _lastMintedId;
        bytes32 hashedId = keccak256(abi.encodePacked(tbyId, borrower));
        AccountData storage data = _idToAccountData[hashedId];

        if (data.escrow == address(0)) {
            data.escrow = address(escrow);
            _tbyIdToHashedIds[tbyId].push(hashedId);
        }
        _asset.forceApprove(address(escrow), totalCollateral);
        rwaAmount = escrow.executePurchase(totalCollateral);
        data.rwaAmount += rwaAmount;
    }

    /// @inheritdoc BloomPool
    function _repayRwa(uint256 rwaAmount) internal virtual override returns (uint256 totalRepaid) {
        uint256 tbyId = _lastMintedId;
        bytes32[] storage hashedIds = _tbyIdToHashedIds[tbyId];

        uint256 len = hashedIds.length;
        if (len == 0) return 0;

        uint256 startIndex = len - 1;
        for (uint256 i = startIndex; i >= 0; --i) {
            AccountData storage data = _idToAccountData[hashedIds[i]];

            uint256 amountToRepay = FpMath.min(data.rwaAmount, rwaAmount);
            data.rwaAmount -= amountToRepay;
            totalRepaid += amountToRepay;
            rwaAmount -= SuperStateEscrow(data.escrow).executeRepayment(amountToRepay);

            if (data.rwaAmount == 0) delete _idToAccountData[hashedIds[i]];
            if (rwaAmount == 0) break;
        }
    }

    /// @inheritdoc BloomPool
    function _getRwaSwapAmount(uint256 tbyId) internal view virtual override returns (uint256 totalRwaAmount) {
        bytes32[] memory hashedIds = _tbyIdToHashedIds[tbyId];
        uint256 ustbBalance = _idToCollateral[tbyId].rwaAmount;
        // Get the total amount of USTB that can be redeemed
        (uint256 maxRedemptionAmount,) = IRedemptionIdle(_redemptionContract).maxUstbRedemptionAmount();

        require(maxRedemptionAmount > 0, NoRedeemableLiquidity());

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

    function _getRwaPrice() internal view override returns (uint256) {
        // We use SuperStates ```calculateUsdcOut``` function instead of the direct price feed
        //    to account for fees that are incurred when redeeming USTB
        (uint256 usdcOutAmount,) = IRedemptionIdle(_redemptionContract).calculateUsdcOut(1e18);
        return usdcOutAmount;
    }

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the escrow contract associated with the given borrower.
    function borrowersAccount(address borrower) external view returns (address) {
        return _borrowerToAccount[borrower];
    }

    /// @notice Returns the amount of RWA tokens associated with the given borrower.
    function borrowersRwaAmount(address borrower) external view returns (uint256) {
        bytes32 hashedId = keccak256(abi.encodePacked(_lastMintedId, borrower));
        return _idToAccountData[hashedId].rwaAmount;
    }

    /// @notice Returns the hashed ids associated with the given TBY id.
    function tbyIdToHashedIds(uint256 tbyId) external view returns (bytes32[] memory) {
        return _tbyIdToHashedIds[tbyId];
    }

    /// @notice Returns the address of the redemption contract.
    function redemptionContract() external view returns (address) {
        return _redemptionContract;
    }
}
