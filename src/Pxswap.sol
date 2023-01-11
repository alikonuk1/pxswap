// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {SwapData} from "./SwapData.sol";
import {Ownable} from "./utils/Ownable.sol";
import {ERC20Interactions} from "./utils/ERC20Interactions.sol";
import {ERC721Interactions} from "./utils/ERC721Interactions.sol";
import {PxswapERC721Receiver} from "./utils/PxswapERC721Receiver.sol";

contract Pxswap is SwapData, Ownable, PxswapERC721Receiver, ERC721Interactions {
    event OpenBuy(address nft, uint256 amount, bool spesificId, uint256 id);
    event CancelBuy(uint256 id);
    event CancelSell(uint256 id);
    event OpenSell(address nft, uint256 amount, uint256 id);
    event SoldAtomic(address atomicSeller, uint256 buysId);
    event BoughtAtomic(address atomicBuyer, uint256 sellsId);

    address public protocol;
    uint256 public fee = 100; // %1
    bool public mutex;

    Buy[] public buys;
    Sell[] public sells;
    Swap[] public swaps;

    modifier noReentrancy() {
        require(!mutex, "Mutex is already set, reentrancy detected!");
        mutex = true;
        _;
        mutex = false;
    }

    function openSwap(address nftGiven, address tokenWant, uint256 amount) public noReentrancy {

    }

    function cancelSwap(uint256 id) public {

    }

    function acceptSwap() public {

    }

    function openBuy(address nftAddress, bool spesificId, uint256 id) public payable noReentrancy {
        require(msg.value > 0, "Value must be greater than zero");

        Buy memory buy;
        buy.buyer = msg.sender;
        buy.nft = nftAddress;
        buy.spesificId = spesificId;
        buy.tokenId = id;
        buy.amount = msg.value;
        buy.active = true;
        buys.push(buy);

        emit OpenBuy(nftAddress, msg.value, spesificId, id);
    }

    function cancelBuy(uint256 id) public noReentrancy {
        Buy storage buy = buys[id];
        require(msg.sender == buy.buyer, "Unauthorized call, cant cancel buy order!" );
        require(buy.active == true, "Buy order is not active!");

        buy.active = false;

        uint256 amount = buy.amount;
        uint256 protocolFee = amount / fee;
        uint256 amount_ = amount - protocolFee;
        address buyer = buy.buyer;

        (bool result0,) = payable(msg.sender).call{gas: (gasleft() - 10000), value: amount_}("");
        require(result0, "Call must return true");

        (bool result1,) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true");

        emit CancelBuy(id);
    }

    function openSell(address nft, uint256 tokenId, uint256 amount) public noReentrancy {
        require(amount > 0, "Amount must be greater than zero");

        _setNftContract(nft);
        // Ensure that msg.sender owns the token
        require(_nftBalance(msg.sender) >= 1, "Dont have enough nft!");
        _transferNft(msg.sender, address(this), tokenId);
        Sell memory sell;
        sell.seller = msg.sender;
        sell.nft = nft;
        sell.tokenId = tokenId;
        sell.amount = amount;
        sell.active = true;
        sells.push(sell);

        emit OpenSell(nft, amount, tokenId);
    }

    function cancelSell(uint256 id) public payable noReentrancy {
        Sell storage sell = sells[id];
        require(msg.sender == sell.seller, "Unauthorized call, cant cancel sell order!");
        require(sell.active == true, "Sell order is not active!");

        uint256 amount = sell.amount;
        uint256 protocolFee = amount / fee;

        require(msg.value >= protocolFee, "Protocol Fee must be paid");

        _setNftContract(sell.nft);

        require(_nftBalance(address(this)) >= 1, "Dont have enough nft!");

        (bool result1,) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true");

        sell.active = false;

        _transferNft(address(this), sell.seller, sell.tokenId);

        emit CancelSell(id);
    }

    function sellAtomic(uint256 id, address nft, uint256 tokenId) public noReentrancy {
        Buy storage buy = buys[id];
        require(buy.active == true, "Buy order is not active!");
        require(buy.nft == nft, "Wrong nft address!");
        if (buy.spesificId == true) {
            require(buy.tokenId == tokenId, "Wrong token id!");
        }
        buy.active = false;
        _setNftContract(nft);
        require(_nftBalance(msg.sender) >= 1, "Dont have enough nft!");

        _transferNft(msg.sender, buy.buyer, tokenId);

        uint256 amount = buy.amount;
        uint256 protocolFee = amount / fee;
        uint256 amount_ = amount - protocolFee;
        address buyer = buy.buyer;

        (bool result0,) = payable(msg.sender).call{gas: (gasleft() - 10000), value: amount_}("");
        require(result0, "Call must return true");

        (bool result1,) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true");

        emit SoldAtomic(msg.sender, id);
    }

    function buyAtomic(uint256 id) public payable noReentrancy {
        Sell storage sell = sells[id];
        require(sell.active == true, "Sell order is not active!");
        sell.active = false;

        uint256 amount = sell.amount;
        uint256 protocolFee = amount / fee;
        uint256 amount_ = amount + protocolFee;
        address seller = sell.seller;

        require(msg.value >= amount_, "Low value call!");

        (bool result0,) = payable(seller).call{gas: (gasleft() - 10000), value: amount}("");
        require(result0, "Call must return true!");

        (bool result1,) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true!");

        _setNftContract(sell.nft);
        _transferNft(address(this), msg.sender, sell.tokenId);

        emit BoughtAtomic(msg.sender, id);
    }

    function setProtocol(address protocol_) public onlyOwner {
        protocol = protocol_;
    }

    function setFee(uint256 fee_) public onlyOwner {
        fee = fee_;
    }
}
