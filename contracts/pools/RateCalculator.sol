// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IRateCalculator} from './interfaces/IRateCalculator.sol';
import {Constants} from '../lib/Constants.sol';
import {Governable} from "../utils/Governable.sol";

contract RateCalculator is IRateCalculator, Governable {
    
    // Slopes for each of the interests
    uint256 public _r0;
    uint256 public _r1;
    uint256 public _r2;

    // Optimal utilization
    uint256 public _uo; 

    // constant do define the year in seconds
    uint256 constant YEAR_IN_SECONDS = 365 days;

    constructor(uint256 r0, uint256 r1, uint256 r2, uint256 uo) Governable(msg.sender) {
        _r0 = r0;
        _r1 = r1;
        _r2 = r2;
        _uo = uo;
    }

    // Restrictred setter functions
    function setSlopes(uint256 r0, uint256 r1, uint256 r2) public onlyGov returns (bool) {
        _r0 = r0;
        _r1 = r1;
        _r2 = r2;
        return true;
    }

    function setUOpt(uint256 uo) public onlyGov returns (bool) {
        _uo = uo;
        return true;
    }

    // Borrow rate * utilization
    function supplyRate(uint256 _u) external view returns (uint256) {
        return (this.borrowRate(_u) * _u) / Constants.PINT;
    }

    // Borrow based on the slope
    function borrowRate(uint256 _u) external view returns (uint256) {
        // Interest is a split function
        // Rv = R0 + U/UO * R1
        // Rv = R0 + R1 + (U-UO)/(1-UO) * R2
        uint256 first = (_u * _r1) / _uo;
        if (_u <= _uo) {
            return first + _r0;
        }
        uint256 second = ((_u - _uo) * _r2) / (Constants.PINT - _uo);
        return  (_r0 + _r1 + second);
    }

    function simpleInterest(uint256 _rate, uint256 _timeFrom, uint256 _timeTo) external pure returns (uint256) {
        require(_timeTo >= _timeFrom, "RCL: Invalid input data");
        uint256 result = ((_timeTo - _timeFrom) * Constants.PINT) / YEAR_IN_SECONDS;
        result = Constants.PINT + ((result * _rate) / Constants.PINT);
        return result;
    }

    function compoundInterest(uint256 _rate, uint256 _timeFrom, uint256 _timeTo) external view returns (uint256) {
        require(_timeTo >= _timeFrom, "RCL: Invalid input data");
        uint256 exp = _timeTo - _timeFrom;

        if (exp == 0) {
            return Constants.PINT;
        }

        uint256 expMinusOne = exp - 1;
        uint256 expMinusTwo = exp > 2 ? exp - 2 : 0;
        uint256 ratePerSecond = _rate / YEAR_IN_SECONDS;

        uint256 basePowerTwo = (ratePerSecond * ratePerSecond);
        uint256 basePowerThree = (basePowerTwo * ratePerSecond);
        uint256 secondTerm = (exp * expMinusOne * basePowerTwo) / 2;
        uint256 thirdTerm = (exp * expMinusOne * expMinusTwo * basePowerThree)  / (6 * Constants.PINT);
        return Constants.PINT + (ratePerSecond * exp) + (secondTerm + thirdTerm) / Constants.PINT;
    }
}