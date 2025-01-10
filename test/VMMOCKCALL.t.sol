// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract VMMOCKCALL is Test {
    uint256 public ethereumMainnetForkId;

    address constant wethAddressETHMainnet =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        // ethereumMainnetForkId = vm.createFork(
        //     "https://eth-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"
        // );
    }

    function testMockCall() public {
        // vm.selectFork(ethereumMainnetForkId);

        address addressOfTestContract = address(this);

        vm.deal(addressOfTestContract, 2 ether);

    }

    function balanceOfThisContract() public returns (uint256) {
        // vm.selectFork(ethereumMainnetForkId);

        IERC20(wethAddressETHMainnet).balanceOf(address(this)) > 1 ether;

        return IERC20(wethAddressETHMainnet).balanceOf(address(this));
    }
}
