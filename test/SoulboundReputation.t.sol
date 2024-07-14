// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SoulboundReputation.sol";
import "forge-std/console.sol";

error OwnableUnauthorizedAccount(address account);

contract SoulboundReputationTest is Test {
    SoulboundReputation public soulboundRep;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        soulboundRep = new SoulboundReputation("TestReputation", "TREP");
    }

    function testInitialState() public {
        assertEq(soulboundRep.name(), "TestReputation");
        assertEq(soulboundRep.symbol(), "TREP");
        assertEq(soulboundRep.owner(), owner);
    }

    function testMint() public {
        uint256 tokenId = 1;
        soulboundRep.mint(user1, tokenId);
        assertEq(soulboundRep.balanceOf(user1, tokenId), 1);
        assertTrue(soulboundRep.hasToken(user1, tokenId));
        assertEq(soulboundRep.getReputation(user1), 0);
    }

    function testMintOnlyOwner() public {
        uint256 tokenId = 1;
        console.log("Test contract address:", address(this));
        console.log("User1 address:", user1);

        vm.prank(user1);
        console.log("Current caller (should be user1):", msg.sender);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1)
        );
        soulboundRep.mint(user2, tokenId);
    }

    function testCannotMintTwice() public {
        uint256 tokenId = 1;
        soulboundRep.mint(user1, tokenId);
        vm.expectRevert("Address already has this token");
        soulboundRep.mint(user1, tokenId);
    }

    function testUpdateReputation() public {
        uint256 tokenId = 1;
        soulboundRep.mint(user1, tokenId);
        soulboundRep.updateReputation(user1, tokenId, 100);
        assertEq(soulboundRep.getReputation(user1), 100);
    }

    function testUpdateReputationOnlyOwner() public {
        uint256 tokenId = 1;
        soulboundRep.mint(user1, tokenId);
        console.log("Test contract address:", address(this));
        console.log("User2 address:", user2);

        vm.prank(user2);
        console.log("Current caller (should be user2):", msg.sender);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user2)
        );
        soulboundRep.updateReputation(user1, tokenId, 100);
    }

    function testCannotUpdateReputationWithoutToken() public {
        uint256 tokenId = 1;
        vm.expectRevert("Account does not have this token");
        soulboundRep.updateReputation(user1, tokenId, 100);
    }

    function testTransferOwnership() public {
        soulboundRep.transferOwnership(user1);
        assertEq(soulboundRep.owner(), user1);
    }

    function testCannotTransfer() public {
        uint256 tokenId = 1;
        soulboundRep.mint(user1, tokenId);
        vm.prank(user1);
        vm.expectRevert("Soulbound tokens cannot be transferred");
        soulboundRep.safeTransferFrom(user1, user2, tokenId, 1, "");
    }

    function testCannotBatchTransfer() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        soulboundRep.mint(user1, 1);
        vm.prank(user1);
        vm.expectRevert("Soulbound tokens cannot be transferred");
        soulboundRep.safeBatchTransferFrom(user1, user2, ids, amounts, "");
    }

    function testEmitReputationChangedEvent() public {
        uint256 tokenId = 1;
        soulboundRep.mint(user1, tokenId);
        vm.expectEmit(true, false, false, true);
        emit SoulboundReputation.ReputationChanged(user1, 100);
        soulboundRep.updateReputation(user1, tokenId, 100);
    }
}
