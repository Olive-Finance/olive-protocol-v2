// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IStagragator{

    function getStrategyForDeposit() external;

    function getStrategyForWithdrawal() external;

    function addStrategy() external;

    function setCashier() external;
}