// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

interface ILendingPool {
    // State functions
    function fund(address _user, uint256 _amount) external returns (bool);

    function withdraw(address _user, uint256 _amount) external returns (bool);

    function borrow(address _toAccount, address _user, uint256 _amount) external returns (uint256);

    function repay(address _fromAccount, address _user, uint256 _amount) external returns (bool);

    // View functions
    function borrowRate() external view returns (uint256);

    function supplyRate() external view returns (uint256);    

    function utilization() external view returns (uint256);

    function debtToken() external view returns (address);

    function wantToken() external view returns (address);

    function  getDebtInWant(address _user) external view returns (uint256);

    function maxAllowedAmount() external view returns (uint256);
}