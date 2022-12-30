// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {SwapData} from "./SwapData.sol";
import {Ownable} from "./utils/Ownable.sol";
import {PxswapERC721Receiver} from "./utils/PxswapERC721Receiver.sol";
import {ERC721Interactions} from "./utils/ERC721Interactions.sol";

contract Pxswap is SwapData, Ownable, PxswapERC721Receiver, ERC721Interactions{

    address public protocol;
    // 1% of amount
    // if 1000000000000000000 = 1 eth
    //     100000000000000000 = 0.1 eth
    // amount / 10 = protocolFee
    uint256 public fee = 100; // %1
    Buy[] public buys;
    Sell[] public sells;

    receive() external payable {}
    fallback() external payable {}

    function openBuy(address nftAddress, bool spesificId, uint256 id) public payable {
        Buy memory buy;
        buy.buyer = msg.sender;
        buy.nft = nftAddress;
        buy.spesificId = spesificId;
        buy.tokenId = id;
        buy.amount = msg.value;
        buy.active = true;
        buys.push(buy);
    }

    function openSell(address nft, uint256 tokenId, uint256 amount) public {
        Sell memory sell;
        _setNftContract(nft);
        require(_nftBalance(msg.sender) >= 1, "Dont have enough nft!");
        _transferNft(msg.sender, address(this), tokenId);
        sell.seller = msg.sender;
        sell.nft = nft;
        sell.tokenId = tokenId;
        sell.amount = amount;
        sell.active = true;
        sells.push(sell);
    }

    function sellAtomic(uint256 id, address nft, uint256 tokenId) public {
        require(buys[id].active == true, "Buy order is not active!");
        require(buys[id].nft == nft, "Wrong nft address!");
        if(buys[id].spesificId == true){
            require(buys[id].tokenId == tokenId, "Wrong token id!");
        }
        _setNftContract(nft);
        require(_nftBalance(msg.sender) >= 1, "Dont have enough nft!");
        buys[id].active = false;

        _transferNft(msg.sender, buys[id].buyer, tokenId);

        uint256 amount = buys[id].amount;
        uint256 protocolFee = amount / fee;
        uint256 amount_ = amount - protocolFee;
        address buyer = buys[id].buyer;
        
        (bool result0,) = payable(msg.sender).call{gas: (gasleft() - 10000), value: amount_}("");
        require(result0, "Call must return true");

        (bool result1,) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true");

    }

    function buyAtomic(uint256 id) public payable {
        require(sells[id].active == true, "Sell order is not active!");

        uint256 amount = sells[id].amount;
        uint256 protocolFee = amount / fee;
        uint256 amount_ = amount + protocolFee;
        address seller = sells[id].seller;

        require(msg.value >= amount_, "Low value call!");
        sells[id].active = false;

        (bool result0, ) = payable(seller).call{gas: (gasleft() - 10000), value: amount}("");
        require(result0, "Call must return true!");

        (bool result1, ) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true!");

        _setNftContract(sells[id].nft);
        _transferNft(address(this), msg.sender, sells[id].tokenId);

    }

    function setProtocol(address protocol_) public onlyOwner {
        protocol = protocol_;
    }

    function setFee(uint256 fee_) public onlyOwner {
        fee = fee_;
    }

}
