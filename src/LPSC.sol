// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {LPSCRegistry} from "./myLPSCRegistry.sol";
import {LPSCVault} from "./LPSCVault.sol";



contract LPSC is LPSCVault, CCIPReceiver {
    address public router;
    address constant registryAddress =0x2e234DAe75C793f67A35089C9d99245E1C58470b;

    IRouterClient sourceRouter;

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


    }

    function _ccipReceive(
        Client.Any2EVMMessage memory receivedMessage
    ) internal override {
        bytes32 messageId = receivedMessage.messageId;
        uint64 sourceChainSelector = receivedMessage.sourceChainSelector;
        (address tokenAddress, uint256 amount, address sender) = abi.decode(
            receivedMessage.data,
            (address, uint256, address)
        );


        reply(tokenAddress, amount, sourceChainSelector, sender, messageId);
    }

    function reply(
        address tokenAddress, //Address of for exp ETHX in the mainnet
        uint256 amount,
        uint64 sourceChainSelector,
        address sender,
        bytes32 messageId
    ) public onlyRouterOrOwner {


        //Address of the ETHX in Arbitrum
        address tokenToReturn = LPSCRegistry(registryAddress)
            .getSourceChainToken(tokenAddress, sourceChainSelector);
        uint256 currentBalance = IERC20(tokenToReturn).balanceOf(address(this));


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
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 900000})
            ),
            feeToken: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 //weth arbitrum
        });


        bytes32 replyMessageId = IRouterClient(router).ccipSend( //the error is here check this
            5009297550715157269,
            messageReply
        );

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
