// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ICToken} from "../src/interfaces/compound/ICtoken.sol";
import {IComptroller} from "../src/interfaces/compound/IComptroller.sol";
import {MonitorCompoundV2} from "../src/monitors/MonitorCompoundV2.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

/**
 * @title MonitorTest
 * @notice This test suite verifies the liquidation protection flow on Compound V2,
 *         using MonitorCompoundV2 to detect a shortfall and request funds via CCIP.
 */
contract MonitorTest is Test {
    // -------------------------------------------------------------------------
    // Contract Under Test
    // -------------------------------------------------------------------------
    MonitorCompoundV2 public monitorContract;

    // -------------------------------------------------------------------------
    // External Contract Addresses (Mainnet)
    // -------------------------------------------------------------------------
    address public constant COMPTROLLER_ADDRESS =
        0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B; // Compound Comptroller
    address public constant CETH_ADDRESS =
        0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; // cETH
    address public constant WETH_GAS_TOKEN =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address public constant ROUTER_ADDRESS =
        0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D; // Chainlink Router on Mainnet
    uint64 public constant CHAIN_SELECTOR_ARBITRUM = 4949039107694359620;
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
    address public constant CDAI_ADDRESS =
        0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; // cDAI

    // -------------------------------------------------------------------------
    // Test User and LPSC Address
    // -------------------------------------------------------------------------
    address public user = address(1);
    address public constant LPSC_ADDRESS =
        0x2e234DAe75C793f67A35089C9d99245E1C58470b;

    // -------------------------------------------------------------------------
    // Setup
    // -------------------------------------------------------------------------
    function setUp() public {
        // Fork Ethereum Mainnet
        string memory ETH_RPC_URL = vm.envString("ETH_RPC_URL");

        vm.createSelectFork(ETH_RPC_URL);

        // Deploy the MonitorCompoundV2 contract
        monitorContract = new MonitorCompoundV2(
            ROUTER_ADDRESS,
            user,
            CDAI_ADDRESS,
            COMPTROLLER_ADDRESS,
            WETH_GAS_TOKEN,
            DAI_ADDRESS,
            LPSC_ADDRESS,
            CHAIN_SELECTOR_ARBITRUM
        );
        console.log("Monitor contract deployed at:", address(monitorContract));

        // Fund the user with ETH
        vm.deal(user, 10 ether);
        console.log("User funded with 10 ETH on Mainnet fork");

        // Fund the monitor with some WETH (simulating gas/fee funding)
        deal(WETH_GAS_TOKEN, address(monitorContract), 1 ether);
        uint256 monitorWethBalance = IERC20(WETH_GAS_TOKEN).balanceOf(
            address(monitorContract)
        );
        console.log("Monitor WETH balance:", monitorWethBalance);
    }

    // -------------------------------------------------------------------------
    // Test: Detect a shortfall scenario and send CCIP request
    // -------------------------------------------------------------------------
    function testMonitorLiquidationFlow() public {
        // Impersonate user
        vm.startPrank(user);

        // 1. Deposit 8 ETH to mint cETH
        ICToken(CETH_ADDRESS).mint{value: 8 ether}();
        uint256 cEthBalance = IERC20(CETH_ADDRESS).balanceOf(user);
        console.log("User's cETH balance after mint:", cEthBalance);

        // 2. Enter the cETH market
        address[] memory markets = new address[](1);
        markets[0] = CETH_ADDRESS;
        uint256[] memory errors = IComptroller(COMPTROLLER_ADDRESS)
            .enterMarkets(markets);
        require(errors[0] == 0, "EnterMarkets failed");

        // 3. Check user's liquidity
        ( , uint256 liquidity, ) = IComptroller(COMPTROLLER_ADDRESS)
            .getAccountLiquidity(user);
        assert(liquidity > 0);

        // 4. Borrow 50 DAI (no shortfall yet)
        uint256 borrowAmountDai = 50 * 1e18;
        uint256 borrowError = ICToken(CDAI_ADDRESS).borrow(borrowAmountDai);
        require(borrowError == 0, "Borrow DAI failed");
        uint256 daiBalance = IERC20(DAI_ADDRESS).balanceOf(user);
        console.log("DAI borrowed:", daiBalance / 1e18);
        console.log("Liquidity (USD) before shortfall simulation:", liquidity / 1e18);

        // 5. Mock a shortfall scenario
        vm.mockCall(
            COMPTROLLER_ADDRESS,
            abi.encodeWithSelector(
                IComptroller.getAccountLiquidity.selector,
                user
            ),
            abi.encode(0, 0, 100 ether) // Shortfall of 100 ETH
        );

        // 6. Check Chainlink Automation
        (bool upkeepNeeded, bytes memory performData) = monitorContract.checkUpkeep("");
        console.log("PerformData returned:", string(performData));

        // Ensure upkeep is needed due to shortfall
        assert(upkeepNeeded);
        console.log("Upkeep needed:", upkeepNeeded);

        // 7. Perform upkeep, triggering cross-chain request
        monitorContract.performUpkeep(performData);
        console.log("CCIP message sent to the LPSC contract");

        // Verify internal state
        assertTrue(monitorContract.isCcipMessageSent());
        console.log("CCIP 'message sent' flag set to true");

        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Test: No shortfall => No upkeep needed
    // -------------------------------------------------------------------------
    function testNoUpkeepNeeded() public {
        // Impersonate user
        vm.startPrank(user);

        // 1. Deposit 5 ETH to mint cETH
        ICToken(CETH_ADDRESS).mint{value: 5 ether}();
        console.log("User minted cETH successfully");

        // 2. Without forcing shortfall, checkUpkeep should return false
        (bool upkeepNeeded, ) = monitorContract.checkUpkeep("");
        assert(!upkeepNeeded);
        console.log("Upkeep not needed (no shortfall):", upkeepNeeded);

        vm.stopPrank();
    }
}
