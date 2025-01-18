// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IComptroller} from "../interfaces/compound/IComptroller.sol";
import {ICToken} from "../interfaces/compound/ICtoken.sol";
import {Withdraw} from "../utils/Withdraw.sol";
import {Test, console} from "forge-std/Test.sol";


contract MonitorCompoundV2 is
    AutomationCompatibleInterface,
    CCIPReceiver,
    Withdraw
{
    address immutable i_onBehalfOf;
    address immutable i_cTokenAddress;
    address immutable i_comptrollerAddress;
    address immutable i_gas_Token;
    address immutable i_tokenAddress;
    address immutable i_lpsc;
    uint64 immutable i_sourceChainSelector;
    bool private _isCcipMessageSent;
    address immutable i_router;

    mapping(bytes32 messageId => uint256 amountToRepay) internal requested;
    mapping(bytes32 messageId => bool reply1) internal reply;

    event MessageSent(bytes32 indexed messageId);

    constructor(
        address router,
        address onBehalfOf,
        address cTokenAddress,
        address comptrollerAddress,
        address weth,
        address tokenAddress,
        address lpsc,
        uint64 sourceChainSelector
    ) CCIPReceiver(router) {
        i_onBehalfOf = onBehalfOf;
        i_cTokenAddress = cTokenAddress;
        i_comptrollerAddress = comptrollerAddress;
        i_gas_Token = weth;
        i_tokenAddress = tokenAddress;
        i_lpsc = lpsc;
        i_sourceChainSelector = sourceChainSelector;
        i_router = router;

        IERC20(i_gas_Token).approve(i_router, type(uint256).max);
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external override returns (bool upkeepNeeded, bytes memory performData) {
        (uint error, uint liquidity, uint shortfall) = IComptroller(
            i_comptrollerAddress
        ).getAccountLiquidity(i_onBehalfOf);
        require(error == 0, "Comtroller Error");
        upkeepNeeded = shortfall != 0 && liquidity <= 0 && !_isCcipMessageSent;
    }

    function performUpkeep(bytes calldata performData) external override {
        require(
            !_isCcipMessageSent,
            "CCIP Message already sent, waiting for a response"
        );
        (uint error, uint liquidity, uint shortfall) = IComptroller(
            i_comptrollerAddress
        ).getAccountLiquidity(i_onBehalfOf);
        require(error == 0, "Comtroller Error");
        require(
            shortfall != 0 && liquidity <= 0,
            "Account can't be liquidated!"
        );

        uint256 amountNeeded = ICToken(i_cTokenAddress).borrowBalanceStored(
            i_onBehalfOf
        );

        // Ask for funds from LPSC on the source blockchain
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(i_lpsc),
            data: abi.encode(i_tokenAddress, amountNeeded, address(this)),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 900000})
            ),  
            feeToken: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
           
        });

        bytes32 messageId = IRouterClient(i_router).ccipSend(
            i_sourceChainSelector,
            message
        );

        requested[messageId] = amountNeeded;

        _isCcipMessageSent = true;

        emit MessageSent(messageId);
    }

    //recieves reply
    function _ccipReceive(
        Client.Any2EVMMessage memory receivedMessage
    ) internal override {
        console.log("reply recieved");
        _isCcipMessageSent = false;
        bytes32 requestMessageId = abi.decode(receivedMessage.data, (bytes32));
        uint256 amountToRepay = requested[requestMessageId];
        reply[requestMessageId] = true;
        
        

        // IERC20(i_tokenAddress).approve(i_cTokenAddress, amountToRepay);
        // ICToken(i_cTokenAddress).repayBorrowBehalf(i_onBehalfOf, amountToRepay);
    }

    // --------------GETTER FUNCTIONS-------------------

    function isCcipMessageSent() external view returns (bool) {
        return _isCcipMessageSent;
    }

    function isCcipMessagerecieved(bytes32 x) external view returns (bool) {
        return reply[x];
    }

    function testCcipReceive(
        Client.Any2EVMMessage memory receivedMessage
    ) external {
        _ccipReceive(receivedMessage);
    }

    receive() external payable {}

    fallback() external payable {}
}
