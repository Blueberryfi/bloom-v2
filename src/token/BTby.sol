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

import {ERC20} from "@solady/tokens/ERC20.sol";
import {FixedPointMathLib as Math} from "@solady/utils/FixedPointMathLib.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {IBTBY} from "@bloom-v2/interfaces/IBTBY.sol";

/**
 * @title BTby
 * @notice bTbys or borrowerTBYs are tokens representing a borrower's position in the Bloom v2 protocol.
 */
contract BTby is IBTBY, ERC20 {
    using Math for uint256;

    /*///////////////////////////////////////////////////////////////
                            Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the BloomPool contract.
    address private immutable _bloomPool;

    /// @notice The number of decimals for the token.
    uint8 private immutable _decimals;

    /// @notice Mapping of borrower's to their idle capital.
    mapping(address => uint256) private _idleCapital;

    /*///////////////////////////////////////////////////////////////
                            Modifiers    
    //////////////////////////////////////////////////////////////*/

    modifier onlyBloom() {
        require(msg.sender == _bloomPool, Errors.NotBloom());
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(address bloomPool_, uint8 decimals_) {
        _bloomPool = bloomPool_;
        _decimals = decimals_;
    }

    /*///////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBTBY
    function mint(
        address account,
        uint256 amount
    ) external onlyBloom returns (uint256) {
        uint256 idleUsed = Math.min(idleCapital(account), amount);
        if (idleUsed > 0) {
            _idleCapital[account] -= idleUsed;
            amount -= idleUsed;
            emit IdleCapitalDecreased(account, idleUsed);
        }
        _mint(account, amount);
        return amount;
    }

    /// @inheritdoc IBTBY
    function burn(address account, uint256 amount) external onlyBloom {
        _burn(account, amount);
    }

    /// @inheritdoc IBTBY
    function increaseIdleCapital(
        address[] memory accounts,
        uint256[] memory amounts
    ) external onlyBloom {
        uint256 length = accounts.length;
        require(length == amounts.length, Errors.ArrayMismatch());
        for (uint256 i = 0; i < length; i++) {
            _idleCapital[accounts[i]] += amounts[i];
            emit IdleCapitalIncreased(accounts[i], amounts[i]);
        }
    }

    /// @inheritdoc IBTBY
    function withdrawIdleCapital(uint256 amount) external {
        address account = msg.sender;
        require(amount > 0, Errors.ZeroAmount());

        uint256 idleFunds = _idleCapital[account];

        if (amount == type(uint256).max) {
            amount = idleFunds;
        } else {
            require(idleFunds >= amount, Errors.InsufficientBalance());
        }

        _idleCapital[account] -= amount;
        _burn(account, amount);
        BloomPool(_bloomPool).transferAsset(account, amount);

        emit IdleCapitalWithdrawn(account, amount);
    }

    /// @inheritdoc IBTBY
    function idleCapital(address account) public view returns (uint256) {
        return _idleCapital[account];
    }

    /// @inheritdoc IBTBY
    function bloomPool() external view returns (address) {
        return _bloomPool;
    }

    /// @inheritdoc ERC20
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc ERC20
    function name() public pure override returns (string memory) {
        return "Borrower TBY";
    }

    /// @inheritdoc ERC20
    function symbol() public view virtual override returns (string memory) {
        return "bTBY";
    }

    /// @inheritdoc ERC20
    function transfer(
        address /*to*/,
        uint256 /*amount*/
    ) public pure override returns (bool) {
        _revertTransfer();
    }

    /// @inheritdoc ERC20
    function transferFrom(
        address /*from*/,
        address /*to*/,
        uint256 /*amount*/
    ) public pure override returns (bool) {
        _revertTransfer();
    }

    /// @notice Reverts all transfers.
    function _revertTransfer() private pure {
        revert Errors.KYCTokenNotTransferable();
    }
}
