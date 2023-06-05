// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ILendingPool {

    function borrow(address _toAccount, address _user, uint256 _amount) external returns (uint256);

    function fund(address _user, uint256 _amount) external returns (bool);

    function withdraw(address _user, uint256 _amount) external returns (bool);

    function interestRate() external view returns (uint256);

    function repay(address _fromAccount, address _user, uint256 _amount) external returns (bool);

    function utilization() external view returns (uint256);

    function debtToken() external view returns (address);

    function wantToken() external view returns (address);

    function maxAllowedAmount() external view returns (uint256);
}