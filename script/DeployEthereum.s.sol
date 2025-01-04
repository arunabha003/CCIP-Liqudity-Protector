// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test, console} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {MonitorCompoundV2} from "../src/monitors/MonitorCompoundV2.sol";
import {Ultimate} from "test/ULTIMATE.t.sol";

contract DeployEthereumScript is Script {
    // Constants for Ethereum Mainnet
    address constant routerAddressMainnet =
        0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D; // Chainlink Router on ETH Mainnet
    address constant transfer_token_address_Mainnet =
        0xA35b1B31Ce002FBF2058D22F30f95D405200A15b; // ethx address on ETH Mainnet
    address constant COMPTROLLER_ADDRESS =
        0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B; // Compound Comptroller
    address constant CETH_ADDRESS = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; // cETH
    address constant WETH_GAS_TOKEN_ETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on Mainnet
    address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
    address constant CDAI_ADDRESS = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; // cDAI

    uint64 constant arbitrumChainSelector = 4949039107694359620; // Arbitrum chain selector
    address constant LPSCArbitrum = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0; // Deployed Registry address on Arbitrum (replace with actual address)

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        Ultimate ultimate = new Ultimate(
            CETH_ADDRESS,
            CDAI_ADDRESS,
            COMPTROLLER_ADDRESS
        );
        console.log("Ultimate deployed at:", address(ultimate));
        // Deploy MonitorCompoundV2
        MonitorCompoundV2 monitor = new MonitorCompoundV2(
            routerAddressMainnet,
            address(ultimate), // Mock user address for testing
            CDAI_ADDRESS,
            COMPTROLLER_ADDRESS,
            WETH_GAS_TOKEN_ETH,
            transfer_token_address_Mainnet,
            LPSCArbitrum,
            arbitrumChainSelector
        );
        console.log("MonitorCompoundV2 deployed at:", address(monitor));

        vm.stopBroadcast();
    }
}
