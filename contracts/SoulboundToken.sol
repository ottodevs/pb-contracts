// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SoulboundToken is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    constructor() ERC721("ReputationToken", "REP") {}

    function mint(address to, uint256 amount) external onlyOwner {
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(to, _tokenIdCounter);
            _tokenIdCounter++;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        require(
            from == address(0) || to == address(0),
            "Token is soulbound and cannot be transferred"
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}
