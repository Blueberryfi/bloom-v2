// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/BloomPool.sol"; // Adjust the path as necessary
import "../test/mocks/MockERC20.sol";
import "../test/mocks/MockPriceFeed.sol";
import "../src/token/Tby.sol";
import "../src/oracle/BloomOracle.sol";
import {ChainlinkOracle} from "../src/oracle/chainlink/ChainlinkOracle.sol";
import "../src/oracle/CrossAdapter.sol";
import "../test/mocks/MockBorrowModule.sol";

contract DeployScript is Script {
    address internal constant usd = address(0x0000000000000000000000000000000000000348);

    function run() external {
        vm.startBroadcast();
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);

        MockERC20 stable = new MockERC20("Mock USDC", "USDC", 6);
        console.log("Stable deployed at: ", address(stable));
        MockERC20 billToken = new MockERC20("Mock T-Bill Token", "bIb01", 18);
        console.log("Bill Token deployed at: ", address(billToken));

        MockPriceFeed priceFeed = new MockPriceFeed(8);
        priceFeed.setLatestRoundData(1, 100e8, 0, block.timestamp, 1);
        console.log("Bill Token Price Feed deployed at: ", address(priceFeed));

        BloomPool bloomPool = new BloomPool(address(stable), 1e6, deployer);
        console.log("Bloom Pool deployed at: ", address(bloomPool));
        vm.stopPrank();

        Tby tby = Tby(bloomPool.tby());
        console.log("Tby deployed at: ", address(tby));

        BloomOracle bloomOracle = new BloomOracle(address(deployer));
        console.log("Bloom Oracle deployed at: ", address(bloomOracle));

        MockPriceFeed usdcPriceFeed = new MockPriceFeed(8);
        usdcPriceFeed.setLatestRoundData(1, 1e8, 0, block.timestamp, 1);
        console.log("USDC Price Feed deployed at: ", address(usdcPriceFeed));

        ChainlinkOracle chainlinkOracle1 =
            new ChainlinkOracle(address(billToken), address(usd), address(priceFeed), 1 days);
        console.log("Bill Token Chainlink Oracle deployed at: ", address(chainlinkOracle1));
        ChainlinkOracle chainlinkOracle2 =
            new ChainlinkOracle(address(stable), address(usd), address(usdcPriceFeed), 1 days);
        console.log("USDC Chainlink Oracle deployed at: ", address(chainlinkOracle2));
        CrossAdapter crossAdapter = new CrossAdapter(
            address(billToken), address(usd), address(stable), address(chainlinkOracle1), address(chainlinkOracle2)
        );
        console.log("Cross Adapter deployed at: ", address(crossAdapter));
        bloomOracle.setConfig(address(billToken), address(usd), address(chainlinkOracle1));
        bloomOracle.setConfig(address(stable), address(usd), address(chainlinkOracle2));
        bloomOracle.setConfig(address(billToken), address(stable), address(crossAdapter));

        // deploy mock borrow module
        MockBorrowModule mockBorrowModule =
            new MockBorrowModule(address(bloomPool), address(bloomOracle), address(billToken), 50e18, 0.9e18, deployer);
        console.log("Mock Borrow Module deployed at: ", address(mockBorrowModule));
        bloomPool.addBorrowModule(address(mockBorrowModule));

        vm.stopBroadcast();
    }
}
