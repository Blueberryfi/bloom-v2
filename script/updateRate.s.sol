// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../test/mocks/MockPriceFeed.sol";

contract UpdateScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockPriceFeed billPriceFeed = MockPriceFeed(0x7d9df786dA5D6888685924F20399B09E4c7731Ed);
        billPriceFeed.setLatestRoundData(11, 100.03e8, 0, block.timestamp, 11);
    }
}
