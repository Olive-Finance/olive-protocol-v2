// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IRateCalculator} from '../interfaces/IRateCalculator.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {Allowed} from '../interfaces/Allowed.sol';

import "hardhat/console.sol";

contract RateCalculator is IRateCalculator, Allowed {
    using SafeMath for uint256;
    
    // Slopes for each of the interests
    uint256 public _r0;
    uint256 public _r1;
    uint256 public _r2;

    // Optimal utilization
    uint256 public _uo; 

    // constant do define the year in seconds
    uint256 constant YEAR_IN_SECONDS = 365 days;

    // precision defined in
    uint256 constant PINT = 1e12;

    constructor(uint256 r0, uint256 r1, uint256 r2, uint256 uo) Allowed(msg.sender) {
        _r0 = r0;
        _r1 = r1;
        _r2 = r2;
        _uo = uo;
    }

    // Restrictred setter functions
    function setSlopes(uint256 r0, uint256 r1, uint256 r2) public onlyAllowed returns (bool) {
        _r0 = r0;
        _r1 = r1;
        _r2 = r2;
        return true;
    }

    function setUOpt(uint256 uo) public onlyAllowed returns (bool) {
        _uo = uo;
        return true;
    }

    // Borrow rate * utilization
    function calculateSupplyRate(uint256 _borrowRate, uint256 _u) external view returns (uint256) {
        console.log("I am called by :", msg.sender);
        return _borrowRate.mul(_u).div(PINT);
    }

    // Borrow based on the slope
    function calculateBorrowRate(uint256 _u) external view returns (uint256) {
        // Interest is a split function
        // Rv = R0 + U/UO * R1
        // Rv = R0 + R1 + (U-UO)/(1-UO) * R2
        uint256 first = _u.mul(_r1).div(_uo);

        if (_u <= _uo) {
            return first.add(_r1);
        }

        uint256 second = _u.sub(_uo);
        console.log(second);
        second = second.mul(_r2);
        second = second.div(PINT.sub(_uo));

        return  second.add(_r1).add(_r2);
    }

    function calculateSimpleInterest(uint256 _rate, uint256 _timeFrom, uint256 _timeTo) external pure returns (uint256) {
        require(_timeTo >= _timeFrom, "RCL: Invalid input data");

        uint256 timeDiff = _timeTo.sub(_timeFrom);
        timeDiff = timeDiff.mul(PINT);
        timeDiff = timeDiff.div(YEAR_IN_SECONDS);

        uint256 first = timeDiff.mul(_rate);
        first = first.div(PINT);
        first = first.add(PINT);

        return first;
    }

    function calculateCompoundInterest(uint256 _rate, uint256 _timeFrom, uint256 _timeTo) external pure returns (uint256) {
        uint256 exp = _timeTo.sub(uint256(_timeFrom));

        if (exp == 0) {
            return PINT;
        }

        uint256 expMinusOne = exp - 1;
        uint256 expMinusTwo = exp > 2 ? exp - 2 : 0;
        uint256 ratePerSecond = _rate / YEAR_IN_SECONDS;

        uint256 basePowerTwo = ratePerSecond.mul(ratePerSecond).div(PINT);
        uint256 basePowerThree = basePowerTwo.mul(ratePerSecond).div(PINT);

        uint256 secondTerm = exp.mul(expMinusOne).mul(basePowerTwo) / 2;
        uint256 thirdTerm = exp.mul(expMinusOne).mul(expMinusTwo).mul(basePowerThree) / 6;

        return PINT.add(ratePerSecond.mul(exp)).add(secondTerm).add(thirdTerm);
    }
}