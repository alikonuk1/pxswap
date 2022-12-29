// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/forge-std/src/Test.sol";
import "../src/Pxswap.sol";
import "./mock/mockERC721.sol";


contract PxswapTest is Test {
    Pxswap px;
    MockERC721 bayc;

    address creator = address(1);
    address seller1 = address(2);
    address seller2 = address(3);
    address seller3 = address(4);
    address buyer1 = address(5);
    address buyer2 = address(6);
    address buyer3 = address(7);
    address hacker = address(9);
    address protocol = address(32);

    function setUp() public {
        vm.startPrank(creator);
        px = new Pxswap();
        px.setProtocol(address(protocol));
        bayc = new MockERC721("MockBayc", "BAYC");
        vm.stopPrank();

        //top up accounts with ether
        vm.deal(seller1, 999 ether);
        vm.deal(seller2, 999 ether);
        vm.deal(seller3, 999 ether);
        vm.deal(buyer1, 999 ether);
        vm.deal(buyer2, 999 ether);
        vm.deal(buyer3, 999 ether);
        vm.deal(hacker, 9999 ether);
        
        vm.startPrank(seller1);
        bayc.mintTo(seller1);
        bayc.mintTo(seller1);
        bayc.mintTo(seller1);
        vm.stopPrank();
        vm.startPrank(seller2);
        bayc.mintTo(seller2);
        vm.stopPrank();
        vm.startPrank(seller3);
        bayc.mintTo(seller3);
        vm.stopPrank();
    }

    function testSuccess_OpenBuy_SellAtomic() public {
        vm.startPrank(buyer1);
        px.openBuy{value: 30 ether}(address(bayc), false, 3);
        vm.stopPrank();

        assertEq(address(px).balance, 30 ether);
        assertEq(address(buyer1).balance, 969 ether);
        assertEq(address(protocol).balance, 0 ether);
        assertEq(bayc.balanceOf(buyer1), 0);

        vm.startPrank(seller1);
        bayc.approve(address(px), 1);
        px.sellAtomic(0, address(bayc), 1);
        vm.stopPrank();
        
        assertEq(bayc.balanceOf(buyer1), 1);
        assertEq(bayc.balanceOf(seller1), 2);
        assertEq(address(px).balance, 0 ether);
        assertEq(address(protocol).balance, 3 ether);
        assertEq(address(seller1).balance, 1026 ether);
    }

    function testRevert_OpenBuy_SellAtomicWrongId() public {
        vm.startPrank(buyer1);
        px.openBuy{value: 30 ether}(address(bayc), true, 3);
        vm.stopPrank();

        assertEq(address(px).balance, 30 ether);
        assertEq(address(buyer1).balance, 969 ether);
        assertEq(address(protocol).balance, 0 ether);
        assertEq(bayc.balanceOf(buyer1), 0);

        vm.startPrank(seller1);
        bayc.approve(address(px), 1);
        vm.expectRevert("Wrong token id!");
        px.sellAtomic(0, address(bayc), 1);
        vm.stopPrank();

    }

    function testRevert_OpenBuy_SellAtomicBidClosed() public {
        vm.startPrank(buyer1);
        px.openBuy{value: 30 ether}(address(bayc), false, 3);
        vm.stopPrank();

        assertEq(address(px).balance, 30 ether);
        assertEq(address(buyer1).balance, 969 ether);
        assertEq(address(protocol).balance, 0 ether);
        assertEq(bayc.balanceOf(buyer1), 0);

        vm.startPrank(seller1);
        bayc.approve(address(px), 1);
        px.sellAtomic(0, address(bayc), 1);
        vm.stopPrank();
        
        assertEq(bayc.balanceOf(buyer1), 1);
        assertEq(bayc.balanceOf(seller1), 2);
        assertEq(address(px).balance, 0 ether);
        assertEq(address(protocol).balance, 3 ether);
        assertEq(address(seller1).balance, 1026 ether);

        vm.startPrank(seller2);
        bayc.approve(address(px), 4);
        vm.expectRevert("Buy order is not active!");
        px.sellAtomic(0, address(bayc), 4);
        vm.stopPrank();
    }

    function testSuccess_OpenBuy_SellAtomicSpesificId() public {
        vm.startPrank(buyer1);
        px.openBuy{value: 30 ether}(address(bayc), true, 1);
        vm.stopPrank();

        assertEq(address(px).balance, 30 ether);
        assertEq(address(buyer1).balance, 969 ether);
        assertEq(address(protocol).balance, 0 ether);
        assertEq(bayc.balanceOf(buyer1), 0);

        vm.startPrank(seller1);
        bayc.approve(address(px), 1);
        px.sellAtomic(0, address(bayc), 1);
        vm.stopPrank();
        
        assertEq(bayc.balanceOf(buyer1), 1);
        assertEq(bayc.balanceOf(seller1), 2);
        assertEq(address(px).balance, 0 ether);
        assertEq(address(protocol).balance, 3 ether);
        assertEq(address(seller1).balance, 1026 ether);
    }

     function testSuccess_OpenSell_BuyAtomic() public {
        assertEq(bayc.balanceOf(seller1), 3);
        assertEq(bayc.balanceOf(address(px)), 0);

        vm.startPrank(seller1);
        bayc.approve(address(px), 1);
        px.openSell(address(bayc), 1, 10 ether);
        vm.stopPrank();

        assertEq(bayc.balanceOf(seller1), 2);
        assertEq(bayc.balanceOf(address(px)), 1);
        assertEq(address(px).balance, 0 ether);
        assertEq(address(protocol).balance, 0 ether);

        vm.startPrank(buyer1);
        px.buyAtomic{value: 11 ether}(0);
        vm.stopPrank();
        
        assertEq(bayc.balanceOf(seller1), 2);
        assertEq(bayc.balanceOf(address(px)), 0);
        assertEq(bayc.balanceOf(buyer1), 1);
        assertEq(address(px).balance, 0 ether);
        assertEq(address(protocol).balance, 1 ether);
        assertEq(address(seller1).balance, 1009 ether);
    }

    function testRevert_OpenSell_BuyAtomicBidClosed() public {
        assertEq(bayc.balanceOf(seller1), 3);
        assertEq(bayc.balanceOf(address(px)), 0);

        vm.startPrank(seller1);
        bayc.approve(address(px), 1);
        px.openSell(address(bayc), 1, 10 ether);
        vm.stopPrank();

        assertEq(bayc.balanceOf(seller1), 2);
        assertEq(bayc.balanceOf(address(px)), 1);
        assertEq(address(px).balance, 0 ether);
        assertEq(address(protocol).balance, 0 ether);

        vm.startPrank(buyer1);
        px.buyAtomic{value: 11 ether}(0);
        vm.stopPrank();
        
        assertEq(bayc.balanceOf(seller1), 2);
        assertEq(bayc.balanceOf(address(px)), 0);
        assertEq(bayc.balanceOf(buyer1), 1);
        assertEq(address(px).balance, 0 ether);
        assertEq(address(protocol).balance, 1 ether);
        assertEq(address(seller1).balance, 1009 ether);

        vm.startPrank(seller3);
        vm.expectRevert("Sell order is not active!");
        px.buyAtomic{value: 11 ether}(0);
        vm.stopPrank();
    }

    function testSuccess_setProtocol() public {
        assertEq(px.protocol(), address(protocol));

        vm.startPrank(creator);
        px.setProtocol(address(999));
        vm.stopPrank();

        assertEq(px.protocol(), address(999));
    }

    function testRevert_setProtocol_NonOwner() public {
        assertEq(px.protocol(), address(protocol));

        vm.startPrank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        px.setProtocol(hacker);
        vm.stopPrank();
    }

    function testSucces_setFee() public {
        assertEq(px.fee(), 10);

        vm.startPrank(creator);
        px.setFee(30);
        vm.stopPrank();

        assertEq(px.fee(), 30);
    }

    function testRevert_setFee_NonOwner() public {
        assertEq(px.fee(), 10);

        vm.startPrank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        px.setFee(30);
        vm.stopPrank();
    }

}

