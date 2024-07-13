// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SoulboundToken.sol";
import "./CommitmentSchema.sol";

contract PredictionBattle {
    IERC20 public nounsToken;
    IERC20 public apeCoinToken;
    SoulboundToken public reputationToken;
    CommitmentSchema public commitmentSchema;

    struct Project {
        uint256 id;
        string name;
        uint256 totalBets;
    }

    mapping(uint256 => Project) public projects;
    uint256 public projectCount;

    uint256 public wageDeadline;
    uint256 public resolutionDate;
    uint256 public fundingPool;

    constructor(
        address _nounsToken,
        address _apeCoinToken,
        address _reputationToken,
        address _commitmentSchema,
        uint256 _wageDeadline,
        uint256 _resolutionDate
    ) {
        nounsToken = IERC20(_nounsToken);
        apeCoinToken = IERC20(_apeCoinToken);
        reputationToken = SoulboundToken(_reputationToken);
        commitmentSchema = CommitmentSchema(_commitmentSchema);
        wageDeadline = _wageDeadline;
        resolutionDate = _resolutionDate;
    }

    function addProject(string memory _name) external {
        projectCount++;
        projects[projectCount] = Project(projectCount, _name, 0);
    }

    function placeBet(
        uint256 _projectId,
        uint256 _amount,
        bytes32 _commitment
    ) external {
        require(block.timestamp <= wageDeadline, "Betting period has ended");
        require(_projectId <= projectCount, "Invalid project ID");

        // Transfer tokens from user to contract
        require(
            nounsToken.transferFrom(msg.sender, address(this), _amount) ||
                apeCoinToken.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        // Store commitment
        commitmentSchema.submitCommitment(msg.sender, _commitment);

        projects[_projectId].totalBets += _amount;
        fundingPool += _amount;
    }

    function revealBet(
        uint256 _projectId,
        uint256 _amount,
        uint256 _nonce
    ) external {
        require(
            block.timestamp > wageDeadline && block.timestamp <= resolutionDate,
            "Not in reveal phase"
        );
        commitmentSchema.revealBet(msg.sender, _projectId, _amount, _nonce);
    }

    function resolveMarket(uint256 _winningProjectId) external {
        require(
            block.timestamp > resolutionDate,
            "Resolution date has not arrived yet"
        );
        require(_winningProjectId <= projectCount, "Invalid project ID");

        // Distribute funding to winning project
        // This is a simplified version, you might want to add more complex distribution logic
        address projectAddress = address(uint160(_winningProjectId)); // This is just an example, you'd need a proper way to store project addresses
        uint256 projectFunding = fundingPool / 2; // 50% to the winning project
        nounsToken.transfer(projectAddress, projectFunding / 2);
        apeCoinToken.transfer(projectAddress, projectFunding / 2);

        // Distribute remaining funds to correct predictors
        // This is also simplified and would need more complex logic in a real implementation
        uint256 remainingFunds = fundingPool - projectFunding;
        address[] memory winners = commitmentSchema.getWinners(
            _winningProjectId
        );
        uint256 rewardPerWinner = remainingFunds / winners.length;
        for (uint i = 0; i < winners.length; i++) {
            nounsToken.transfer(winners[i], rewardPerWinner / 2);
            apeCoinToken.transfer(winners[i], rewardPerWinner / 2);
            reputationToken.mint(winners[i], 1); // Award 1 reputation token to each winner
        }

        fundingPool = 0; // Reset funding pool
    }
}
