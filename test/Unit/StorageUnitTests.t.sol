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

import {IBloomRouter} from "@bloom-v2/interfaces/IBloomRouter.sol";
import {BloomTestSetup} from "../BloomTestSetup.t.sol";

contract StorageUnitTests is BloomTestSetup {
    function setUp() public {
        _setUp(address(0), address(0));
    }

    function testAsset() public {
        assertEq(bloomRouter.asset(), address(stable));
    }

    function testAssetDecimals() public {
        assertEq(bloomRouter.assetDecimals(), stable.decimals());
    }

    function testMinOrderSize() public {
        assertEq(bloomRouter.minOrderSize(), 1e6);
    }

    function testLastMintedId() public {
        assertEq(bloomRouter.lastMintedId(), type(uint256).max);
    }
}
