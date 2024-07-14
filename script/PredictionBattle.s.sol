// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PredictionBattle} from "../src/PredictionBattle.sol";
import {SoulboundReputation} from "../src/SoulboundReputation.sol";
import {CommitmentSchema} from "../src/CommitmentSchema.sol";
import {FundingPool} from "../src/FundingPool.sol";
import {MockERC20Token} from "../src/mock/MockERC20Token.sol";

contract PredictionBattleScript is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        MockERC20Token bettingToken = new MockERC20Token("Betting Token", "BET");
        SoulboundReputation soulboundReputation = new SoulboundReputation("Reputation", "REP");
        CommitmentSchema commitmentSchema = new CommitmentSchema();
        FundingPool fundingPool = new FundingPool();
        
        PredictionBattle predictionBattle = new PredictionBattle(
            address(bettingToken),
            address(soulboundReputation),
            address(commitmentSchema),
            address(fundingPool)
        );

        address admin = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        predictionBattle.grantRole(predictionBattle.ADMIN_ROLE(), admin);
        predictionBattle.grantRole(predictionBattle.SPONSOR_ROLE(), admin);
        fundingPool.grantRole(fundingPool.SPONSOR_ROLE(), admin);
        fundingPool.grantRole(fundingPool.AUTHORIZER_ROLE(), address(predictionBattle));
        
        soulboundReputation.transferOwnership(address(predictionBattle));
        bettingToken.mint(admin, 1000 ether);

        vm.stopBroadcast();
    }
}
