// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FundingPool is AccessControl {
    bytes32 public constant AUTHORIZER_ROLE = keccak256("AUTHORIZER_ROLE");

    IERC20 public nounsToken;
    IERC20 public apeCoinToken;

    mapping(address => mapping(address => uint256)) public authorizedClaims;

    event FundsAuthorized(
        address indexed project,
        address indexed token,
        uint256 amount
    );
    event FundsClaimed(
        address indexed project,
        address indexed token,
        uint256 amount
    );

    constructor(address _nounsToken, address _apeCoinToken) {
        nounsToken = IERC20(_nounsToken);
        apeCoinToken = IERC20(_apeCoinToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(AUTHORIZER_ROLE, msg.sender);
    }

    function authorizeFunds(
        address project,
        address token,
        uint256 amount
    ) external onlyRole(AUTHORIZER_ROLE) {
        require(
            token == address(nounsToken) || token == address(apeCoinToken),
            "Invalid token"
        );
        authorizedClaims[project][token] += amount;
        emit FundsAuthorized(project, token, amount);
    }

    function claimFunds(address token) external {
        uint256 amount = authorizedClaims[msg.sender][token];
        require(amount > 0, "No funds to claim");

        authorizedClaims[msg.sender][token] = 0;

        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");

        emit FundsClaimed(msg.sender, token, amount);
    }
}
