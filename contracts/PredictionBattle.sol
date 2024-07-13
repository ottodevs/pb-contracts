// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SoulboundToken.sol";
import "./CommitmentSchema.sol";
import "./FundingPool.sol";

contract PredictionBattle {
    IERC20 public nounsToken;
    IERC20 public apeCoinToken;
    SoulboundToken public reputationToken;
    CommitmentSchema public commitmentSchema;
    FundingPool public fundingPool;

    struct Project {
        uint256 id;
        string name;
        uint256 totalVotes;
    }

    mapping(uint256 => Project) public projects;
    uint256 public projectCount;

    uint256 public wageDeadline;
    uint256 public resolutionDate;
    uint256 public fundingPool;
    uint256 public maxBetAmount;
    uint256 public constant SQRT_BASE = 1e9;

    mapping(address => uint256) public userTotalBets;

    constructor(
        address _nounsToken,
        address _apeCoinToken,
        address _reputationToken,
        address _commitmentSchema,
        address _fundingPool,
        uint256 _wageDeadline,
        uint256 _resolutionDate,
        uint256 _maxBetAmount
    ) {
        nounsToken = IERC20(_nounsToken);
        apeCoinToken = IERC20(_apeCoinToken);
        reputationToken = SoulboundToken(_reputationToken);
        commitmentSchema = CommitmentSchema(_commitmentSchema);
        fundingPool = FundingPool(_fundingPool);
        wageDeadline = _wageDeadline;
        resolutionDate = _resolutionDate;
        maxBetAmount = _maxBetAmount;
    }

    function addProject(string memory _name) external {
        projectCount++;
        projects[projectCount] = Project(projectCount, _name, 0);
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function placeBet(
        uint256 _projectId,
        uint256 _amount,
        bytes32 _commitment
    ) external {
        require(block.timestamp <= wageDeadline, "Betting period has ended");
        require(_projectId <= projectCount, "Invalid project ID");
        require(_amount <= maxBetAmount, "Bet exceeds maximum allowed amount");
        require(
            userTotalBets[msg.sender] + _amount <= maxBetAmount,
            "Total bets would exceed maximum allowed amount"
        );

        // Transfer tokens from user to contract
        require(
            nounsToken.transferFrom(msg.sender, address(this), _amount) ||
                apeCoinToken.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        // Store commitment
        commitmentSchema.submitCommitment(msg.sender, _commitment);

        userTotalBets[msg.sender] += _amount;
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

        // Calculate quadratic votes
        uint256 votes = sqrt(_amount * SQRT_BASE) * 100;
        projects[_projectId].totalVotes += votes;
    }

    function resolveMarket() external {
        require(
            block.timestamp > resolutionDate,
            "Resolution date has not arrived yet"
        );

        uint256 winningProjectId = 0;
        uint256 maxVotes = 0;
        for (uint256 i = 1; i <= projectCount; i++) {
            if (projects[i].totalVotes > maxVotes) {
                maxVotes = projects[i].totalVotes;
                winningProjectId = i;
            }
        }

        require(winningProjectId > 0, "No winning project found");

        // Authorize funding for winning project
        address projectAddress = address(uint160(winningProjectId)); // This is just an example, you'd need a proper way to store project addresses
        uint256 projectFunding = fundingPool / 2; // 50% to the winning project
        fundingPool.authorizeFunds(
            projectAddress,
            address(nounsToken),
            projectFunding / 2
        );
        fundingPool.authorizeFunds(
            projectAddress,
            address(apeCoinToken),
            projectFunding / 2
        );

        // Authorize remaining funds to correct predictors
        uint256 remainingFunds = fundingPool - projectFunding;
        address[] memory winners = commitmentSchema.getWinners(
            winningProjectId
        );
        uint256 rewardPerVote = remainingFunds /
            projects[winningProjectId].totalVotes;

        for (uint i = 0; i < winners.length; i++) {
            address winner = winners[i];
            (uint256 projectId, uint256 amount, ) = commitmentSchema
                .getRevealedBet(winner);
            if (projectId == winningProjectId) {
                uint256 votes = sqrt(amount * SQRT_BASE) * 100;
                uint256 reward = votes * rewardPerVote;
                fundingPool.authorizeFunds(
                    winner,
                    address(nounsToken),
                    reward / 2
                );
                fundingPool.authorizeFunds(
                    winner,
                    address(apeCoinToken),
                    reward / 2
                );
                reputationToken.mint(winner, 1); // Award 1 reputation token to each winner
            }
        }

        fundingPool = 0; // Reset funding pool
    }
}
