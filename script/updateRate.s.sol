// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../test/mocks/MockPriceFeed.sol";

contract UpdateScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockPriceFeed usdPriceFeed = MockPriceFeed(0x1456A0032701be0B8D5b6f6E5A4bE795d791A9B8);
        usdPriceFeed.setLatestRoundData(11, 1e8, 0, block.timestamp, 11);

        MockPriceFeed billPriceFeed = MockPriceFeed(0x0C955e46b4Db7745840bE54dA5ED8bF3E1D5C282);
        billPriceFeed.setLatestRoundData(11, 100.03e8, 0, block.timestamp, 11);
    }
}
