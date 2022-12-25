// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {SwapData} from "./SwapData.sol";
import {Ownable} from "./utils/Ownable.sol";

contract Pxswap is SwapData, Ownable{

    address public protocol;
    // 1% of amount
    // if 1000000000000000000 = 1 eth
    //     100000000000000000 = 0.1 eth
    // amount / 10 = protocolFee
    uint256 public fee = 10; // %1
    Buy[] public buys;
    Sell[] public sells;

    receive() external payable {}
    fallback() external payable {}

    function openBuy(address nftAddress) public payable {
        Buy memory buy;
        buy.buyer = msg.sender;
        buy.nft = nftAddress;
        buy.amount = msg.value;
        buy.active = true;
        buys.push(buy);
    }

    function openSell(address nftAddress, uint256 tokenId, uint256 amount) public {
        Sell memory sell;
        //TODO: transfer nft
        sell.seller = msg.sender;
        sell.nft = nftAddress;
        sell.tokenId = tokenId;
        sell.amount = amount;
        sell.active = true;
        sells.push(sell);
    }

    function sellAtomic(uint256 id) public {
        Buy memory buy_ = buys[id];
        require(buy_.active == true, "Buy order is not active!");

        uint256 amount = buy_.amount;
        uint256 protocolFee = amount / fee;
        uint256 amount_ = amount - protocolFee;
        address buyer = buy_.buyer;
        
        (bool result0,) = payable(msg.sender).call{gas: (gasleft() - 10000), value: amount_}("");
        require(result0, "Call must return true");

        (bool result1,) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true");

/*         payable(msg.sender).transfer(amount);

        payable(protocol).transfer(protocolFee); */

        buy_.active = false;

    }

    function buyAtomic(uint256 id) public payable {
        Sell memory sell_ = sells[id];
        require(sell_.active == true, "Sell order is not active!");

        uint256 amount = sell_.amount;
        uint256 protocolFee = amount / fee;
        uint256 amount_ = amount + protocolFee;
        address seller = sell_.seller;

        require(msg.value >= amount_, "Low value call!");

        (bool result0, ) = payable(seller).call{gas: (gasleft() - 10000), value: amount}("");
        require(result0, "Call must return true!");

        (bool result1, ) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true!");

    }

    function setProtocol(address protocol_) public onlyOwner {
        protocol = protocol_;
    }

    function setFee(uint256 fee_) public onlyOwner {
        fee = fee_;
    }
}
