// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/interfaces/IUniswap.sol";
import "../src/interfaces/ICurve.sol";

contract SwapTest is Test {
    IUniswapV2Router02 public router;
    IERC20 public ethx;
    IERC20 public dai;
    IERC20 public WETH;
    address public user = address(1);
    uint256 public ethereumMainnetForkId;
    ICurvePool public curvePool;

    function setUp() public {
        // Fork mainnet
        ethereumMainnetForkId = vm.createFork(
            "https://eth-mainnet.g.alchemy.com/v2/KywLaq2zlVzePOhip0BY3U8ztfHkYDmo"
        );
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        ethx = IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b);
        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        curvePool = ICurvePool(0xd82C2eB10F4895CABED6EDa6eeee234bd1A9838B);
    }

    function testSwapETHXtoDAI() public {
        vm.selectFork(ethereumMainnetForkId);
        uint256 swapAmount = 1e18; // 1 ETHX

        deal(address(ethx), user, 2 * 1e18);
        deal(address(WETH), user, 0);

        address ofThis = address(this);

        vm.prank(user);

        ethx.transfer(ofThis, 2 * 1e18);
        vm.stopPrank();
        console.log("address", msg.sender);
        console.log("transfer successful");
        // Get initial balances
        uint256 initialETHX = ethx.balanceOf(address(this));
        console.log("Initial ETHX balance: ", initialETHX);
        uint256 initialWETH = WETH.balanceOf(address(this));
        console.log("Initial WETH balance: ", initialWETH);

        // Approve router
        ethx.approve(0xd82C2eB10F4895CABED6EDa6eeee234bd1A9838B, swapAmount);
        console.log("approval successful");

        // Prepare swap parameters
        // address[] memory path;

        // path = new address[](3);

        // path[0] = address(ethx);

        // path[1] = address(WETH);

        // path[2] = address(dai);

        // console.log("problem caused", 0);

        // Execute swap
        // router.swapExactTokensForTokens(
        //     swapAmount,
        //     0, // Accept any amount of DAI
        //     path,
        //     address(this),
        //     block.timestamp
        // );
        // 0xd82C2eB10F4895CABED6EDa6eeee234bd1A9838B address of curve pool to swap
        // token.approve(address(pool), amountIn);

        console.log(curvePool.coins(0)); //ETHX
        console.log("next coin");
        console.log(curvePool.coins(1)); //ETH

        curvePool.exchange(0, 1, 1e18, 0);

        //Uniswap
        // require(dai.approve(address(router), swapAmount), 'approve failed.');
        // address[] memory path = new address[](2);
        // path[0] = address(dai);
        // path[1] = router.WETH();
        // console.log(block.timestamp);
        // console.log(path[1]);
        // router.swapExactTokensForETH(
        //     swapAmount,
        //     0,
        //     path,
        //     address(user),
        //     block.timestamp +3000000
        // );

        // console.log("problem not", 1);

        // // Verify balances changes
        // assertLt(
        //     ethx.balanceOf(user),
        //     initialETHX,
        //     "ETHX balance should decrease"
        // );
        // assertGt(
        //     dai.balanceOf(user),
        //     initialDAI,
        //     "DAI balance should increase"
        // );

        // uint256 finalETHX = ethx.balanceOf(address(this));
        // console.log("Final ETHX balance: ", finalETHX);
        uint256 finalWeth = WETH.balanceOf(address(this));
        console.log("Final WETH balance: ", finalWeth);
    }
}
