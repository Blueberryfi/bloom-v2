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

import {ERC1155} from "@solady/tokens/ERC1155.sol";
import {FixedPointMathLib as Math} from "@solady/utils/FixedPointMathLib.sol";

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {ITby} from "@bloom-v2/interfaces/ITby.sol";

/**
 * @title Tby
 * @notice Tby or Term Bound Yield tokens represent a lenders's position in the Bloom v2 protocol.
 */
abstract contract Tby is ITby, ERC1155 {
    using Math for uint256;

    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of the user's total supply of LTby.
    mapping(uint256 => uint256) private _totalSupply;

    /*///////////////////////////////////////////////////////////////
                                Immutables    
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the token.
    string private immutable _name;

    /// @notice The symbol of the token.
    string private immutable _symbol;

    /// @notice The number of decimals for the token.
    uint8 private immutable _decimals;

    /*///////////////////////////////////////////////////////////////
                            Constructor    
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbolSuffix_, uint8 decimals_) {
        _name = string.concat("Term Bound Yield - ", name_);
        _symbol = string.concat("TBY-", symbolSuffix_);
        _decimals = decimals_;
    }

    /*///////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITby
    function name() external pure returns (string memory) {
        return _name;
    }

    /// @inheritdoc ITby
    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    /// @inheritdoc ITby
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc ITby
    function totalSupply(uint256 id) public view returns (uint256) {
        return _totalSupply[id];
    }

    /// @inheritdoc ERC1155
    function uri(uint256 id) public view virtual override returns (string memory) {
        return string.concat("https://bloom.garden/", _symbol, "/", id);
    }

    /**
     * @notice Mints Tby tokens to an account.
     * @dev This function is overridden to update the total supply of Tby.
     * @param account The address of the account to mint to.
     * @param id The Tby id.
     * @param amount The amount to mint.
     */
    function _mint(address account, uint256 id, uint256 amount, bytes memory data) internal override {
        _totalSupply[id] += amount;
        super._mint(account, id, amount, "");
        emit Mint(account, id, amount);
    }

    /**
     * @notice Burns Tby tokens from an account.
     * @dev This function is overridden to update the total supply of Tby.
     * @param id The Tby id.
     * @param account The address of the account to burn from.
     * @param amount The amount to burn.
     */
    function _burn(uint256 id, address account, uint256 amount) internal override {
        _totalSupply[id] -= amount;
        super._burn(account, id, amount);
        emit Burn(account, id, amount);
    }
}
