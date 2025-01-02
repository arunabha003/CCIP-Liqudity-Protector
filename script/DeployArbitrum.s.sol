// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {LPSCRegistry} from "../src/myLPSCRegistry.sol";
import {LPSC} from "../src/LPSC.sol";
import {LPSCVault} from "../src/LPSCVault.sol";
import {Test, console} from "forge-std/Test.sol";

contract DeployArbitrumScript is Script {
    // Constants for Arbitrum
    address constant aavePoolAddress =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Aave V3 Pool on Arbitrum
    address constant routerAddressArbitrum =
        0x141fa059441E0ca23ce184B6A78bafD2A517DdE8; // Chainlink Router on Arbitrum
    address constant transfer_token_address_Arbitrum =
        0xED65C5085a18Fa160Af0313E60dcc7905E944Dc7; // ethx address on Arbitrum

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        console.log(deployerPrivateKey);
        // Deploy Registry
        LPSCRegistry registry = new LPSCRegistry();
        console.log("LPSCRegistry deployed at:", address(registry));

        // Deploy Vault
        LPSCVault vault = new LPSCVault(aavePoolAddress);
        console.log("LPSCVault deployed at:", address(vault));

        // Deploy LPSC
        LPSC lpsc = new LPSC(routerAddressArbitrum, address(vault));
        console.log("LPSC deployed at:", address(lpsc));

        vm.stopBroadcast();
    }
}
