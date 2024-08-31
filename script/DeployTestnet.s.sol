// SPDX-License-Identifier: MIT
/*
██████╗░██╗░░░░░░█████╗░░█████╗░███╗░░░███╗
██╔══██╗██║░░░░░██╔══██╗██╔══██╗████╗░████║
██████╦╝██║░░░░░██║░░██║██║░░██║██╔████╔██║
██╔══██╗██║░░░░░██║░░██║██║░░██║██║╚██╔╝██║
██████╦╝███████╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚══════╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
*/
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockPriceFeed} from "../test/mocks/MockPriceFeed.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {BloomPool} from "../src/BloomPool.sol";
import {BloomFactory} from "../src/BloomFactory.sol";

contract DeployScript is Script {
    address public owner = address(0);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);
        
        if (owner == address(0)) {
            owner = deployer;
        }

        MockPriceFeed priceFeed = new MockPriceFeed(18);
        priceFeed.setLatestRoundData(1, 100e18, block.timestamp, block.timestamp, 1);
        console.log("MockPriceFeed: ", address(priceFeed));

        (, int256 answer, , , ) = priceFeed.latestRoundData();
        require(answer == 100e18, "PriceFeed is not set");

        MockERC20 stable = new MockERC20("Bloom USDC", "bUSDC", 6);
        console.log("Stable: ", address(stable));
        require(address(stable) != address(0), "Stable is not set");

        MockERC20 billToken = new MockERC20("Bloom Bill", "bBill", 18);
        console.log("BillToken: ", address(billToken));
        require(address(billToken) != address(0), "BillToken is not set");

        BloomFactory bloomFactory = new BloomFactory(owner);    
        console.log("BloomFactory: ", address(bloomFactory));
        require(address(bloomFactory) != address(0), "BloomFactory is not set");

        BloomPool bloomPool = bloomFactory.createBloomPool(
            address(stable),
            address(billToken),
            address(priceFeed),
            50e18, // 50x leverage
            .995e18 // .5% spread for borrow returns
        );
        console.log("BloomPool: ", address(bloomPool));

        require(bloomPool.owner() != address(0), "Deployer is not owner");
        require(bloomPool.asset() == address(stable), "Stable is not set");
        require(bloomPool.rwa() == address(billToken), "BillToken is not set");
        require(bloomPool.rwaPriceFeed() == address(priceFeed), "PriceFeed is not set");
        require(bloomPool.leverage() == 50e18, "Init leverage is not set");
        require(bloomPool.spread() == .995e18, "Spread is not set");

        vm.stopBroadcast();
    }
}
