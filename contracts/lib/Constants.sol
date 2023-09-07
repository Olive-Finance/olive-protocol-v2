// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

library Constants {
    // Base constants
    uint256 constant PINT = 1e18;
    uint256 constant ZERO = 0;
    uint256 constant MAX_INT = type(uint256).max;
    uint256 constant HUNDRED_PERCENT = 100e18; //100

    // Thresholds
    uint256 constant LIQUIDATION_THRESHOLD = 0.9e18;
    uint256 constant LIQUIDATION_THRESHOLD_LIMIT = 0.5e18;

    // Leverage
    uint256 constant MAX_LEVERAGE_LIMIT = 10e18;

    // Limits 
    uint256 constant MAX_PERFORMANCE_FEE = 20e18; 
    uint256 constant MAX_MANAGEMENT_FEE = 5e18;

    uint256 constant MAX_LIQUIDATION_FEE = 10e18; //10% 
    uint256 constant MAX_LIQUIDATOR_FEE = 50e18; //50% of Liquidation fee

    uint256 constant MAX_REWARD_RATE_FOR_OLIVE_HOLDERS = 100e18; //100% of total performance fee

    uint256 constant YIELD_LIMIT_FOR_FEES = 50e18; //% of yield which can be used for fees

    // Supply constants
    uint256 constant OLIVE_MAX_SUPPLY = 1000_000_000 * 1e18;
    uint256 constant ESOLIVE_MAX_EMISSION = 400_000_000 * 1e18;

    // Constants for Meta Manager & Time periods
    uint256 constant YEAR_IN_SECONDS = 365 days;
    uint256 constant VESTING_PERIOD = 60 days;
    uint256 constant REWARDS_PAYOUT_PERIOD = 30 days;
    uint256 constant ONE_DAY = 1 days;

    uint256 constant TEN_DAYS = 10 days;
    uint256 constant SIXTY_DAYS = 60 days;

    // Numerical constant/s
    uint256 constant HUNDERED = 100;

    // Boost constants
    // LOCK-IN Settings
    uint256 constant SETTING_1_LOCK_PERIOD = 30 days;
    uint256 constant SETTING_2_LOCK_PERIOD = 90 days;
    uint256 constant SETTING_3_LOCK_PERIOD = 180 days;
    uint256 constant SETTING_4_LOCK_PERIOD = 365 days;

    // Reward boost
    uint256 constant SETTING_1_BOOST = 20e18; // 20%
    uint256 constant SETTING_2_BOOST = 30e18; // 30%
    uint256 constant SETTING_3_BOOST = 50e18; // 50%
    uint256 constant SETTING_4_BOOST = 100e18; // 100%

    // Magic number definition
    uint256 constant FIFTY_DAYS = 50;

    // Default fee values
    uint256 constant ManagementFee = 2e18; // 2% 
    uint256 constant PerformanceFee = 10e18; // 10%
    uint256 constant LiquidationFee = 5e18; // 5%
    uint256 constant LiquidatorFee = 80e18; // 80%
    uint256 constant RewardToOLVHolders = 20e18; //20% 
    uint256 constant YieldFeeLimit = 30e18; // 30%
}
