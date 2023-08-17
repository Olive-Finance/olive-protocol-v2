// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IRewardManager {
    function refreshReward(address user) external;

    function notifyRewardAmount(uint256) external;
}