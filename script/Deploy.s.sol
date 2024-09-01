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
import {BloomPool} from "../src/BloomPool.sol";

contract DeployScript is Script {
    address public owner = address(0);
    address public stable = address(0);
    address public rwa = address(0);
    address public rwaPriceFeed = address(0);
    uint256 public leverage = 0;
    uint256 public spread = 0;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);

        if (owner == address(0)) {
            owner = deployer;
        }
        require(owner != address(0), "Deployer is not set");
        require(stable != address(0), "Stable is not set");
        require(rwa != address(0), "RWA is not set");
        require(rwaPriceFeed != address(0), "RWA PriceFeed is not set");
        require(leverage != 0, "Leverage is not set");
        require(spread != 0, "Spread is not set");

        BloomPool bloomPool = new BloomPool(stable, rwa, rwaPriceFeed, leverage, spread, owner);
        console.log("BloomPool: ", address(bloomPool));

        require(bloomPool.owner() != address(0), "Deployer is not owner");
        require(bloomPool.asset() == address(stable), "Stable is not set");
        require(bloomPool.rwa() == address(rwa), "BillToken is not set");
        require(bloomPool.rwaPriceFeed() == address(rwaPriceFeed), "PriceFeed is not set");
        require(bloomPool.leverage() == leverage, "Init leverage is not set");
        require(bloomPool.spread() == spread, "Spread is not set");

        vm.stopBroadcast();
    }
}
