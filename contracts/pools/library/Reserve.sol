// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IRateCalculator} from './../interfaces/IRateCalculator.sol';
import {Constants} from '../../lib/Constants.sol';

library Reserve {
    struct ReserveData {
        // supply index for scaled balance of supply tokens
        uint256 _supplyIndex;

        // borrow index for scaling the debt tokens
        uint256 _borrowIndex;

        // supply rate for lenders
        uint256 _supplyRate;

        // borrow rate for borrowers
        uint256 _borrowRate;

        // last updated timestamp 
        uint256 _lastUpdatedTimestamp;

        // Address for aToken
        IERC20 _aToken;

        // Address for debtToken
        IERC20 _dToken;    

        // Want address
        IERC20 _want;

        // Interest address strategy
        IRateCalculator _rcl;

        // pool address
        address _pool; //todo do we need this information
    }

    function init(ReserveData storage reserve, address aToken, address dToken, address want, address rcl, address pool) internal {
        require(aToken != address(0), "RSV: aToken can't be null address");
        require(dToken != address(0), "RSV: dToken can't be null address");
        require(want != address(0), "RSV: want can't be null address");
        require(rcl != address(0), "RSV: Rate Calculator can't be null address");
        require(pool != address(0), "RSV: Pool address can't be null address");

        reserve._supplyIndex = Constants.PINT;
        reserve._borrowIndex = Constants.PINT;

        reserve._aToken = IERC20(aToken);
        reserve._dToken = IERC20(dToken);
        reserve._want = IERC20(want);
        reserve._rcl = IRateCalculator(rcl);

        reserve._pool = pool;

        reserve._lastUpdatedTimestamp = block.timestamp;
    }

    /**
     * Update the state which is the supply and borrow indices
     */
    function updateState(ReserveData storage reserve) internal {
        uint256 currentTimestamp = block.timestamp;
        IRateCalculator rcl = reserve._rcl;
        uint256 reserveLastUpdated = reserve._lastUpdatedTimestamp;

        // update liquidity index
        uint256 si = rcl.simpleInterest(reserve._supplyRate, uint256(reserveLastUpdated), currentTimestamp);
        reserve._supplyIndex = (si * reserve._supplyIndex) / Constants.PINT;

        
        // update borrow index
        uint256 totalDebt = reserve._dToken.totalSupply();
        if( totalDebt > 0) { // Don't have to compute borrow index as there is no borrow
            uint256 ci = rcl.compoundInterest(reserve._borrowRate, reserveLastUpdated, currentTimestamp);
            reserve._borrowIndex = (ci * reserve._borrowIndex) / Constants.PINT;
        }

        // update timestamp
        reserve._lastUpdatedTimestamp = uint40(currentTimestamp);
    }

    function getNormalizedIncome(ReserveData storage reserve) internal view returns (uint256) {
        uint256 reserveTimestamp = reserve._lastUpdatedTimestamp;
        uint256 supplyIndex = reserve._supplyIndex;
        if (reserveTimestamp == block.timestamp) {
            return supplyIndex;
        }
        IRateCalculator rcl = reserve._rcl;
        uint256 si = rcl.simpleInterest(reserve._supplyRate, reserveTimestamp, block.timestamp);
        supplyIndex = (si * supplyIndex) / Constants.PINT;
        return supplyIndex;
    }

    function getNormalizedDebt(ReserveData storage reserve) internal view returns (uint256) {
        uint256 reserveTimestamp = reserve._lastUpdatedTimestamp;
        uint256 borrowIndex = reserve._borrowIndex;
        if (reserveTimestamp == block.timestamp) {
            return borrowIndex;
        }
        IRateCalculator rcl = reserve._rcl;
        uint256 ci = rcl.compoundInterest(reserve._borrowRate, reserveTimestamp, block.timestamp);
        borrowIndex = (ci * borrowIndex) / Constants.PINT;
        return borrowIndex;
    }

    function updateRates(ReserveData storage reserve, 
        uint256 totalBorrwedDebt,
        uint256 totalliquidity,
        uint256 supply,
        uint256 withdraw,
        uint256 borrow,
        uint256 repay
    ) internal {
        uint256 debt = totalBorrwedDebt + borrow - repay;
        uint256 liquidity = totalliquidity + supply - withdraw;
        uint256 utilization = 0;
        if (debt!=0) {
            utilization = (debt * Constants.PINT) / (liquidity + debt);
        }
        reserve._borrowRate = reserve._rcl.borrowRate(utilization);
        reserve._supplyRate = reserve._rcl.supplyRate(utilization);
    }
}