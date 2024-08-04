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

import {BloomPool} from "@bloom-v2/BloomPool.sol";
import {IOrderbook} from "@bloom-v2/interfaces/IOrderbook.sol";

/**
 * @title LTby
 * @notice LTby or lenderTBYs are tokens representing a lenders's position in the Bloom v2 protocol.
 */
contract LTby is ERC1155 {
    using Math for uint256;

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

    function decimals() external view returns (uint8) {
        return _decimals;
    }

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

    /**
     * @notice Opens a new order in the orderbook.
     * @dev Only the BloomPool can call this function
     * @param amount The amount of underlying tokens being placed into the orderbook.
     */
    function open(address account, uint256 amount) external onlyBloom {
        _mint(account, uint256(IOrderbook.OrderType.OPEN), amount, "");
    }

    /**
     * @notice Close an order in the orderbook.
     * @dev Only the BloomPool can call this function
     * @param amount The amount of underlying tokens to remove from the orderbook.
     */
    function close(
        address account,
        uint256 id,
        uint256 amount
    ) external onlyBloom {
        _burn(account, id, amount);
    }

    /**
     * @notice The order is staged for the market maker.
     * @dev The staging process occurs after the order is matched by the borrower.
     * @dev Only the BloomPool can call this function.
     * @param amount The amount of underlying tokens that have been matched.
     */
    function stage(address account, uint256 amount) external onlyBloom {
        _burn(account, uint256(IOrderbook.OrderType.OPEN), amount);
        _mint(account, uint256(IOrderbook.OrderType.MATCHED), amount, "");
    }

    /**
     * @notice Called to redeem underlying tokens and realize yield.
     * @dev This can only occur post the maturity date of the token.
     * @dev Only the BloomPool can call this function.
     * @param amount The amount of underlying tokens that have been matched.
     */
    function redeem(uint256 amount) external onlyBloom {
        /// Not implemented at this time
    }

    function openBalance(address account) public view returns (uint256) {
        return balanceOf(account, uint256(IOrderbook.OrderType.OPEN));
    }

    function matchedBalance(address account) public view returns (uint256) {
        return balanceOf(account, uint256(IOrderbook.OrderType.MATCHED));
    }

    function liveBalance(address account) public view returns (uint256) {
        return balanceOf(account, uint256(IOrderbook.OrderType.LIVE));
    }

    function totalValueLocked(
        address account
    ) external view returns (uint256 amount) {
        amount += openBalance(account);
        amount += matchedBalance(account);
        amount += liveBalance(account);
    }

    function name() external pure returns (string memory) {
        return "Lender TBY";
    }

    function symbol() external pure returns (string memory) {
        return "lTBY";
    }
}
