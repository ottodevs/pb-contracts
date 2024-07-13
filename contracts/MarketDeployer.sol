// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PredictionBattle.sol";

contract MarketDeployer {
    function deployPredictionBattle(
        address _nounsToken,
        address _apeCoinToken,
        address _reputationToken,
        address _commitmentSchema,
        uint256 _wageDeadline,
        uint256 _resolutionDate
    ) external returns (address) {
        PredictionBattle newMarket = new PredictionBattle(
            _nounsToken,
            _apeCoinToken,
            _reputationToken,
            _commitmentSchema,
            _wageDeadline,
            _resolutionDate
        );
        return address(newMarket);
    }
}
