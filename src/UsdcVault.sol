// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ComptrollerG7 as Comptroller} from "compound-protocol/contracts/ComptrollerG7.sol";
import "compound-protocol/contracts/CErc20.sol";

contract UsdcVault is ERC20, ReentrancyGuard, Ownable {
    /**
     * @notice State variables
     */
    ERC20 public immutable asset;
    CErc20 public immutable cAsset;
    ERC20 public immutable rewardsToken;
    Comptroller private comptroller;
    mapping(address => uint256) public shareHolders;

    /**
     * @notice Events
     */
    event Deposit(address caller, uint256 amount);

    event Withdraw(address caller, uint256 amount);

    event ExchangeRate(uint256 exchangeRateMantissa);

    /**
     * @notice Errors
     */
    error AmountBelowOrEqualZero();

    error NotEnoughShares();

    error AllowanceNotMet();

    /**
     * @notice Constructor
     */
    constructor(
        ERC20 _underlying,
        CErc20 _cAsset,
        ERC20 _rewardsToken,
        Comptroller _comptroller,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        asset = _underlying;
        cAsset = _cAsset;
        rewardsToken = _rewardsToken;
        comptroller = _comptroller;
    }

    /**
     * @notice Functions
     */
    function deposit(uint256 amount) public nonReentrant {
        if (amount <= 0) revert AmountBelowOrEqualZero();

        uint256 allowance = asset.allowance(msg.sender, address(this));
        if (allowance < amount) revert AllowanceNotMet();

        asset.transferFrom(msg.sender, address(this), amount);

        uint256 exchangeRate = cAsset.exchangeRateCurrent();
        uint256 sharesToIssue = ((amount * 1e18) / (exchangeRate));

        asset.approve(address(cAsset), amount);
        assert(cAsset.mint(amount) == 0);

        shareHolders[msg.sender] += sharesToIssue;
        _mint(msg.sender, sharesToIssue);

        emit Deposit(msg.sender, sharesToIssue);
    }

    function redeem(
        uint256 shares,
        address receiver
    ) internal returns (uint256 assets) {
        if (shares <= 0) revert AmountBelowOrEqualZero();
        if (shares > shareHolders[msg.sender]) revert NotEnoughShares();

        shareHolders[msg.sender] -= shares;
        _burn(msg.sender, shares);

        assert(cAsset.redeem(shares) == 0);
        uint256 exchangeRateMantissa = cAsset.exchangeRateCurrent();
        uint256 assetsToReturn = (shares * exchangeRateMantissa) / 1e18;

        emit Withdraw(receiver, assetsToReturn);
        return assetsToReturn;
    }

    function withdraw(uint256 shares) public nonReentrant {
        uint256 payout = redeem(shares, msg.sender);
        asset.transfer(msg.sender, payout);
    }

    function withdrawRewards() public onlyOwner {
        comptroller.claimComp(address(this));
        uint256 rewards = rewardsToken.balanceOf(address(this));
        rewardsToken.transfer(msg.sender, rewards);
    }
}
