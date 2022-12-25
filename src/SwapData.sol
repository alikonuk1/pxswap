// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

contract SwapData {
    struct Buy {
        address buyer;
        address nft;
        uint256 amount;
        bool active;
    }
    
    struct Sell {
        address seller;
        address nft;
        uint256 tokenId;
        uint256 amount;
        bool active;
    }
}
