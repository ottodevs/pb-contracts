// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PredictionBattle.sol";

contract MarketDeployer {
    function deployPredictionBattle(
        address _bettingToken,
        address _soulboundReputation,
        address _commitmentSchema,
        address _fundingPool
    ) external returns (address) {
        PredictionBattle newMarket = new PredictionBattle(
            address(_bettingToken),
            address(_soulboundReputation),
            address(_commitmentSchema),
            address(_fundingPool)
        );
        return address(newMarket);
    }
}
