// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

interface IRateCalculator {
    function supplyRate(uint256 _u) external view returns (uint256);

    function borrowRate(uint256 _u) external view returns (uint256);

    function simpleInterest(uint256 _rate, uint256 _timeFrom, uint256 _timeTo) external view returns (uint256);

    function compoundInterest(uint256 _rate, uint256 _timeFrom, uint256 _timeTo) external view returns (uint256);
}