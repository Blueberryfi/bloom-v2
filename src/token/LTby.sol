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
import {IOracle} from "@bloom-v2/interfaces/IOracle.sol";

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

    address private immutable _oracle;

    /// @notice The number of decimals for the token.
    uint8 private immutable _decimals;

    struct Borrower {
        address account;
        uint256 matchedAmount;
    }

    struct TbyMaturity {
        uint128 start;
        uint128 end;
    }

    mapping(uint256 => Borrower[]) private _idToBorrowers;

    mapping(uint256 => TbyMaturity) private _idToMaturity;

    mapping(uint256 => uint256) private _totalSupply;

    uint256 private _lastMintedId;

    uint256 private _lastMaturedId;

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

    constructor(address bloomPool_, address oracle_, uint8 decimals_) {
        _bloomPool = bloomPool_;
        _oracle = oracle_;
        _decimals = decimals_;

        // Initialize the last minted and matured id's to start right before the first live id.
        uint256 startId = uint256(IOrderbook.OrderType.MATCHED);
        _lastMintedId = startId;
        _lastMaturedId = startId;
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

    function swapIn(
        address account,
        address[] memory borrowers,
        uint256[] memory amounts,
        uint256 stableAmount
    ) external onlyBloom returns (uint256 id) {
        id = _lastMintedId;
        TbyMaturity memory maturity = _idToMaturity[id];

        if (block.timestamp > maturity.start) {
            id = _lastMintedId++;
            uint128 start = uint128(block.timestamp + 48 hours);
            uint128 end = start + 180 days;
            _idToMaturity[_lastMintedId] = TbyMaturity(start, end);
        }

        Borrower[] storage borrowerList = _idToBorrowers[id];
        uint256 borrowerCount = borrowerList.length;
        for (uint256 i = 0; i < borrowerCount; ++i) {
            borrowerList.push(Borrower(borrowers[i], amounts[i]));
        }

        _burn(account, uint256(IOrderbook.OrderType.MATCHED), stableAmount);
        _mint(account, id, stableAmount, "");
        _totalSupply[id] += stableAmount;
    }

    function getRate(uint256 id) public view returns (uint256) {
        TbyMaturity memory maturity = _idToMaturity[id];
        uint256 time = block.timestamp;
        if (time <= maturity.start) {
            return 1e18;
        }
        return
            1e18 +
            IOracle(_oracle).tbyRatePerSecond(address(this)) *
            (time - maturity.start);
    }

    function shareOf(
        uint256 id,
        address account
    ) public view returns (uint256) {
        require(id >= uint256(IOrderbook.OrderType.LIVE), Errors.InvalidId());
        uint256 balance = balanceOf(account, id);
        uint256 total = _totalSupply[id];
        return (balance * 1e6) / total;
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
