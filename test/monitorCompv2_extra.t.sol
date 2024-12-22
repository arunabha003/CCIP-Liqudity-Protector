// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ICToken} from "../src/interfaces/compound/ICtoken.sol";
import {IComptroller} from "../src/interfaces/compound/IComptroller.sol";
import {MonitorCompoundV2} from "../src/monitors/MonitorCompoundV2.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract MonitorTest is Test {
    MonitorCompoundV2 public monitor;

    address constant COMPTROLLER_ADDRESS =
        0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B; // Compound Comptroller on Ethereum Mainnet
    address constant CETH_ADDRESS = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; // cETH on Ethereum Mainnet
    address constant WETH_GAS_TOKEN =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on Mainnet
    address constant ROUTER_ADDRESS =
        0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D; //ETH Mainnet Router Address
    uint64 constant CHAIN_SELECTOR_ARBITRUM = 4949039107694359620; //Chain selector Arbitrum Mainnet
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F; //DAI address Ethereum Mainnet
    address public constant CDAI_ADDRESS =
        0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; // cDai address Ethereum Mainnet
    address user = address(1);
    address lpscAddress = 0x2e234DAe75C793f67A35089C9d99245E1C58470b;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork(
            "https://eth-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"
        );

        // Deploy the Monitor contract
        monitor = new MonitorCompoundV2(
            ROUTER_ADDRESS,
            user,
            CDAI_ADDRESS,
            COMPTROLLER_ADDRESS,
            WETH_GAS_TOKEN,
            DAI_ADDRESS,
            lpscAddress,
            CHAIN_SELECTOR_ARBITRUM
        );
        console.log("Monitor contract deployed at: ", address(monitor));

        // Fund the user with ETH
        vm.deal(user, 10 ether);
        console.log("User funded with 10 ETH");

        // Fund the monitor with WETH (to simulate fee funding)
        deal(WETH_GAS_TOKEN, address(monitor), 1 ether);
        uint256 wethBalance = IERC20(WETH_GAS_TOKEN).balanceOf(
            address(monitor)
        );
        console.log("Monitor WETH balance: ", wethBalance);
    }

    function testMonitorLiquidationn() public {
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

        // Step 4: Borrow DAI
        uint256 daiToBorrow = 50 * 1e18; // Borrow 50 DAI
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
            abi.encode(0, 0, 100 ether) // Simulated shortfall of 100 ETH
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

        // Verify internal state
        assertTrue(monitor.isCcipMessageSent());
        console.log("CCIP message flag set");

        vm.stopPrank();
    }

    function testNoUpkeepNeeded() public {
        vm.startPrank(user);

        // Step 1: Mint cETH
        ICToken(CETH_ADDRESS).mint{value: 5 ether}();
        console.log("User minted cETH");

        // Step 2: Call checkUpkeep (No shortfall)
        bool upkeepNeeded;
        bytes memory performData;
        (upkeepNeeded, performData) = monitor.checkUpkeep("");
        assert(!upkeepNeeded);
        console.log("Upkeep not needed: ", upkeepNeeded);

        vm.stopPrank();
    }
}
