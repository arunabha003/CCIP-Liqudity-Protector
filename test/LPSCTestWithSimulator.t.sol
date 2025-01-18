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

/**
 * @title LPSCTestWithSimulator
 * @notice Demonstrates the full CCIP flow between an Arbitrum fork (LPSC side) 
 *         and an Ethereum fork (MonitorCompoundV2 side), using 
 *         CCIPLocalSimulatorFork for cross-chain message simulation.
 */
contract LPSCTestWithSimulator is Test {
    // -------------------------------------------------------------------------
    // Contract Instances
    // -------------------------------------------------------------------------
    LPSC public lpscContract;
    LPSCVault public vaultContract;
    MonitorCompoundV2 public monitorContract;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    LPSCRegistry public registryContract;

    // -------------------------------------------------------------------------
    // Fork and Network Details
    // -------------------------------------------------------------------------
    uint64 public destinationChainSelector;
    uint256 public ethereumMainnetForkId;
    uint256 public arbitrumMainnetForkId;
    IRouterClient public sourceRouter;

    // -------------------------------------------------------------------------
    // Addresses for Ethereum and Arbitrum
    // -------------------------------------------------------------------------
    address public constant WETH_MAINNET =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH Mainnet
    address public constant WETH_ARBITRUM =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum
    address public constant AAVE_POOL_ARBITRUM =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Aave V3 Pool on Arbitrum
    address public constant ROUTER_MAINNET =
        0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D; // Chainlink Router on ETH Mainnet
    address public constant ROUTER_ARBITRUM =
        0x141fa059441E0ca23ce184B6A78bafD2A517DdE8; // Chainlink Router on Arbitrum

    // Example cross-chain token addresses (ETHx)
    address public constant ETHX_MAINNET =
        0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    address public constant ETHX_ARBITRUM =
        0xED65C5085a18Fa160Af0313E60dcc7905E944Dc7;

    // -------------------------------------------------------------------------
    // Test User and Chain Selectors
    // -------------------------------------------------------------------------
    address public user = address(1);
    uint64 public constant ETHEREUM_CHAIN_SELECTOR = 5009297550715157269;
    uint64 public constant ARBITRUM_CHAIN_SELECTOR = 4949039107694359620;
    uint256 public constant ETHEREUM_MAINNET_CHAIN_ID = 1;
    uint256 public constant ARBITRUM_MAINNET_CHAIN_ID = 42161;

    // -------------------------------------------------------------------------
    // Setup
    // -------------------------------------------------------------------------
    function setUp() public {
        // 1. Create forks

        string memory ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");
        string memory ETH_RPC_URL = vm.envString("ETH_RPC_URL");

        arbitrumMainnetForkId = vm.createFork(ARBITRUM_RPC_URL);
        ethereumMainnetForkId = vm.createFork(ETH_RPC_URL);

        // 2. Initialize CCIP simulator, make it persistent
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // 3. Retrieve destination network details (Ethereum)
        Register.NetworkDetails memory destinationNetworkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(ETHEREUM_MAINNET_CHAIN_ID);
        destinationChainSelector = destinationNetworkDetails.chainSelector;

        // 4. Deploy contracts on the Arbitrum fork
        vm.selectFork(arbitrumMainnetForkId);

        Register.NetworkDetails memory sourceNetworkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(ARBITRUM_MAINNET_CHAIN_ID);
        sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);

        console.log("Arbitrum fork selected, chainID:", block.chainid);

        registryContract = new LPSCRegistry();
        vaultContract = new LPSCVault(AAVE_POOL_ARBITRUM);

        // Deploy LPSC on Arbitrum
        lpscContract = new LPSC(
            ROUTER_ARBITRUM,
            address(vaultContract)
        );

        // 5. Deploy the MonitorCompoundV2 contract on the Ethereum fork
        vm.selectFork(ethereumMainnetForkId);
        monitorContract = new MonitorCompoundV2(
            ROUTER_MAINNET,
            user,
            0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643, // cDAI
            0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B, // Comptroller
            WETH_MAINNET,
            0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
            address(lpscContract),
            ARBITRUM_CHAIN_SELECTOR
        );
    }

    // -------------------------------------------------------------------------
    // Test:  Flow with CCIP Simulator
    // -------------------------------------------------------------------------
    function testFullFlowWithSimulator() public {
        // ---------------------------------------------------------------------
        // Step 1: Fund LPSC (Arbitrum) with WETH for gas fees and ETHx for bridging
        // ---------------------------------------------------------------------
        vm.selectFork(arbitrumMainnetForkId);

        uint256 initialWethFunding = 3 ether;
        uint256 initialEthxFunding = 5 ether;

        // Give LPSC some WETH (gas) and ETHx (collateral)
        deal(WETH_ARBITRUM, address(lpscContract), initialWethFunding);
        deal(ETHX_ARBITRUM, address(lpscContract), initialEthxFunding);

        // Approve the router to spend LPSC's WETH
        vm.prank(address(lpscContract));
        IERC20(WETH_ARBITRUM).approve(ROUTER_ARBITRUM, initialWethFunding);

        // ---------------------------------------------------------------------
        // Step 2: Simulate an incoming CCIP request from Ethereum side
        // ---------------------------------------------------------------------
        vm.startPrank(user);

        // Create tokens array for Any2EVMMessage
        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: ETHX_MAINNET,
            amount: 2 ether
        });

        // Construct the Any2EVMMessage
        Client.Any2EVMMessage memory receivedMessage = Client.Any2EVMMessage({
            messageId: 0x7966d990fa4ca25d0516a65ec0e70f72346cb60d83513f0418061f6e90a1d2b4,
            sourceChainSelector: ETHEREUM_CHAIN_SELECTOR,
            sender: abi.encode(address(monitorContract)),
            data: abi.encode(
                ETHX_MAINNET,
                2 ether,
                address(monitorContract)
            ),
            destTokenAmounts: destTokenAmounts
        });

        vm.stopPrank();

        uint256 balanceBefore = IERC20(ETHX_ARBITRUM).balanceOf(address(lpscContract));

        // Emulate router calling `testCcipReceive` on LPSC
        vm.prank(ROUTER_ARBITRUM);
        lpscContract.testCcipReceive(receivedMessage);

        uint256 balanceAfter = IERC20(ETHX_ARBITRUM).balanceOf(address(lpscContract));
        console.log("Balance of ETHx in LPSC before:", balanceBefore);
        console.log("Balance of ETHx in LPSC after:", balanceAfter);

        // Assert that some ETHx was spent/sent (balanceAfter < balanceBefore)
        assert(balanceAfter < balanceBefore);

        vm.stopPrank();

        // ---------------------------------------------------------------------
        // Step 3: Switch Chain to Ethereum and route the message
        // ---------------------------------------------------------------------
        ccipLocalSimulatorFork.switchChainAndRouteMessage(ethereumMainnetForkId);

        // Check if monitor (on Ethereum) received the token
        uint256 monitorBalance = IERC20(ETHX_MAINNET).balanceOf(address(monitorContract));
        console.log("Monitor contract ETHx balance on Mainnet:", monitorBalance);


    }
}
