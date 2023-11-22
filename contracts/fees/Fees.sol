// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IFees} from './interfaces/IFees.sol';

import {Allowed} from '../utils/Allowed.sol';
import {Governable} from '../utils/Governable.sol';

import {Constants} from '../lib/Constants.sol';


contract Fees is IFees, Allowed, Governable {
    //treasury
    address public treasury;

    // percentages
    uint256 public pFee;
    uint256 public mFee;
    uint256 public liquidationFee;
    uint256 public liquidatorFee;

    uint256 public lastUpdatedAt;
    uint256 public accumulatedFee;

    uint256 public rewardRateforOliveholders;
    uint256 public yieldFeeLimit;

    uint256 public withdrawalFee;

    // user level fees
    uint256 public userMFee; 
    mapping(address => uint256) public userFees;
    mapping(address => uint256) public userFeeUpdatedAt;


    // Empty constructor
    constructor() Allowed(msg.sender) Governable(msg.sender) {
        pFee = Constants.PerformanceFee;
        mFee = Constants.ManagementFee;
        liquidationFee = Constants.LiquidationFee;
        liquidatorFee = Constants.LiquidatorFee;
        rewardRateforOliveholders = Constants.RewardToOLVHolders;
        yieldFeeLimit = Constants.YieldFeeLimit;
        withdrawalFee = Constants.WithdrawalFee;
        userMFee = Constants.UserManagementFee;
    }

    function getPFee() external view override returns (uint256) { 
        return pFee; 
    }

    function getMFee() external view override returns (uint256) { 
        return mFee;
    }

    function getTreasury() external view override returns (address) {
        return treasury;
    }

    function getLiquidationFee() external view override returns (uint256) {
        return liquidationFee;
    }

    function getLiquidatorFee() external view override returns (uint256) {
        return liquidatorFee;
    }

    function getAccumulatedFee() external view override returns (uint256) {
        return accumulatedFee;
    }

    function getLastUpdatedAt() external view override returns (uint256) {
        return lastUpdatedAt;
    }

    function getLiquidationTreasuryFee() external view override returns (uint256) {
        return (Constants.HUNDRED_PERCENT - liquidatorFee);
    }

    function getRewardRateForOliveHolders() external view override returns (uint256) {
        return rewardRateforOliveholders;
    }

    function getYieldFeeLimit() external view override returns (uint256) {
        return yieldFeeLimit;
    }

    function getWithdrawalFee() external view override returns (uint256) {
        return withdrawalFee;
    }

    function getAccumulatedFeeForUser(address _user) external view override returns (uint256, uint256) {
        return (userFees[_user], userFeeUpdatedAt[_user]);
    }

    function getUserMFee() external view override returns (uint256) {
        return userMFee;
    }

    function setTreasury(address _treasury) external override onlyOwner {
        require(_treasury != address(0), "FEE: Invalid treasury address");
        treasury = _treasury;
    }

    function setPFee(uint256 _pFee) external override onlyGov {
        require(_pFee <= Constants.MAX_PERFORMANCE_FEE, "FEE: Invalid perfromance fee");
        pFee = _pFee;
    }

    function setMFee(uint256 _mFee) external override onlyGov {
        require(_mFee <= Constants.MAX_MANAGEMENT_FEE, "FEE: Invalid management fee");
        mFee = _mFee;
    }

    function setUserMFee(uint256 _umFee) external override onlyGov {
        require(_umFee <= Constants.MAX_MANAGEMENT_FEE, "FEE: Invalid management fee");
        userMFee = _umFee;
    }

    function setLiquidationFee(uint256 _liquidationFee) external override onlyGov {
        require(Constants.MAX_LIQUIDATION_FEE >= _liquidationFee, "FEE: Invalid liquidation fee");
        liquidationFee = _liquidationFee;
    }

    function setLiquidatorFee(uint256 _liquidatorFee) external override onlyGov {
        require(Constants.HUNDRED_PERCENT >= _liquidatorFee, "FEE: Invalid liquidator fee");
        liquidatorFee = _liquidatorFee;
    }

    function setFee(uint256 _fee, uint256 _updatedAt) external override onlyAllowed {
        require(lastUpdatedAt <= _updatedAt, "FEE: Backdated entry");
        accumulatedFee = _fee;
        lastUpdatedAt = _updatedAt;
    }

    function setRewardRateForOliveHolders(uint256 _rewardRate) external override onlyGov {
        require(Constants.MAX_REWARD_RATE_FOR_OLIVE_HOLDERS >= _rewardRate , "FEE: Invalid olive reward rate");
        rewardRateforOliveholders = _rewardRate;
    }

    function setYieldFeeLimit(uint256 _yieldFeeLimit) external override onlyGov {
        require(Constants.YIELD_LIMIT_FOR_FEES >= _yieldFeeLimit, "FEE: Invalid limit");
        yieldFeeLimit = _yieldFeeLimit;
    }

    function setFeeForUser(address _user, uint256 _fee, uint256 _updatedAt) external override onlyAllowed {
        userFees[_user] = _fee;
        userFeeUpdatedAt[_user] = _updatedAt;
    }

    function setWithdrawalFee(uint256 _withdrawalFee) external override onlyGov {
        require(Constants.MAX_WITHDRAWAL_FEE >= _withdrawalFee, "FEE: Invalid withdrawal fee");
        withdrawalFee = _withdrawalFee;
    }
}