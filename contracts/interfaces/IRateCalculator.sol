// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IRateCalculator {
    function calculateSupplyRate(uint256 _borrowRate, uint256 _u) external view returns (uint256);

    function calculateBorrowRate(uint256 _u) external view returns (uint256);

    function calculateSimpleInterest(uint256 _rate, uint256 _timeFrom, uint256 _timeTo) external view returns (uint256);

    function calculateCompoundInterest(uint256 _rate, uint256 _timeFrom, uint256 _timeTo) external view returns (uint256);
}