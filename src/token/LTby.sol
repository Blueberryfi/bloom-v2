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

    /// @inheritdoc ILTBY
    function open(address account, uint256 amount) external onlyBloom {
        _mint(account, uint256(IOrderbook.OrderType.OPEN), amount, "");
    }

    /// @inheritdoc ILTBY
    function close(
        address account,
        uint256 id,
        uint256 amount
    ) external onlyBloom {
        _burn(account, id, amount);
    }

    /// @inheritdoc ILTBY
    function stage(address account, uint256 amount) external onlyBloom {
        _burn(account, uint256(IOrderbook.OrderType.OPEN), amount);
        _mint(account, uint256(IOrderbook.OrderType.MATCHED), amount, "");
    }

    /// @inheritdoc ILTBY
    function redeem(uint256 amount) external onlyBloom {
        /// Not implemented at this time
    }

    /// @inheritdoc ILTBY
    function openBalance(address account) public view returns (uint256) {
        return balanceOf(account, uint256(IOrderbook.OrderType.OPEN));
    }

    /// @inheritdoc ILTBY
    function matchedBalance(address account) public view returns (uint256) {
        return balanceOf(account, uint256(IOrderbook.OrderType.MATCHED));
    }

    /// @inheritdoc ILTBY
    function liveBalance(address account) public view returns (uint256) {
        return balanceOf(account, uint256(IOrderbook.OrderType.LIVE));
    }

    /// @inheritdoc ILTBY
    function totalBalance(
        address account
    ) external view returns (uint256 amount) {
        amount += openBalance(account);
        amount += matchedBalance(account);
        amount += liveBalance(account);
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

    /// @inheritdoc ERC1155
    function uri(
        uint256 id
    ) public view virtual override returns (string memory) {
        if (id == 0) {
            return "https://bloom.garden/open";
        }
        if (id == 1) {
            return "https://bloom.garden/matched";
        }
        return "https://bloom.garden/live";
    }
}
