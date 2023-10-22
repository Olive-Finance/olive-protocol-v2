// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IBoost {
    function getUserBoost(address user, uint256 userUpdatedAt, uint256 finishAt) external view returns (uint256);

    function getUnlockTime(address user) external view returns (uint256 unlockTime);
}