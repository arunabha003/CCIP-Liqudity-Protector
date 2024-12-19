// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


/**
 * A simplified registry contract tailored for Ethereum Mainnet and Arbitrum Mainnet,
 * mapping WETH addresses based on chain selectors.
 */
contract LPSCRegistry {
    uint64 public constant ETH_MAINNET_CHAIN_SELECTOR = 5009297550715157269;
    //address public constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint64 public constant ARBITRUM_MAINNET_CHAIN_SELECTOR = 4949039107694359620;
    //address public constant WETH_ARBITRUM = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address constant transfer_token_address_Mainnet=0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
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
