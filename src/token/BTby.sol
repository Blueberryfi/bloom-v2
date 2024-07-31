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

/**
 * @title BTby
 * @notice bTbys or borrowerTBYs are tokens representing a borrower's position in the Bloom v2 protocol.
 */
contract BTby is ERC20 {
    using Math for uint256;

    /// @notice Address of the BloomPool contract.
    address private immutable _bloomPool;

    /// @notice Mapping of borrower's to their idle capital.
    mapping(address => uint256) private _idleCapital;

    modifier onlyBloom() {
        require(msg.sender == _bloomPool, Errors.NotBloom());
        _;
    }

    constructor(address bloomPool_) {
        _bloomPool = bloomPool_;
    }

    function mint(
        address account,
        uint256 amount
    ) external onlyBloom returns (uint256) {
        uint256 idleCapital = _idleCapital[account];
        uint256 idleUsed = Math.min(idleCapital, amount);
        if (idleUsed > 0) {
            _idleCapital[account] -= idleUsed;
            amount -= idleUsed;
        }
        _mint(account, amount);
        return amount;
    }

    function burn(address account, uint256 amount) external onlyBloom {
        _burn(account, amount);
    }

    function increaseIdleCapital(
        address[] memory account,
        uint256[] memory amount
    ) external onlyBloom {
        uint256 length = account.length;
        require(length == amount.length, Errors.ArrayMismatch());
        for (uint256 i = 0; i < length; i++) {
            _idleCapital[account[i]] += amount[i];
        }
    }

    function withdrawIdleCapital(address account) external {
        uint256 amount = _idleCapital[account];
        require(amount > 0, Errors.ZeroAmount());
        _idleCapital[account] -= amount;
        _burn(account, amount);
    }

    function name() public pure override returns (string memory) {
        return "Borrower TBY";
    }

    function symbol() public view virtual override returns (string memory) {
        return "bTBY";
    }
}
