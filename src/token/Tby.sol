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

import {ERC1155} from "@solady/tokens/ERC1155.sol";
import {FixedPointMathLib as Math} from "@solady/utils/FixedPointMathLib.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {ITby} from "@bloom-v2/interfaces/ITby.sol";

/**
 * @title Tby
 * @notice Tby or Term Bound Yield tokens represent a lenders's position in the Bloom v2 protocol.
 */
contract Tby is ITby, ERC1155 {
    using Math for uint256;

    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the BloomPool contract.
    address private immutable _bloomPool;

    /// @notice The number of decimals for the token.
    uint8 private immutable _decimals;

    /// @notice Mapping of the user's total supply of LTby.
    mapping(uint256 => uint256) private _totalSupply;

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

    /**
     * @notice Mints Tby tokens to an account.
     * @param id The Tby id.
     * @param account The address of the account to mint to.
     * @param amount The amount to mint.
     */
    function mint(uint256 id, address account, uint256 amount) external onlyBloom {
        _totalSupply[id] += amount;
        _mint(account, id, amount, "");
    }

    /**
     * @notice Burns Tby tokens from an account.
     * @param id The Tby id.
     * @param account The address of the account to burn from.
     * @param amount The amount to burn.
     */
    function burn(uint256 id, address account, uint256 amount) external onlyBloom {
        _totalSupply[id] -= amount;
        _burn(account, 0, amount);
    }

    /// @inheritdoc ITby
    function bloomPool() external view returns (address) {
        return _bloomPool;
    }

    /// @inheritdoc ITby
    function name() external pure returns (string memory) {
        return "Term Bound Yield";
    }

    /// @inheritdoc ITby
    function symbol() external pure returns (string memory) {
        return "TBY";
    }

    /// @inheritdoc ITby
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc ITby
    function totalSupply(uint256 id) external view returns (uint256) {
        return _totalSupply[id];
    }

    /// @inheritdoc ERC1155
    function uri(uint256 /*id*/ ) public view virtual override returns (string memory) {
        return "https://bloom.garden/live";
    }
}
