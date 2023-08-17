// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IStrategy {
    function deposit(address _user, uint256 _amount) external;

    function withdraw(address _user, uint256 _shares) external returns (uint256);

    function harvest() external;

    function balance() external view returns (uint256);

    function balanceOf(address _user) external view returns (uint256);

    function setHandler(address _user, address _handler, bool _enabled) external ;

    event HandlerChanged(address indexed _user, address indexed _handler, bool indexed _enabled);
}