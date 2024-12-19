// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console } from "forge-std/Test.sol";
import {CompoundETHManager, ICEth, ICompoundComptroller} from "../../src/contracts/compound.sol";

contract CompoundETHManagerTest is Test {
    CompoundETHManager public compoundManager;
    address user = address(1); // Test user
    address constant cEthAddress = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; // cETH on Ethereum Mainnet
    address constant comptrollerAddress = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B; // Comptroller on Ethereum Mainnet

    function setUp() public {
        vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"); // Replace with your Infura key
        compoundManager = new CompoundETHManager(cEthAddress, comptrollerAddress);
        vm.deal(user, 10 ether); // Provide ETH to the test user
    }

    function testDepositETH() public {
        vm.startPrank(user);

        uint256 initialCEthBalance = ICEth(cEthAddress).balanceOf(user);
        uint256 depositAmount = 1 ether;

        // Deposit ETH
        compoundManager.depositETH{value: depositAmount}();

        // Verify cETH balance increased
        uint256 finalCEthBalance = ICEth(cEthAddress).balanceOf(user);
        assert(finalCEthBalance > initialCEthBalance);

        vm.stopPrank();
    }

    function testWithdrawETH() public {
        vm.startPrank(user);

        uint256 depositAmount = 1 ether;

        // Deposit ETH
        compoundManager.depositETH{value: depositAmount}();

        uint256 cEthBalance = ICEth(cEthAddress).balanceOf(user);
        assert(cEthBalance > 0);

        // Transfer cETH to contract for withdrawal
        ICEth(cEthAddress).transfer(address(compoundManager), cEthBalance);

        // Withdraw ETH
        uint256 userBalanceBefore = user.balance;
        compoundManager.withdrawETH(cEthBalance);
        uint256 userBalanceAfter = user.balance;

        assert(userBalanceAfter > userBalanceBefore);

        vm.stopPrank();
    }

    function testExchangeRate() public {
        uint256 exchangeRate = compoundManager.getExchangeRate();
        assert(exchangeRate > 0); // Validate that an exchange rate is returned
    }

    function testHealthFactor() public {
        vm.startPrank(user);

        uint256 depositAmount = 1 ether;

        // Deposit ETH
        compoundManager.depositETH{value: depositAmount}();

        // Verify health factor
        uint256 healthFactor = compoundManager.getHealthFactor(user);
        console.log("Health Factor :" ,healthFactor);
        assert(healthFactor > 0); // Validate that a health factor is returned and valid

        vm.stopPrank();
    }
}
