// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FundingPool is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant AUTHORIZER_ROLE = keccak256("AUTHORIZER_ROLE");
    bytes32 public constant SPONSOR_ROLE = keccak256("SPONSOR_ROLE");

    mapping(address => uint256) public tokenBalances;
    mapping(address => mapping(address => uint256)) public authorizedClaims;

    event FundsDeposited(
        address indexed sponsor,
        address indexed token,
        uint256 amount
    );
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

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUTHORIZER_ROLE, msg.sender);
    }

    function depositFunds(
        address token,
        uint256 amount
    ) external onlyRole(SPONSOR_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        tokenBalances[token] += amount;
        emit FundsDeposited(msg.sender, token, amount);
    }

    function authorizeFunds(
        address project,
        address token,
        uint256 amount
    ) external onlyRole(AUTHORIZER_ROLE) {
        require(tokenBalances[token] >= amount, "Insufficient funds in pool");
        authorizedClaims[project][token] += amount;
        tokenBalances[token] -= amount;
        emit FundsAuthorized(project, token, amount);
    }

    function claimFunds(address token) external {
        uint256 amount = authorizedClaims[msg.sender][token];
        require(amount > 0, "No funds to claim");

        authorizedClaims[msg.sender][token] = 0;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit FundsClaimed(msg.sender, token, amount);
    }

    function getTokenBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }

    // Function to allow withdrawal of excess funds by admin
    function withdrawExcessFunds(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenBalances[token] >= amount, "Insufficient funds");
        tokenBalances[token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
