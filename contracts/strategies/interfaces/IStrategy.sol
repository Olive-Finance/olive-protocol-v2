// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

interface IStrategy {
    function deposit(address _user, uint256 _amount) external;

    function withdraw(address _user, uint256 _amount) external returns (uint256);

    function harvest() external;

    function balance() external view returns (uint256);

    function balanceOf(address _user) external view returns (uint256);
}