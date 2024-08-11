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

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";

import {ILTBY} from "@bloom-v2/interfaces/ILTBY.sol";
import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

/**
 * @title LTby
 * @notice LTby or lenderTBYs are tokens representing a lenders's position in the Bloom v2 protocol.
 */
contract LTby is ILTBY, ERC1155 {
    /*///////////////////////////////////////////////////////////////
                                Storage    
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the BloomPool contract.
    address private immutable _bloomPool;

    /// @notice The number of decimals for the token.
    uint8 private immutable _decimals;

    /// @notice Mapping of the user's total supply of LTby.
    mapping(uint256 => mapping(address => uint256)) private _totalSupply;

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

    function mint(uint256 id, address account, uint256 amount) external onlyBloom {
        _totalSupply[id][account] += amount;
        _mint(account, 0, amount, "");
    }

    function burn(uint256 id, address account, uint256 amount) external onlyBloom {
        _totalSupply[id][account] -= amount;
        _burn(account, 0, amount);
    }

    /// @inheritdoc ILTBY
    function bloomPool() external view returns (address) {
        return _bloomPool;
    }

    /// @inheritdoc ILTBY
    function name() external pure returns (string memory) {
        return "Lender TBY";
    }

    /// @inheritdoc ILTBY
    function symbol() external pure returns (string memory) {
        return "lTBY";
    }

    /// @inheritdoc ILTBY
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc ILTBY
    function totalSupply(uint256 id, address account) external view returns (uint256) {
        return _totalSupply[id][account];
    }

    /// @inheritdoc ERC1155
    function uri(uint256 /*id*/ ) public view virtual override returns (string memory) {
        return "https://bloom.garden/live";
    }
}
