// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./SoulboundReputation.sol";
import "./CommitmentSchema.sol";
import "./FundingPool.sol";

contract PredictionBattle is AccessControl {
    IERC20 public bettingToken;
    SoulboundReputation public soulboundReputation;
    CommitmentSchema public commitmentSchema;
    FundingPool public fundingPool;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SPONSOR_ROLE = keccak256("SPONSOR_ROLE");

    struct Project {
        uint256 id;
        string name;
        uint256 totalBets;
    }

    struct Round {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 resolutionTime;
        uint256 lowBetCap;
        uint256 highBetCap;
        uint256[] prizeDistribution;
        mapping(uint256 => Project) projects;
        uint256 projectCount;
        uint256 totalBets;
    }

    mapping(uint256 => Round) public rounds;
    uint256 public currentRoundId;

    event RoundCreated(
        uint256 indexed roundId,
        uint256 startTime,
        uint256 endTime
    );
    event ProjectAdded(
        uint256 indexed roundId,
        uint256 indexed projectId,
        string name
    );
    event BetPlaced(
        uint256 indexed roundId,
        address indexed better,
        uint256 indexed projectId,
        uint256 amount
    );

    constructor(
        address _bettingToken,
        address _soulboundReputation,
        address _commitmentSchema,
        address _fundingPool
    ) {
        bettingToken = IERC20(_bettingToken);
        soulboundReputation = SoulboundReputation(_soulboundReputation);
        commitmentSchema = CommitmentSchema(_commitmentSchema);
        fundingPool = FundingPool(_fundingPool);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function createRound(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _resolutionTime,
        uint256 _lowBetCap,
        uint256 _highBetCap,
        uint256[] memory _prizeDistribution
    ) external onlyRole(ADMIN_ROLE) {
        require(
            _startTime > block.timestamp,
            "Start time must be in the future"
        );
        require(_endTime > _startTime, "End time must be after start time");
        require(
            _resolutionTime > _endTime,
            "Resolution time must be after end time"
        );
        require(
            _highBetCap > _lowBetCap,
            "High bet cap must be greater than low bet cap"
        );

        currentRoundId++;
        Round storage newRound = rounds[currentRoundId];
        newRound.id = currentRoundId;
        newRound.startTime = _startTime;
        newRound.endTime = _endTime;
        newRound.resolutionTime = _resolutionTime;
        newRound.lowBetCap = _lowBetCap;
        newRound.highBetCap = _highBetCap;
        newRound.prizeDistribution = _prizeDistribution;

        emit RoundCreated(currentRoundId, _startTime, _endTime);
    }

    function addProject(
        uint256 _roundId,
        string memory _name
    ) external onlyRole(ADMIN_ROLE) {
        Round storage round = rounds[_roundId];
        require(
            block.timestamp < round.startTime,
            "Cannot add projects after round has started"
        );

        round.projectCount++;
        round.projects[round.projectCount] = Project(
            round.projectCount,
            _name,
            0
        );

        emit ProjectAdded(_roundId, round.projectCount, _name);
    }

    function placeBet(
        uint256 _roundId,
        uint256 _projectId,
        uint256 _amount
    ) external {
        Round storage round = rounds[_roundId];
        require(
            block.timestamp >= round.startTime &&
                block.timestamp <= round.endTime,
            "Betting is not open"
        );
        require(
            _amount >= round.lowBetCap && _amount <= round.highBetCap,
            "Bet amount out of range"
        );
        require(
            _projectId > 0 && _projectId <= round.projectCount,
            "Invalid project ID"
        );

        require(
            bettingToken.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        round.projects[_projectId].totalBets += _amount;
        round.totalBets += _amount;

        emit BetPlaced(_roundId, msg.sender, _projectId, _amount);
    }

    function revealBet(
        uint256 _roundId,
        uint256 _projectId,
        uint256 _amount,
        uint256 _nonce
    ) external {
        Round storage round = rounds[_roundId];
        require(
            block.timestamp > round.endTime &&
                block.timestamp <= round.resolutionTime,
            "Not in reveal phase"
        );
        commitmentSchema.revealBet(msg.sender, _projectId, _amount, _nonce);

        // Update project bets
        round.projects[_projectId].totalBets += _amount;
    }

    function resolveMarket(uint256 _roundId) external {
        Round storage round = rounds[_roundId];
        require(
            block.timestamp > round.resolutionTime,
            "Resolution time has not arrived yet"
        );

        uint256 winningProjectId = 0;
        uint256 maxBets = 0;
        for (uint256 i = 1; i <= round.projectCount; i++) {
            if (round.projects[i].totalBets > maxBets) {
                maxBets = round.projects[i].totalBets;
                winningProjectId = i;
            }
        }

        require(winningProjectId > 0, "No winning project found");

        // Calculate prize distribution
        uint256 totalPrize = round.totalBets;
        uint256 projectFunding = totalPrize / 3; // 1/3 to the winning project
        uint256 betterRewards = totalPrize - projectFunding; // 2/3 to the correct predictors

        // Distribute funds to winning project
        fundingPool.authorizeFunds(
            address(uint160(winningProjectId)),
            address(bettingToken),
            projectFunding
        );

        // Distribute remaining funds to correct predictors
        address[] memory winners = commitmentSchema.getWinners(
            winningProjectId
        );

        uint256 rewardPerBet = betterRewards /
            round.projects[winningProjectId].totalBets;

        for (uint i = 0; i < winners.length; i++) {
            address winner = winners[i];
            (
                uint256 projectId,
                uint256 amount,
                bool revealed
            ) = commitmentSchema.getRevealedBet(winner);

            if (projectId == winningProjectId) {
                uint256 reward = amount * rewardPerBet;
                require(
                    bettingToken.transfer(winner, reward),
                    "Transfer to winner failed"
                );
                soulboundReputation.mint(winner, 1);
            }
        }

        // Reset round data
        delete rounds[_roundId];
    }
}
