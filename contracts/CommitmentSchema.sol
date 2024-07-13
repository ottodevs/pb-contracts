// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CommitmentSchema {
    struct Commitment {
        bytes32 commitmentHash;
        bool revealed;
        uint256 projectId;
        uint256 amount;
    }

    mapping(address => Commitment) public commitments;
    mapping(uint256 => address[]) public projectBetters;

    function submitCommitment(address _better, bytes32 _commitment) external {
        require(
            commitments[_better].commitmentHash == bytes32(0),
            "Commitment already exists"
        );
        commitments[_better] = Commitment(_commitment, false, 0, 0);
    }

    function revealBet(
        address _better,
        uint256 _projectId,
        uint256 _amount,
        uint256 _nonce
    ) external {
        Commitment storage commitment = commitments[_better];
        require(!commitment.revealed, "Bet already revealed");
        require(
            commitment.commitmentHash ==
                keccak256(abi.encodePacked(_projectId, _amount, _nonce)),
            "Invalid revelation"
        );

        commitment.revealed = true;
        commitment.projectId = _projectId;
        commitment.amount = _amount;
        projectBetters[_projectId].push(_better);
    }

    function getWinners(
        uint256 _winningProjectId
    ) external view returns (address[] memory) {
        return projectBetters[_winningProjectId];
    }
}
