// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBoost} from "./interface/IBoost.sol";
import {Allowed} from "../utils/Allowed.sol";
import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {IMintable} from "../interfaces/IMintable.sol";

import {Constants} from "../lib/Constants.sol";

contract StakingRewards is Allowed {
    // Tokens
    IERC20 public immutable stakingToken; 
    IMintable public immutable rewardsToken;

    // Contract leve public addresses
    IBoost public boost;
    IRewardManager public oliveMgr;

    // Duration of rewards to be paid out (in seconds)
    uint256 public duration = Constants.REWARDS_PAYOUT_PERIOD;

    // Vault level variables
    uint256 public finishAt;
    uint256 public updatedAt;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;

    // user level variables
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userUpdatedAt;

    // Total staked
    uint256 public totalSupply;
    // User address => staked amount
    mapping(address => uint256) public balanceOf;

    constructor(
        address _stakingToken,
        address _rewardToken,
        address _boost,
        address _oliveMgr
    ) Allowed(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IMintable(_rewardToken);
        boost = IBoost(_boost);
        oliveMgr = IRewardManager(_oliveMgr);
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
            userUpdatedAt[_account] = block.timestamp;
        }
        _;
    }

    function setBoost(address _boost) external onlyOwner {
        require(_boost != address(0), "STKR: Invalid boost");
        boost = IBoost(_boost);
    }

    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(_duration > 1 days && finishAt < block.timestamp, "STKR: reward duration not finished");
        duration = _duration;
    }

    function setMetaManager(address _oliveMgr) external onlyOwner {
        require(_oliveMgr != address(0), "STKR: Invalid olive manager");
        oliveMgr = IRewardManager(_oliveMgr);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * Constants.PINT) /
            totalSupply;
    }

    function stake(uint256 _amount) external updateReward(msg.sender) {
        address caller = msg.sender;
        require(_amount > 0, "STKR: Invalid amount");
        stakingToken.transferFrom(caller, address(this), _amount);
        balanceOf[caller] += _amount;
        totalSupply += _amount;
    }

    function withdraw(uint256 _amount) external updateReward(msg.sender) {
        address caller = msg.sender;
        require(
            block.timestamp >= boost.getUnlockTime(caller),
            "Your lock-in period has not ended. You can't claim your LP Token now."
        );
        require(_amount > 0, "STKR: Invalid amount");
        balanceOf[caller] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(caller, _amount);
    }

    function getBoost(address _account) public view returns (uint256) {
        return
            100 * Constants.PINT +
            boost.getUserBoost(
                _account,
                userUpdatedAt[_account],
                finishAt
            );
    }

    function earned(address _account) public view returns (uint256) {
        return
            ((balanceOf[_account] *
                getBoost(_account) *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e38) +
            rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        address caller = msg.sender;
        require(
            block.timestamp >= boost.getUnlockTime(caller),
            "Your lock-in period has not ended. You can't claim your esMETA now."
        );
        uint256 reward = rewards[caller];
        if (reward > 0) {
            rewards[caller] = 0;
            oliveMgr.refreshReward(caller);
            rewardsToken.mint(caller, reward);
        }
    }

    // Function to refresh the rewards, not other actions to be performed
    function refreshReward(address _account) external updateReward(_account) {}
    
    // Allows the owner to set the mining rewards.
    function notifyRewardAmount(uint256 _amount) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint256 remainingRewards = (finishAt - block.timestamp) *
                rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}
