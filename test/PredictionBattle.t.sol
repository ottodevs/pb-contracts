// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/PredictionBattle.sol";
import "../src/SoulboundReputation.sol";
import "../src/CommitmentSchema.sol";
import "../src/FundingPool.sol";
import {MockERC20Token} from "./mocks/MockERC20Token.sol";

contract PredictionBattleTest is Test {
    PredictionBattle public predictionBattle;
    SoulboundReputation public soulboundReputation;
    CommitmentSchema public commitmentSchema;
    FundingPool public fundingPool;
    MockERC20Token public bettingToken;

    address public admin = address(1);
    address public sponsor = address(2);
    address[20] public betters;

    uint256 public constant BETTING_AMOUNT = 100 ether;

    function setUp() public {
        vm.startPrank(admin);

        setupContracts();
        setupRoles();
        mintTokensToUsers();

        vm.stopPrank();
    }

    function setupContracts() private {
        bettingToken = new MockERC20Token("Betting Token", "BET");
        soulboundReputation = new SoulboundReputation("Reputation", "REP");
        commitmentSchema = new CommitmentSchema();
        fundingPool = new FundingPool();

        predictionBattle = new PredictionBattle(
            address(bettingToken),
            address(soulboundReputation),
            address(commitmentSchema),
            address(fundingPool)
        );

        soulboundReputation.transferOwnership(address(predictionBattle));
    }

    function setupRoles() private {
        predictionBattle.grantRole(predictionBattle.ADMIN_ROLE(), admin);
        predictionBattle.grantRole(predictionBattle.SPONSOR_ROLE(), sponsor);
        fundingPool.grantRole(fundingPool.SPONSOR_ROLE(), sponsor);
        fundingPool.grantRole(
            fundingPool.AUTHORIZER_ROLE(),
            address(predictionBattle)
        );
    }

    function mintTokensToUsers() private {
        bettingToken.mint(sponsor, 1000 ether);
        for (uint i = 0; i < 20; i++) {
            betters[i] = address(uint160(i + 100));
            bettingToken.mint(betters[i], BETTING_AMOUNT);
        }
    }

    function testCreateRound() public {
        vm.startPrank(admin);
        uint256[] memory prizeDistribution = new uint256[](3);
        prizeDistribution[0] = 50;
        prizeDistribution[1] = 30;
        prizeDistribution[2] = 20;

        predictionBattle.createRound(
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            10 ether,
            100 ether,
            prizeDistribution
        );

        assertEq(
            predictionBattle.currentRoundId(),
            1,
            "Round should be created"
        );
        vm.stopPrank();
    }

    function testAddProjects() public {
        testCreateRound();

        vm.startPrank(admin);
        for (uint i = 1; i <= 10; i++) {
            predictionBattle.addProject(
                1,
                string(abi.encodePacked("Project ", vm.toString(i)))
            );
        }
        vm.stopPrank();

        (, , , , , , uint256 projectCount, uint256 totalBets) = predictionBattle
            .rounds(1);

        assertEq(projectCount, 10, "Should have 10 projects");
    }

    function testPlaceBet() public {
        testAddProjects();

        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(betters[0]);
        bettingToken.approve(address(predictionBattle), BETTING_AMOUNT);
        predictionBattle.placeBet(1, 1, BETTING_AMOUNT);
        vm.stopPrank();

        (, , , , , , , uint256 totalBets) = predictionBattle.rounds(1);

        assertEq(totalBets, BETTING_AMOUNT, "Total bets should be updated");
    }

    function testMultipleBets() public {
        testAddProjects();

        vm.warp(block.timestamp + 1 days + 1);

        for (uint i = 0; i < 20; i++) {
            vm.startPrank(betters[i]);
            bettingToken.approve(address(predictionBattle), BETTING_AMOUNT);
            predictionBattle.placeBet(1, (i % 10) + 1, BETTING_AMOUNT);
            vm.stopPrank();
        }

        (, , , , , , , uint256 totalBets) = predictionBattle.rounds(1);

        assertEq(
            totalBets,
            BETTING_AMOUNT * 20,
            "Total bets should be updated for all betters"
        );
    }

    function testSponsorDeposit() public {
        vm.startPrank(sponsor);
        bettingToken.approve(address(fundingPool), 1000 ether);
        fundingPool.depositFunds(address(bettingToken), 1000 ether);
        vm.stopPrank();

        assertEq(
            fundingPool.getTokenBalance(address(bettingToken)),
            1000 ether,
            "Funding pool should have correct balance"
        );
    }
}
