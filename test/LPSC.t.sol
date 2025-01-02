// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import {Test, console} from "forge-std/Test.sol";
// import {LPSC} from "../src/LPSC.sol";
// import {LPSCVault} from "../src/LPSCVault.sol";
// import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
// import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
// import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
// import {LPSCRegistry} from "../src/myLPSCRegistry.sol";
// import {IPoolAaveV3} from "../src/interfaces/aave-v3/IPoolAaveV3.sol";
// import {MonitorCompoundV2} from "../src/monitors/MonitorCompoundV2.sol";

// contract LPSCTest is Test {
//     LPSC public lpsc;
//     LPSCVault public vault;
//     LPSCRegistry public registry;
//     MonitorCompoundV2 public monitor;

//     event ReplySent(
//         bytes32 replyMessageId,
//         uint64 sourceChainSelector,
//         bytes32 messageId,
//         address sender,
//         address tokenToReturn,
//         uint256 amount
//     );

//     address constant aavePoolAddress =
//         0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Aave V3 Pool on Arbitrum
//     address constant wethAddressETHMainnet =
//         0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETHMainnet
//     address constant wethAddressArbitrum =
//         0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; //wethAddress Arbitrum
//     address constant aWethAddress = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8; // aWETH on Arbitrum
//     address constant routerAddress = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8; // Chainlink Router on Arbitrum
//     address user = address(1);

//     function setUp() public {
//         // Fork the Arbitrum mainnet
//         vm.createSelectFork(
//             "https://arb-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"
//         );

//         //Deploy Registry
//         registry = new LPSCRegistry();
//         console.log("registery deployed at:", address(registry));

//         // Deploy the Vault contract
//         vault = new LPSCVault(aavePoolAddress);
//         console.log("Vault deployed at:", address(vault));

//         // Deploy the LPSC contract
//         lpsc = new LPSC(routerAddress, address(vault));
//         console.log("LPSC deployed at:", address(lpsc));

//         vm.createSelectFork(
//             "https://eth-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"
//         );
//         //Deploy Monitor contract
//         monitor = new MonitorCompoundV2(
//             0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D,
//             user,
//             0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643,
//             0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B,
//             0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
//             0x6B175474E89094C44Da98b954EedeAC495271d0F,
//             address(lpsc),
//             4949039107694359620
//         );

//         console.log("LPSC deployed at:", address(monitor));
//     }

//     function testReplyWithoutVaultInteraction() public {
//         vm.selectFork(0);
//         address token = wethAddressETHMainnet; // Token to transfer
//         uint256 mockAmount = 2 ether; // Amount to transfer
//         uint64 mockSourceChainSelector = 5009297550715157269; //  chain selector ETH Mainnet
//         address mockSender = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f; // sender (Monitor Contract on ETH Mainnet)
//         bytes32 mockMessageId = 0x0ea9ee5b82e1a3a84b2dc565a48196d89cda6321b94ab191b530cf9d6beb297e; //  message ID

//         // Fund and approve the LPSC contract
//         uint256 lpscBalance = 3 ether; // Sufficient funds
//         deal(wethAddressArbitrum, address(lpsc), lpscBalance);
//         // deal(wethAddressArbitrum, user, 10 ether);

//         uint256 balanceBefore = IERC20(wethAddressArbitrum).balanceOf(
//             address(lpsc)
//         );

//         vm.prank(routerAddress);
//         lpsc.reply(
//             token,
//             mockAmount,
//             mockSourceChainSelector,
//             mockSender,
//             mockMessageId
//         );

//         uint256 balanceAfter = IERC20(wethAddressArbitrum).balanceOf(
//             address(lpsc)
//         );

//         assert(balanceBefore > balanceAfter);
//         console.log(
//             "Initial Balance :",
//             balanceBefore,
//             "Final Balance: ",
//             balanceAfter
//         );
//     }

//     function testWithCcipReceiveFunc() public {
//         vm.selectFork(0);
//         vm.startPrank(user);
//         uint256 lpscBalance = 3 ether; // Sufficient funds
//         deal(wethAddressArbitrum, address(lpsc), lpscBalance);

//         Client.EVMTokenAmount[] memory destTokenAmounts;
//         destTokenAmounts = new Client.EVMTokenAmount[](1);
//         destTokenAmounts[0] = Client.EVMTokenAmount({
//             token: wethAddressETHMainnet,
//             amount: 2 ether
//         });

//         // Create the Any2EVMMessage struct
//         Client.Any2EVMMessage memory receivedMessage = Client.Any2EVMMessage({
//             messageId: bytes32(keccak256("mockMessageId")),
//             sourceChainSelector: 5009297550715157269,
//             sender: abi.encode(address(monitor)),
//             data: abi.encode(wethAddressETHMainnet, 2 ether, address(monitor)),
//             destTokenAmounts: destTokenAmounts
//         });

//         vm.stopPrank();

//         uint256 balanceBefore = IERC20(wethAddressArbitrum).balanceOf(
//             address(lpsc)
//         );

//         vm.prank(routerAddress);
//         lpsc.testCcipReceive(receivedMessage);

//         uint256 balanceAfter = IERC20(wethAddressArbitrum).balanceOf(
//             address(lpsc)
//         );
//         assert(balanceAfter < balanceBefore);
//         console.log(balanceBefore, balanceAfter);

//         // // Step 3: Verify token transfer
//         vm.selectFork(1);
//         uint256 MoniterReceivedBalance = IERC20(wethAddressETHMainnet)
//             .balanceOf(address(user));
//         console.log("MoniterReceivedBalance :", MoniterReceivedBalance);
//     }
// }
