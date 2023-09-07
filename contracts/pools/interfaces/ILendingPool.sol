// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface ILendingPool {
    // State functions
    function supply(uint256 _amount) external returns (bool);
    function withdraw(uint256 _shares) external returns (bool);
    function borrow(address _to, address _user, uint256 _amount) external returns (uint256);
    function repay(address _from, address _user, uint256 _amount) external returns (bool);
    function repayWithSettle(address _from, address _user, uint256 _amount) external returns (bool);

    // View functions
    function borrowRate() external view returns (uint256);
    function supplyRate() external view returns (uint256);    
    function utilization() external view returns (uint256);
    function debtToken() external view returns (address);
    function wantToken() external view returns (address);
    function getDebt(address _user) external view returns (uint256);
    function getBalance(address _user) external view returns (uint256);

    //events
    event Fund(address _caller, address indexed _depositor, uint256 _amount);
    event Withdraw(address _caller, address indexed _user, uint256 _amount);
    event Borrow(address _caller, address _to, address indexed _user, uint256 _amount);
    event Repay(address _caller, address _user, uint256 _amount);
}