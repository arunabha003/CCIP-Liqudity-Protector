// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test,console} from "forge-std/Test.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import {LPSCVault} from "../../src/LPSCVault.sol";
import {IPoolAaveV3} from "../../src/interfaces/aave-v3/IPoolAaveV3.sol";

contract LPSCVaultTest is Test {
    LPSCVault public vault;
    address constant aavePoolAddress = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Aave V3 Pool on Arbitrum
    address constant wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum
    address constant aWethAddress = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8; // aWETH on Arbitrum

    address user = address(1);

    function setUp() public {
        vm.createSelectFork("https://arb-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"); // Replace with your Infura key

        // Set up the vault with the Aave Pool address
        vault = new LPSCVault(aavePoolAddress);

        // Deal some ETH to the user
        uint256 initialBalance = 10 ether;
        vm.deal(user, initialBalance);

        // Wrap ETH into WETH
        vm.startPrank(user);
        IWETH(wethAddress).deposit{value: initialBalance}();
        uint256 wethBalance = IERC20(wethAddress).balanceOf(user);
        console.log(wethBalance, "is the balance in weth");
        //assertEq(wethBalance, initialBalance, "WETH balance mismatch after deposit");

        // Approve and deposit WETH into Aave
        IERC20(wethAddress).approve(aavePoolAddress, wethBalance);
        IPoolAaveV3(aavePoolAddress).supply(wethAddress, wethBalance, user, 0);
        vm.stopPrank();

        // Verify aWETH balance
        uint256 aWethBalance = IERC20(aWethAddress).balanceOf(user);
        console.log("aweth balance :",aWethBalance);
        
        //assertEq(aWethBalance, initialBalance, "aWETH balance mismatch after supply");
    }

    function testWithdrawETHFromVault() public {
        uint256 withdrawAmount = 5 ether; // Withdraw 5 ETH worth of aWETH
        
        // Transfer aWETH from user to vault contract
        vm.startPrank(user);
        uint256 aWethBalance = IERC20(aWethAddress).balanceOf(user);
        console.log("User aWETH balance before transfer:", aWethBalance);
        assert(aWethBalance >= withdrawAmount);
    
        bool transferSuccess = IERC20(aWethAddress).transfer(address(vault), withdrawAmount);
        require(transferSuccess, "aWETH transfer to vault failed");
        console.log("Transferred aWETH to vault:", withdrawAmount);
        vm.stopPrank();
    
        // Verify vault's aWETH balance
        uint256 vaultAweBalance = IERC20(aWethAddress).balanceOf(address(vault));
        console.log("Vault's aWETH balance after transfer:", vaultAweBalance);
        assertEq(vaultAweBalance, withdrawAmount, "Vault's aWETH balance mismatch");
    
        vm.prank(user);
        // Simulate withdrawing WETH from the vault
        vault.withdrawFromVaultExternal(wethAddress, withdrawAmount);
    
        // Verify that WETH was received by the vault contract
        uint256 wethBalance = IERC20(wethAddress).balanceOf(address(vault));
        console.log("Vault's WETH balance after withdrawal:", wethBalance);
        assertEq(wethBalance, withdrawAmount, "WETH balance mismatch in vault after withdrawal");
    
        // Transfer WETH back to user
        vm.prank(address(vault)); // Set the vault as the sender for the transfer
        bool returnSuccess = IERC20(wethAddress).transfer(user, wethBalance);
        require(returnSuccess, "WETH transfer back to user failed");
    
        vm.startPrank(user); // Set user as the sender for the next step
        IWETH(wethAddress).withdraw(wethBalance); // Convert WETH to ETH
    
        // Verify that ETH was received by the user
        uint256 userEthBalance = user.balance;
        console.log("User's ETH balance after withdrawal:", userEthBalance);
        assertEq(userEthBalance, withdrawAmount, "ETH balance mismatch after withdrawal");
        vm.stopPrank();
    }
    
    
    
}

// WETH Interface
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
