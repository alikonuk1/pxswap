// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.15;

import {SwapData} from "./SwapData.sol";
import {Ownable} from "./utils/Ownable.sol";
import {ERC20Interactions} from "./utils/ERC20Interactions.sol";
import {ERC721Interactions} from "./utils/ERC721Interactions.sol";
import {PxswapERC721Receiver} from "./utils/PxswapERC721Receiver.sol";

/**
 * @title pxswap
 * @author pxswap
 * @dev This contract is for buying and selling non-fungible tokens (NFTs)
 * through atomic swaps
 */
contract Pxswap is SwapData, Ownable, PxswapERC721Receiver, ERC20Interactions, ERC721Interactions {
    event OpenBuy(address nft, uint256 amount, bool spesificId, uint256 id);
    event CancelBuy(uint256 id);
    event CancelSell(uint256 id);
    event CancelSwap(uint256 id);
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

    function openSwap(
        address nftGiven,
        uint256 giveId,
        bool isNft,
        /*         bool spesificId, */
        address wantNft,
        address wantToken,
        uint256 amount
    )
        /*         uint256 wantId  */
        public
        noReentrancy
    {
        _setNftContract(nftGiven);
        require(_nftBalance(msg.sender) >= 1, "Dont have enough nft!");
        _transferNft(msg.sender, address(this), giveId);

        Swap memory swap;
        swap.seller = msg.sender;
        swap.giveNft = nftGiven;
        swap.giveId = giveId;
        swap.isNft = isNft;

        if (isNft == true) {
            swap.wantNft = wantNft;
            swap.active = true;
            swaps.push(swap);
        } else {
            swap.wantToken = wantToken;
            swap.amount = amount;
            swap.active = true;
            swaps.push(swap);
        }
    }

    function cancelSwap(uint256 id) public {
        Swap storage swap = swaps[id];
        require(msg.sender == swap.seller, "Unauthorized call, cant cancel swap!");
        require(swap.active == true, "Swap is not active!");

        swap.active = false;

        emit CancelSwap(id);
    }

    function acceptSwap(uint256 id, uint256 wantId) public {
        Swap storage swap = swaps[id];
        require(swap.active == true, "Swap is not active!");

        if (swap.isNft == true) {
            // Set the NFT contract to perform actions
            _setNftContract(swap.wantNft);
            // Ensure that msg.sender owns the NFT
            require(_nftBalance(msg.sender) >= 1, "Dont have enough nft!");
            _transferNft(msg.sender, swap.seller, wantId);

            swap.active = false;
        } else {
            _setTokenContract(swap.wantToken);

            require(_tokenBalance(msg.sender) >= swap.amount, "Dont have enough tokens!");
            _transferTokens(msg.sender, swap.seller, swap.amount);

            swap.active = false;
        }

        _setNftContract(swap.giveNft);
        require(_nftBalance(address(this)) >= 1, "Dont have enough nft!");
        _transferNft(address(this), msg.sender, swap.giveId);
    }

    /**
     * @dev Opens a new buy order for a specific NFT and ID or any NFT
     * @param nftAddress the address of the NFT contract
     * @param spesificId boolean indicating if the order is for a specific tokenId
     * @param id the id of the NFT (if spesificId is true)
     * @notice msg.value the value of the order in wei, must be greater than zero
     */
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

    /**
     * @dev Cancels a buy order for NFT
     * @param id the id of the buy order
     * @notice msg.sender the address of the buyer, should be the same as the address
     * that made the buy order
     */
    function cancelBuy(uint256 id) public noReentrancy {
        Buy storage buy = buys[id];
        require(msg.sender == buy.buyer, "Unauthorized call, cant cancel buy order!");
        require(buy.active == true, "Buy order is not active!");

        buy.active = false;

        uint256 amount = buy.amount;
        uint256 protocolFee = amount / fee;
        uint256 amount_ = amount - protocolFee;

        (bool result0,) = payable(msg.sender).call{gas: (gasleft() - 10000), value: amount_}("");
        require(result0, "Call must return true");

        (bool result1,) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true");

        emit CancelBuy(id);
    }

    /**
     * @dev Creates a sell order for an NFT
     * @param nft the address of the NFT contract
     * @param tokenId the tokenId of the NFT to be sold
     * @param amount the selling price for the NFT
     * @notice msg.sender the address of the NFT owner
     */
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

    /**
     * @dev Allows seller to cancel an open sell order and receive their NFT back
     * @param id The ID of the sell order
     * @notice Only the seller of the NFT can cancel the sell order
     * @notice A protocol fee is charged for cancelling the sell order
     */
    function cancelSell(uint256 id) public payable noReentrancy {
        // Retrieve sell order from storage
        Sell storage sell = sells[id];
        // Check if msg.sender is the seller of the NFT
        require(msg.sender == sell.seller, "Unauthorized call, cant cancel sell order!");
        // Check if sell order is active
        require(sell.active == true, "Sell order is not active!");

        uint256 amount = sell.amount;
        uint256 protocolFee = amount / fee;

        // Check if protocol fee has been paid
        require(msg.value >= protocolFee, "Protocol Fee must be paid");

        _setNftContract(sell.nft);

        require(_nftBalance(address(this)) >= 1, "Dont have enough nft!");

        //pay the protocol fee
        (bool result1,) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        require(result1, "Call must return true");

        //set the sell order inactive
        sell.active = false;

        //transfer the nft back to the seller
        _transferNft(address(this), sell.seller, sell.tokenId);

        emit CancelSell(id);
    }
    /**
     * @dev Function to sell an NFT at a specific Buy order, also known as Atomic Swaps
     * @param id The ID of the Buy order to sell to
     * @param nft The address of the NFT contract of the NFT being sold
     * @param tokenId The ID of the NFT being sold
     */

    function sellAtomic(uint256 id, address nft, uint256 tokenId) public noReentrancy {
        // Retrieve the Buy order from storage
        Buy storage buy = buys[id];
        // Ensure that the Buy order is active
        require(buy.active == true, "Buy order is not active!");
        // Ensure that the NFT address being sold is the same as the Buy order's NFT address
        require(buy.nft == nft, "Wrong nft address!");
        // Ensure that the tokenId being sold is the same as the Buy order's tokenId, if the Buy order is looking for a specific tokenId
        if (buy.spesificId == true) {
            require(buy.tokenId == tokenId, "Wrong token id!");
        }
        // Deactivate the Buy order
        buy.active = false;
        // Set the NFT contract to perform actions
        _setNftContract(nft);
        // Ensure that msg.sender owns the NFT
        require(_nftBalance(msg.sender) >= 1, "Dont have enough nft!");

        // Transfer the NFT to the Buyer
        _transferNft(msg.sender, buy.buyer, tokenId);

        uint256 amount = buy.amount;
        // Calculate the protocol fee
        uint256 protocolFee = amount / fee;
        // Calculate the amount to be sent to seller
        uint256 amount_ = amount - protocolFee;

        // call payable function from the seller with the calculated amount
        (bool result0,) = payable(msg.sender).call{gas: (gasleft() - 10000), value: amount_}("");
        // require that call must return true
        require(result0, "Call must return true");

        // call payable function to protocol
        (bool result1,) = payable(protocol).call{gas: (gasleft() - 10000), value: protocolFee}("");
        // require that call must return true
        require(result1, "Call must return true");

        // Emit an event indicating that the Atomic Swap is complete
        emit SoldAtomic(msg.sender, id);
    }

    /**
     * @dev buy an NFT with a sell order ID
     * @param id uint256 - ID of sell order
     * @notice msg.value should be greater or equal than (sell.amount + sell.amount/fee)
     * @notice call must return true on payable(seller).call and payable(protocol).call
     * @notice _transferNft must complete successfully
     */
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
    /**
     * @dev Function to set the protocol address.
     * @param protocol_ The address of the protocol.
     */

    function setProtocol(address protocol_) public onlyOwner {
        protocol = protocol_;
    }

    /**
     * @dev Allows the contract owner to set the transaction fee.
     * @param fee_ The new transaction fee.
     */
    function setFee(uint256 fee_) public onlyOwner {
        fee = fee_;
    }
}
