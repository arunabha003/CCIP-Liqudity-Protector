pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol"; //import Script from Foundry Standard Lib
import  {VMMOCKCALL} from "../test/VMMOCKCALL.t.sol"; //import contract to deploy

contract DeployTest is Script {

   function run() external returns(VMMOCKCALL) {

      vm.startBroadcast();

      VMMOCKCALL vmMockCall = new VMMOCKCALL(); 
      
      vm.stopBroadcast();

      return vmMockCall;

   }

}

//forge script script/DeployTest.s.sol --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80