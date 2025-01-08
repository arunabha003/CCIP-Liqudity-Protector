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
import {Test, console} from "forge-std/Test.sol";
import {ICToken} from "../src/interfaces/compound/ICtoken.sol";
import {IComptroller} from "../src/interfaces/compound/IComptroller.sol";
import {MonitorCompoundV2} from "../src/monitors/MonitorCompoundV2.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "../src/interfaces/ICurve.sol";
import "../src/interfaces/IUniswap.sol";

contract FullFlowTest is Test {
    MonitorCompoundV2 public monitor;
    LPSC public lpsc;
    LPSCVault public vault;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    LPSCRegistry public registry;
    ICurvePool public curvePoolETHXtoWETH;
    IUniswapV2Router02 public uniswap_router;
    // Fork IDs
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
        0xA35b1B31Ce002FBF2058D22F30f95D405200A15b; //ethx address on eth mainet
    address constant transfer_token_address_Arbitrum =
        0xED65C5085a18Fa160Af0313E60dcc7905E944Dc7; //ethx address on arbitrum

    address user = address(1);
    // Chain selectors
    uint64 constant ethereumChainSelector = 5009297550715157269; // ETH Mainnet chain selector
    uint64 constant arbitrumChainSelector = 4949039107694359620; // Arbitrum chain selector
    uint256 ethereumMainnetchainId = 1;
    uint256 arbitrumMainnetchainId = 42161;

    address constant COMPTROLLER_ADDRESS =
        0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B; // Compound Comptroller on Ethereum Mainnet
    address constant CETH_ADDRESS = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; // cETH on Ethereum Mainnet
    address constant WETH_GAS_TOKEN_ETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on Mainnet
    address constant ROUTER_ADDRESS =
        0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D; //ETH Mainnet Router Address
    uint64 constant CHAIN_SELECTOR_ARBITRUM = 4949039107694359620; //Chain selector Arbitrum Mainnet
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F; //DAI address Ethereum Mainnet
    address public constant CDAI_ADDRESS =
        0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; // cDai address Ethereum Mainnet
    address lpscAddress;

    function setUp() public {
        // Create forks
        arbitrumForkId = vm.createFork(
            "https://arb-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"
        );
        ethereumMainnetForkId = vm.createFork(
            "https://eth-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"
        );

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.selectFork(arbitrumForkId);
        registry = new LPSCRegistry();

        vault = new LPSCVault(aavePoolAddress);

        lpsc = new LPSC(routerAddressArbitrum, address(vault));

        vm.selectFork(ethereumMainnetForkId);
        monitor = new MonitorCompoundV2(
            routerAddressMainnet,
            user,
            0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643, //ctoken(CDAI ADDRESS)
            0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B, //comptroller FROM COMPOUND DOCS
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, //gas token
            0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, //token address of ethx
            address(lpsc),
            4949039107694359620 //source chian selecor
        );
        console.log("Monitor contract deployed at: ", address(monitor));

        curvePoolETHXtoWETH = ICurvePool(
            0xd82C2eB10F4895CABED6EDa6eeee234bd1A9838B
        );

        uniswap_router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        // Fund the user with ETH
        vm.deal(user, 10 ether);
        console.log("User funded with 10 ETH");

        // Fund the monitor with WETH (gas)
        deal(WETH_GAS_TOKEN_ETH, address(monitor), 10 ether);
        uint256 wethBalance = IERC20(WETH_GAS_TOKEN_ETH).balanceOf(
            address(monitor)
        );
        console.log("Monitor WETH balance: ", wethBalance);

        vm.selectFork(arbitrumForkId);

        // Fund the LPSC with WETH (gas)
        deal(wethAddressArbitrum, address(lpsc), 10 ether); // WETH for gas fees
        console.log(
            "WETH balance for LPSC set:",
            IERC20(wethAddressArbitrum).balanceOf(address(lpsc))
        );

        // Fund the LPSC with ETHx (Token to transfer)
        deal(transfer_token_address_Arbitrum, address(lpsc), 10 ether);
        console.log(
            "Token balance for LPSC set:",
            IERC20(transfer_token_address_Arbitrum).balanceOf(address(lpsc))
        );

        //approve the router to spend the weth
        vm.prank(address(lpsc));
        IERC20(wethAddressArbitrum).approve(
            address(routerAddressArbitrum),
            type(uint256).max
        );
    }

    function testMonitorLiquidationn() public {
        vm.selectFork(ethereumMainnetForkId);

        vm.startPrank(user);

        // Step 1: Mint cETH (Deposit ETH)
        ICToken(CETH_ADDRESS).mint{value: 8 ether}();
        console.log(
            "User minted cETH balance ",
            IERC20(CETH_ADDRESS).balanceOf(user)
        );

        // Step 2: Enter the market
        address[] memory markets;
        markets = new address[](1);
        markets[0] = CETH_ADDRESS;

        //vm.prank(user);
        uint256[] memory errors = IComptroller(COMPTROLLER_ADDRESS)
            .enterMarkets(markets);
        require(errors[0] == 0, "Enter markets failed");

        // Step 3: Calculate liquidity
        (, uint256 liquidity, ) = IComptroller(COMPTROLLER_ADDRESS)
            .getAccountLiquidity(user);
        assert(liquidity > 0);
        uint256 daiBalance0 = IERC20(DAI_ADDRESS).balanceOf(user);

        // Log borrow results
        console.log("initial DAI:", daiBalance0 / 1e18); //where is the initial DAI coming from?

        // Step 4: Borrow DAI
        uint256 daiToBorrow = 1 * 1e18; // Borrow 1 DAI
        //vm.prank(user);
        uint256 borrowError = ICToken(CDAI_ADDRESS).borrow(daiToBorrow);
        require(borrowError == 0, "Borrow failed");

        // Assert DAI balance is updated
        uint256 daiBalance = IERC20(DAI_ADDRESS).balanceOf(user);

        // Log borrow results
        console.log("DAI borrowed:", daiBalance / 1e18);
        console.log("Liquidity remaining (in USD):", liquidity / 1e18);

        // Step 3: Mock Comptroller's getAccountLiquidity (Simulate shortfall)
        vm.mockCall(
            COMPTROLLER_ADDRESS,
            abi.encodeWithSelector(
                IComptroller.getAccountLiquidity.selector,
                user
            ),
            abi.encode(0, 0, 2 ether) // Simulated shortfall of 1 ETH
        );

        // Step 4: Call checkUpkeep
        bool upkeepNeeded;
        bytes memory performData;
        (upkeepNeeded, performData) = monitor.checkUpkeep("");

        assert(upkeepNeeded);
        console.log("Upkeep needed: ", upkeepNeeded);
        // Step 5: Perform upkeep to send CCIP message
        monitor.performUpkeep(performData);
        console.log("CCIP message sent");

        //LPSC STARTS FROM HERE_______________________________
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumForkId); //whatever message for the request of funds will happen because of this when we switch to arbitrum
        vm.selectFork(ethereumMainnetForkId);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(
            ethereumMainnetForkId
        );

        //after switching to wth the funds should be transferred to mainnet and there shouldnt be any need to liquidate
        uint256 transfer_tokens_ETHX_by_Monitor = IERC20(
            transfer_token_address_Mainnet
        ).balanceOf(address(monitor));

        console.log(
            "balance of transfer token on eth mainnet:",
            transfer_tokens_ETHX_by_Monitor
        );

        vm.stopPrank();
        vm.selectFork(ethereumMainnetForkId);



        //swapping etherx-> weth then weth to cdai
        vm.startPrank(address(monitor));





        uint256 initialETHX = IERC20(transfer_token_address_Mainnet).balanceOf(
            address(this)
        );
        console.log("Initial ETHX balance: ", initialETHX);

        IERC20(transfer_token_address_Mainnet).approve(
            0xd82C2eB10F4895CABED6EDa6eeee234bd1A9838B,
            transfer_tokens_ETHX_by_Monitor
        );
        console.log("approval successful");

        console.log(
            "transfer_tokens_ETHX_by_Monitor before swap: ",
            transfer_tokens_ETHX_by_Monitor
        );

        uint256 initialweth = IERC20(wethAddressETHMainnet).balanceOf(
            address(monitor)
        );
        console.log("initail WETH by Monitor: ", initialweth);

        curvePoolETHXtoWETH.exchange(
            0,
            1,
            transfer_tokens_ETHX_by_Monitor,
            101001111111111
        );
        uint256 final_transfer_tokens_ETHX_by_Monitor = IERC20(
            transfer_token_address_Mainnet
        ).balanceOf(address(monitor));

        console.log(
            "final transfer_tokens_ETHX_by_Monitor before swap: ",
            final_transfer_tokens_ETHX_by_Monitor
        );




        // console.log("address this : ", address(this)); //FullFlowKaAddress h
        // console.log("address monitor : ", address(monitor));




        // exchange weth to dai

        uint256 finalWeth = IERC20(wethAddressETHMainnet).balanceOf(
            address(monitor)
        );
        console.log("Final WETH balance before exchange to DAI: ", finalWeth);

        //uniswap dai to weth
        // token 0 dai
        // token 1 weth
        // liquidity pool uniswapV2Pair 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11

        //Uniswap

        require(
            IERC20(uniswap_router.WETH()).approve(
                address(uniswap_router),
                finalWeth
            ),
            "approve failed."
        );


        address[] memory path = new address[](2);
        path[0] = uniswap_router.WETH();
        path[1] = DAI_ADDRESS;

        uniswap_router.swapExactTokensForTokens(
            finalWeth,
            0,
            path,
            address(monitor),
            block.timestamp + 3000000
        );
        console.log(
            "transfer complete",
            IERC20(DAI_ADDRESS).balanceOf(address(monitor))
        );
        vm.stopPrank();
        
    
        //giving liquidity back to lending protocol
        // ICToken cToken = ICToken(CDAI_ADDRESS);
        // //
        //  uint256 borrowError = ICToken(CDAI_ADDRESS).repayBorrowBehalf.value(paisa)(user);
    }
}
