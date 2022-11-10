// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./MultiOwnable.sol";

contract AuthenticationNFT is ERC721Enumerable, MultiOwnable {
    uint256 internal _nextId;

    constructor() ERC721("Gyroscope authentication NFT", "GYAT") MultiOwnable() {}

    function mint(address to) external onlyOwner {
        uint256 id = _nextId;
        _mint(to, id);
        _nextId = id + 1;
    }

    function burn(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }
}
