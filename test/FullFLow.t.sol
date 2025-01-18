// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {LPSC} from "../src/LPSC.sol";
import {LPSCVault} from "../src/LPSCVault.sol";
import {MonitorCompoundV2} from "../src/monitors/MonitorCompoundV2.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {LPSCRegistry} from "../src/myLPSCRegistry.sol";
import {ICToken} from "../src/interfaces/compound/ICtoken.sol";
import {IComptroller} from "../src/interfaces/compound/IComptroller.sol";

contract FullFlowTest is Test {
    // -------------------------------------------------------------------------
    // Contract Instances
    // -------------------------------------------------------------------------
    MonitorCompoundV2 public monitorContract;
    LPSC public lpscContract;
    LPSCVault public vaultContract;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    LPSCRegistry public registryContract;

    // -------------------------------------------------------------------------
    // Fork IDs
    // -------------------------------------------------------------------------
    uint256 public ethMainnetForkId;
    uint256 public arbitrumMainnetForkId;

    // -------------------------------------------------------------------------
    // Router Interface (for testing purposes if needed)
    // -------------------------------------------------------------------------
    IRouterClient public sourceRouter;

    // -------------------------------------------------------------------------
    // Address Constants (Mainnet + Arbitrum)
    // -------------------------------------------------------------------------
    address public constant WETH_ETH_MAINNET =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH Mainnet
    address public constant WETH_ARBITRUM =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum
    address public constant AAVE_V3_POOL_ARBITRUM =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Aave V3 Pool on Arbitrum
    address public constant ROUTER_ETH_MAINNET =
        0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D; // Chainlink Router on ETH Mainnet
    address public constant ROUTER_ARBITRUM =
        0x141fa059441E0ca23ce184B6A78bafD2A517DdE8; // Chainlink Router on Arbitrum
    address public constant ETHX_MAINNET =
        0xA35b1B31Ce002FBF2058D22F30f95D405200A15b; // Example ETHx on Mainnet
    address public constant ETHX_ARBITRUM =
        0xED65C5085a18Fa160Af0313E60dcc7905E944Dc7; // Example ETHx on Arbitrum

    // -------------------------------------------------------------------------
    // Chain Selectors and Chain IDs
    // -------------------------------------------------------------------------
    uint64 public constant ETHEREUM_CHAIN_SELECTOR = 5009297550715157269; 
    uint64 public constant ARBITRUM_CHAIN_SELECTOR = 4949039107694359620; 
    uint256 public constant ETHEREUM_MAINNET_CHAIN_ID = 1;
    uint256 public constant ARBITRUM_MAINNET_CHAIN_ID = 42161;

    // -------------------------------------------------------------------------
    // Compound Protocol Addresses (Ethereum Mainnet)
    // -------------------------------------------------------------------------
    address public constant COMPTROLLER_ADDRESS =
        0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B; // Compound Comptroller
    address public constant CETH_ADDRESS =
        0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; // cETH 
    address public constant WETH_GAS_TOKEN_MAINNET =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH (gas token)
    address public constant ROUTER_ADDRESS_MAINNET =
        0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D; // Chainlink Router on Mainnet
    uint64 public constant ARBITRUM_SELECTOR = 4949039107694359620; 
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI on Mainnet
    address public constant CDAI_ADDRESS =
        0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; // cDAI on Mainnet

    // -------------------------------------------------------------------------
    // Test Constants / Actors
    // -------------------------------------------------------------------------
    address public user = address(1);

    // -------------------------------------------------------------------------
    // Setup
    // -------------------------------------------------------------------------
    function setUp() public {
        // ------------------------------
        // Create Forks
        // ------------------------------

        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        string memory ETH_RPC_URL = vm.envString("ETH_RPC_URL");

        arbitrumMainnetForkId = vm.createFork(ARBITRUM_RPC_URL);
        ethMainnetForkId = vm.createFork(ETH_RPC_URL);

        // Deploy CCIP simulator on persistent storage
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // ------------------------------
        // Deploy on Arbitrum Fork
        // ------------------------------
        vm.selectFork(arbitrumMainnetForkId);

        // Deploy registry and vault
        registryContract = new LPSCRegistry();
        vaultContract = new LPSCVault(AAVE_V3_POOL_ARBITRUM);

        // Deploy LPSC on Arbitrum
        lpscContract = new LPSC(ROUTER_ARBITRUM, address(vaultContract));

        // ------------------------------
        // Deploy on Ethereum Mainnet Fork
        // ------------------------------
        vm.selectFork(ethMainnetForkId);
        monitorContract = new MonitorCompoundV2(
            ROUTER_ADDRESS_MAINNET,
            user,
            CDAI_ADDRESS,           // cToken (cDAI)
            COMPTROLLER_ADDRESS,    // Compound Comptroller
            WETH_GAS_TOKEN_MAINNET, // Gas token (WETH)
            ETHX_MAINNET,           // Example cross-chain token (ETHx)
            address(lpscContract),
            ARBITRUM_SELECTOR       // Arbitrum chain selector
        );
        console.log("Monitor contract deployed at:", address(monitorContract));

        // Fund user with ETH on Mainnet
        vm.deal(user, 10 ether);
        console.log("User funded with 10 ETH on Mainnet");

        // Fund the monitor contract with WETH for gas
        deal(WETH_GAS_TOKEN_MAINNET, address(monitorContract), 10 ether);
        uint256 monitorWethBalance =
            IERC20(WETH_GAS_TOKEN_MAINNET).balanceOf(address(monitorContract));
        console.log("Monitor WETH balance:", monitorWethBalance);

        // ------------------------------
        // Back to Arbitrum Fork for Funding LPSC
        // ------------------------------
        vm.selectFork(arbitrumMainnetForkId);

        // Fund the LPSC with WETH for gas fees
        deal(WETH_ARBITRUM, address(lpscContract), 10 ether);
        uint256 lpscWethBalance =
            IERC20(WETH_ARBITRUM).balanceOf(address(lpscContract));
        console.log("LPSC WETH balance (Arbitrum):", lpscWethBalance);

        // Fund the LPSC with ETHx (the token to be transferred cross-chain)
        deal(ETHX_ARBITRUM, address(lpscContract), 10 ether);
        uint256 lpscEthxBalance =
            IERC20(ETHX_ARBITRUM).balanceOf(address(lpscContract));
        console.log("LPSC ETHx balance (Arbitrum):", lpscEthxBalance);

        // Approve the router to spend LPSC's WETH
        vm.prank(address(lpscContract));
        IERC20(WETH_ARBITRUM).approve(
            ROUTER_ARBITRUM,
            type(uint256).max
        );
    }

    // -------------------------------------------------------------------------
    // Test: Monitor Liquidation Flow
    // -------------------------------------------------------------------------
    function testMonitorLiquidationFlow() public {
        // Switch to Ethereum Mainnet fork
        vm.selectFork(ethMainnetForkId);

        // Impersonate user
        vm.startPrank(user);

        // ---------------------------------------------------------------------
        // 1. Mint cETH (Deposit 8 ETH into Compound)
        // ---------------------------------------------------------------------
        ICToken(CETH_ADDRESS).mint{value: 8 ether}();
        uint256 cEthBalanceUser = IERC20(CETH_ADDRESS).balanceOf(user);
        console.log("User minted cETH balance:", cEthBalanceUser);

        // ---------------------------------------------------------------------
        // 2. Enter the Market in Compound
        // ---------------------------------------------------------------------
        address[] memory markets = new address[](1);
        markets[0] = CETH_ADDRESS;
        uint256[] memory errors = IComptroller(COMPTROLLER_ADDRESS).enterMarkets(markets);
        require(errors[0] == 0, "enterMarkets failed");

        // Check user’s account liquidity
        ( , uint256 initialLiquidity, ) = IComptroller(COMPTROLLER_ADDRESS)
            .getAccountLiquidity(user);
        require(initialLiquidity > 0, "User has zero initial liquidity");

        // ---------------------------------------------------------------------
        // 3. Borrow DAI
        // ---------------------------------------------------------------------
        uint256 initialDaiBalance = IERC20(DAI_ADDRESS).balanceOf(user);
        console.log("User initial DAI balance:", initialDaiBalance / 1e18);

        uint256 daiToBorrow = 1 * 1e18; // Borrow 1 DAI
        uint256 borrowError = ICToken(CDAI_ADDRESS).borrow(daiToBorrow);
        require(borrowError == 0, "DAI borrow failed");

        uint256 newDaiBalance = IERC20(DAI_ADDRESS).balanceOf(user);
        console.log("User DAI after borrow:", newDaiBalance / 1e18);

        // ---------------------------------------------------------------------
        // 4. Simulate Account Underwater (Shortfall)
        // ---------------------------------------------------------------------
        // Mock the Comptroller to force a shortfall
        vm.mockCall(
            COMPTROLLER_ADDRESS,
            abi.encodeWithSelector(
                IComptroller.getAccountLiquidity.selector,
                user
            ),
            abi.encode(0, 0, 2 ether) // Shortfall of 2 ETH, forcing liquidation scenario
        );

        // ---------------------------------------------------------------------
        // 5. Chainlink Automation: checkUpkeep + performUpkeep
        // ---------------------------------------------------------------------
        bool upkeepNeeded;
        bytes memory performData;
        (upkeepNeeded, performData) = monitorContract.checkUpkeep("");
        require(upkeepNeeded, "Upkeep not needed");
        console.log("Upkeep needed:", upkeepNeeded);

        // Perform the upkeep to send a cross-chain request
        monitorContract.performUpkeep(performData);
        console.log("CCIP message has been sent to Arbitrum");

        // ---------------------------------------------------------------------
        // 6. Simulate Cross-Chain Communication
        // ---------------------------------------------------------------------
        // Switch chain to Arbitrum to route the request
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumMainnetForkId);

        // Switch back to Ethereum to route the reply
        vm.selectFork(ethMainnetForkId);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(ethMainnetForkId);

        // ---------------------------------------------------------------------
        // 7. Verify tokens arrived on the Monitor (on Ethereum)
        // ---------------------------------------------------------------------
        uint256 monitorTokenBalance = IERC20(ETHX_MAINNET).balanceOf(
            address(monitorContract)
        );
        console.log("Monitor contract ETHx balance on Mainnet:", monitorTokenBalance);

        vm.stopPrank();
    }
}
