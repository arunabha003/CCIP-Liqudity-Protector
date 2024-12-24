// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {LPSCRegistry} from "./myLPSCRegistry.sol";
import {LPSCVault} from "./LPSCVault.sol";
import {Test, console} from "forge-std/Test.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

contract LPSC is LPSCVault, CCIPReceiver {
    address public router;
    address constant registryAddress =
        0x2e234DAe75C793f67A35089C9d99245E1C58470b;
    address constant aavePoolAddress =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD; // Aave V3 Pool on Arbitrum

    event ReplySent(
        bytes32 replyMessageId,
        uint64 sourceChainSelector,
        bytes32 messageId,
        address sender,
        address tokenToReturn,
        uint256 amount
    );

    modifier onlyRouterOrOwner() {
        require(
            msg.sender == router || msg.sender == owner(),
            "Only LPSC or Owner can call"
        );
        _;
    }

    constructor(
        address _router,
        address _vault
    ) CCIPReceiver(_router) LPSCVault(_vault) {
        router = _router;

        // bool success=LinkTokenInterface(LINK).approve(_router, 1 ether);
        // require(success, "Approval failed");
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory receivedMessage
    ) internal override {
        console.log("message recieved by lpsc");
        bytes32 messageId = receivedMessage.messageId;
        uint64 sourceChainSelector = receivedMessage.sourceChainSelector;
        (address tokenAddress, uint256 amount, address sender) = abi.decode(
            receivedMessage.data,
            (address, uint256, address)
        );
        console.log("token address", tokenAddress);
        console.log("amount", amount);
        console.log("sender", sender);
        console.log("source chain sleector:", sourceChainSelector);
        // console.log("messaageID:", messageId);

        reply(tokenAddress, amount, sourceChainSelector, sender, messageId);
    }

    function reply(
        address tokenAddress, //Address of for exp ETHX in the mainnet
        uint256 amount,
        uint64 sourceChainSelector,
        address sender,
        bytes32 messageId
    ) public onlyRouterOrOwner {
        // address tokenToReturn = s_destinationToSourceMap[
        //     keccak256(abi.encodePacked(tokenAddress, sourceChainSelector))
        // ];

        //Address of the ETHX in Arbitrum
        address tokenToReturn = LPSCRegistry(registryAddress)
            .getSourceChainToken(tokenAddress, sourceChainSelector);
        console.log("Token to return Arbitrum address:", tokenToReturn);
        uint256 currentBalance = IERC20(tokenToReturn).balanceOf(address(this));
        console.log("and its balance is:", currentBalance);
        console.log("and its amount req is:", amount);

        // If there are not enough funds in LPSC, withdraw additional from Aave vault
        if (currentBalance < amount) {
            withdrawFromVault(tokenToReturn, amount - currentBalance);
        }

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: tokenToReturn,
            amount: amount
        });
        tokenAmounts[0] = tokenAmount;

        IERC20(tokenToReturn).approve(router, amount);

        Client.EVM2AnyMessage memory messageReply = Client.EVM2AnyMessage({
            receiver: abi.encode(sender),
            data: abi.encode(messageId),
            tokenAmounts: tokenAmounts,
            extraArgs: "",
            feeToken: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 //weth arbitrum
        });
        console.log(
            "balance of feetoken:",
            IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(
                address(this)
            )
        );
        console.log("reply sending");
        // uint256 fee = IRouterClient(router).getFee(
        //     5009297550715157269,
        //     messageReply
        // );
        // console.log("fee is ", fee);
        bytes32 replyMessageId = IRouterClient(router).ccipSend( //the error is here check this
            5009297550715157269,
            messageReply
        );
        console.log("reply sent");

        emit ReplySent(
            replyMessageId,
            5009297550715157269,
            messageId,
            sender,
            tokenToReturn,
            amount
        );
    }

    function testCcipReceive(
        Client.Any2EVMMessage memory receivedMessage
    ) external {
        _ccipReceive(receivedMessage);
    }

    receive() external payable {}

    fallback() external payable {}
}
