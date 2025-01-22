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

import {BloomErrors as Errors} from "@bloom-v2/helpers/BloomErrors.sol";
import {MockBloomPool} from "../mocks/MockBloomPool.sol";
import {BloomTestSetup} from "../BloomTestSetup.t.sol";

contract TbyUnitTest is BloomTestSetup {
    MockBloomPool tby; // Same thing as bloomPool

    function setUp() public {
        _setUp(address(0), address(0));

        // Create a new BloomPool
        tby = new MockBloomPool(
            "Test Strategy",
            "TEST",
            address(bloomRouter),
            address(billToken),
            address(priceFeed),
            6,
            50e18,
            0.9e18,
            address(1)
        );
    }

    function testDecimals() public {
        assertEq(tby.decimals(), 6);
    }

    function testName() public {
        assertEq(tby.name(), "Term Bound Yield - Test Strategy");
    }

    function testSymbol() public {
        assertEq(tby.symbol(), "TBY-TEST");
    }

    function testUri() public {
        assertEq(tby.uri(1), "https://bloom.garden/TBY-TEST/1");
    }
}
