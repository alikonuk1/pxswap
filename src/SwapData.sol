// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.15;

contract SwapData {
    struct Buy {
        bool active;
        bool spesificId;
        address buyer;
        address nft;
        uint256 tokenId;
        uint256 amount;
    }

    struct Sell {
        bool active;
        address seller;
        address nft;
        uint256 tokenId;
        uint256 amount;
    }

    struct Swap {
        bool active;
        bool isNft;
        bool spesificId;
        address seller;
        address wantNft;
        address giveNft;
        address wantErc20;
        uint256 amount;
        uint256 wantId;
        uint256 giveId;
    }
}
