//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract ERC721Interactions {
    event NftSet(address setter, address nft);

    address private nft;

    function _setNftContract(address _nft) internal {
/*         require(nft != _nft, "ERC721Interactions: The new address is the same as the old one"); */
        emit NftSet(msg.sender, _nft);
        nft = _nft;
    }

    function getNft() internal view returns (address) {
        return nft;
    }

    function _nftBalance(address owner) internal view returns (uint256) {
        IERC721 _nft = IERC721(nft);
        uint256 nftBalance = _nft.balanceOf(owner);
        return nftBalance;
    }

    function _transferNft(address from, address to, uint256 id) internal {
        IERC721 _nft = IERC721(nft);
        _nft.safeTransferFrom(from, to, id);
    }
}
