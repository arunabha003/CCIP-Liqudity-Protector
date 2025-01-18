// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


/**
 * A simplified registry contract tailored for Ethereum Mainnet and Arbitrum Mainnet,
 * mapping WETH addresses based on chain selectors.
 */


//transfer token is ETHx in our case
contract LPSCRegistry {
    uint64 public constant ETH_MAINNET_CHAIN_SELECTOR = 5009297550715157269;

    uint64 public constant ARBITRUM_MAINNET_CHAIN_SELECTOR = 4949039107694359620;

    address constant transfer_token_address_Mainnet=0xA35b1B31Ce002FBF2058D22F30f95D405200A15b; //Transfer token is ETHX
    address constant transfer_token_address_Arbitrum=0xED65C5085a18Fa160Af0313E60dcc7905E944Dc7;


    mapping(bytes32 tokenAndChainSelector => address token) internal s_destinationToSourceMap;


    constructor() {

         _fillMap(transfer_token_address_Mainnet, ETH_MAINNET_CHAIN_SELECTOR, transfer_token_address_Arbitrum);

    }

    function _fillMap(
        address destinationChainToken,
        uint64 destinationChainSelector,
        address sourceChainToken
    ) internal {
        s_destinationToSourceMap[
            keccak256(
                abi.encodePacked(destinationChainToken, destinationChainSelector)
            )
        ] = sourceChainToken;
    }

    
    function getSourceChainToken(
        address destinationChainToken,
        uint64 destinationChainSelector
    ) external view returns (address) {
        return s_destinationToSourceMap[
            keccak256(
                abi.encodePacked(destinationChainToken, destinationChainSelector)
            )
        ];
    }
}
