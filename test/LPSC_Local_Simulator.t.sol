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

contract LPSCTestWithSimulator is Test {
    // Contracts and components
    LPSC public lpsc;
    LPSCVault public vault;
    MonitorCompoundV2 public monitor;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    LPSCRegistry public registry;
    // Fork IDs
    uint64 public destinationChainSelector;
    uint256 public ethereumMainnetForkId;
    uint256 public arbitrumForkId;
    IRouterClient public sourceRouter;

    // Addresses for Ethereum and Arbitrum
    address constant wethAddressETHMainnet =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH Mainnet
    address constant wethAddressArbitrum =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum
    address constant aavePoolAddress =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Aave V3 Pool on Arbitrum
    address constant routerAddressMainnet =
        0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D; // Chainlink Router on ETH Mainnet
    address constant routerAddressArbitrum =
        0x141fa059441E0ca23ce184B6A78bafD2A517DdE8; // Chainlink Router on Arbitrum
    address constant transfer_token_address_Mainnet =
        0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    address constant transfer_token_address_Arbitrum =
        0xED65C5085a18Fa160Af0313E60dcc7905E944Dc7;

    address user = address(1);
    // Chain selectors
    uint64 constant ethereumChainSelector = 5009297550715157269; // ETH Mainnet chain selector
    uint64 constant arbitrumChainSelector = 4949039107694359620; // Arbitrum chain selector
    uint256 ethereumMainnetchainId = 1;
    uint256 arbitrumMainnetchainId = 42161;

    function setUp() public {
        // Create forks
        ethereumMainnetForkId = vm.createFork(
            "https://eth-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"
        );
        arbitrumForkId = vm.createFork(
            "https://arb-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"
        );

        // Initialize the CCIP simulator
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        Register.NetworkDetails
            memory destinationNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(ethereumMainnetchainId);

        destinationChainSelector = destinationNetworkDetails.chainSelector;

        vm.selectFork(arbitrumForkId);
        Register.NetworkDetails
            memory sourceNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(arbitrumMainnetchainId);
        sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);
        console.log("Chain ID for Arbitrum", block.chainid);
        registry = new LPSCRegistry();

        vault = new LPSCVault(aavePoolAddress);

        lpsc = new LPSC(routerAddressArbitrum, address(vault));

        // Deploy the MonitorCompoundV2 contract
        vm.selectFork(ethereumMainnetForkId);
        monitor = new MonitorCompoundV2(
            0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D,
            user,
            0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643, //c tokens ??
            0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B, //comptroller ??
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            0x6B175474E89094C44Da98b954EedeAC495271d0F, //token address ??
            address(lpsc),
            4949039107694359620 //source chian slecor
        );
    }

    function testFullFlowWithSimulator() public {
        // Step 1: Fund LPSC contract on Arbitrum with WETH
        vm.selectFork(arbitrumForkId);

        uint256 lpscBalance = 3 ether; // Sufficient funds
        deal(wethAddressArbitrum, address(lpsc), lpscBalance); //weth(gas fees)
        deal(transfer_token_address_Arbitrum, address(lpsc), 5 ether); //ethx(to cover collateralization)

        vm.prank(address(lpsc));
        IERC20(wethAddressArbitrum).approve(
            address(routerAddressArbitrum),
            3 ether
        );

        vm.startPrank(user);
        Client.EVMTokenAmount[] memory destTokenAmounts;
        destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: transfer_token_address_Mainnet,
            amount: 2 ether
        });

        // Create the Any2EVMMessage struct
        Client.Any2EVMMessage memory receivedMessage = Client.Any2EVMMessage({
            messageId: bytes32(keccak256("mockMessageId")),
            sourceChainSelector: 5009297550715157269, //ETH Mainnet chain selector
            sender: abi.encode(address(monitor)),
            data: abi.encode(
                transfer_token_address_Mainnet,
                2 ether,
                address(monitor)
            ),
            destTokenAmounts: destTokenAmounts
        });

        vm.stopPrank();

        uint256 balanceBefore = IERC20(transfer_token_address_Arbitrum)
            .balanceOf(address(lpsc));

        vm.prank(routerAddressArbitrum);
        lpsc.testCcipReceive(receivedMessage);

        uint256 balanceAfter = IERC20(transfer_token_address_Arbitrum)
            .balanceOf(address(lpsc));

        assert(balanceAfter < balanceBefore);
        vm.stopPrank();

        ccipLocalSimulatorFork.switchChainAndRouteMessage(
            ethereumMainnetForkId
        );
        uint256 monitorBalance = IERC20(transfer_token_address_Mainnet)
            .balanceOf(address(monitor));

        console.log(
            "balance of transfer token on eth mainnet:",
            monitorBalance
        );
    }
}
