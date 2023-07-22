// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;


interface IPriceHelper {
    // Price of a token in USD
    function getPriceOf(address _token) external view returns (uint256);

    // proce of reward token in USD
    function getPriceOfRewardToken() external view returns (uint256);
}