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
import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {FixedPointMathLib as Math} from "@solady/utils/FixedPointMathLib.sol";

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

    function burn(address account, uint256 amount) external onlyBloom {
        _burn(account, amount);
    }

    function transfer(
        address /*to*/,
        uint256 /*amount*/
    ) public pure override returns (bool) {
        _revertTransfer();
    }

    function transferFrom(
        address /*from*/,
        address /*to*/,
        uint256 /*amount*/
    ) public pure override returns (bool) {
        _revertTransfer();
    }

    function _revertTransfer() private pure {
        revert Errors.KYCTokenNotTransferable();
    }

    function bloomPool() external view returns (address) {
        return _bloomPool;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function increaseIdleCapital(
        address[] memory account,
        uint256[] memory amount
    ) external onlyBloom {
        uint256 length = account.length;
        require(length == amount.length, Errors.ArrayMismatch());
        for (uint256 i = 0; i < length; i++) {
            _idleCapital[account[i]] += amount[i];
            emit IdleCapitalIncreased(account[i], amount[i]);
        }
    }

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

    function idleCapital(address account) public view returns (uint256) {
        return _idleCapital[account];
    }

    function name() public pure override returns (string memory) {
        return "Borrower TBY";
    }

    function symbol() public view virtual override returns (string memory) {
        return "bTBY";
    }
}
