// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { BloomRouter } from "@bloom-v2/BloomRouter.sol";
import { BloomPool } from "@bloom-v2/pools/BloomPool.sol";
import { MockBloomPool } from "../test/mocks/MockBloomPool.sol";
import { MockPriceFeed } from "../test/mocks/MockPriceFeed.sol";

contract DeployScript is Script {

    address constant BASE_USDC = 0x0000000000000000000000000000000000000000;
    address constant BASE_RWA = 0x0000000000000000000000000000000000000000;

    address constant BASE_SEPOLIA_MOCK_STABLE = 0x8D925bEF13303319CFf25cEb50ACc6Af0F0b9A42;
    address constant BASE_SEPOLIA_MOCK_RWA = 0x4a0D70C9daf00060fc0f84955ee14302F7A047dc;

    string constant BASE_TBY_NAME = "";
    string constant BASE_TBY_SUFFIX = "";

    string constant BASE_SEPOLIA_TBY_NAME = "Mock Treasury Bill";
    string constant BASE_SEPOLIA_TBY_SUFFIX = "MTB";


    uint256 constant INIT_LEVERAGE = 50e18;
    uint256 constant INIT_SPREAD = 0.995e18;

    bool constant IS_TESTNET = true;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);

        MockPriceFeed mockPriceFeed = new MockPriceFeed(8);
        mockPriceFeed.setLatestRoundData(1, 100e8, 0, block.timestamp, 1);

        console.log("MockPriceFeed deployed at", address(mockPriceFeed));

        BloomRouter bloomRouter = new BloomRouter(
            IS_TESTNET ? BASE_SEPOLIA_MOCK_STABLE : BASE_USDC,
            1e6,
            deployer
        );
        console.log("BloomRouter deployed at", address(bloomRouter));

        MockBloomPool bloomPool = new MockBloomPool(
            BASE_SEPOLIA_TBY_NAME,
            BASE_SEPOLIA_TBY_SUFFIX,
            address(bloomRouter),
            BASE_SEPOLIA_MOCK_RWA,
            address(mockPriceFeed),
            uint8(6),
            INIT_LEVERAGE,
            INIT_SPREAD,
            deployer
        );
        console.log("MockBloomPool deployed at", address(bloomPool));

        bloomRouter.addPool(address(bloomPool));

        bloomPool.whitelistBorrower(deployer, true);
        bloomPool.whitelistBorrower(0xf5a2CC461040311b2895394F742559c173768708, true);
    }
}
