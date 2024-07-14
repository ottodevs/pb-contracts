// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

contract SoulboundReputation is ERC1155, Ownable {
    address public immutable myAddr;
    string public name;
    string public symbol;
    mapping(address => uint256) private _reputationScores;

    event ReputationChanged(address indexed account, uint256 newScore);

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC1155("") Ownable(msg.sender) {
        name = _name;
        symbol = _symbol;
        myAddr = address(this);
    }

    function mint(address to, uint256 tokenId) external onlyOwner {
        require(balanceOf(to, tokenId) == 0, "Address already has this token");
        _mint(to, tokenId, 1, "");
        _reputationScores[to] = 1; // Set the initial reputation score to 1
        emit ReputationChanged(to, 1);
    }

    function updateReputation(
        address account,
        uint256 tokenId,
        uint256 newScore
    ) external onlyOwner {
        require(
            balanceOf(account, tokenId) != 0,
            "Account does not have this token"
        );
        _reputationScores[account] = newScore;
        emit ReputationChanged(account, newScore);
    }

    function getReputation(address account) external view returns (uint256) {
        return _reputationScores[account];
    }

    function hasToken(
        address account,
        uint256 tokenId
    ) external view returns (bool) {
        return balanceOf(account, tokenId) != 0;
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override {
        revert("Soulbound tokens cannot be transferred");
    }

    function safeBatchTransferFrom(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure override {
        revert("Soulbound tokens cannot be transferred");
    }

    function transferOwnership(
        address newOwner
    ) public virtual override onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }
}
