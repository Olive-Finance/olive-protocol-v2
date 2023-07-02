// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IRateCalculator} from './../interfaces/IRateCalculator.sol';
import {Constants} from '../../lib/Constants.sol';

import 'hardhat/console.sol';

library Reserve {
    struct ReserveData {
        // supply index for scaled balance of supply tokens
        uint256 _supplyIndex;

        // borrow index for scaling the debt tokens
        uint256 _borrowIndex;

        // supply rate for lenders
        uint256 _currentSupplyRate;

        // borrow rate for borrowers
        uint256 _currentBorrowRate;

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
        uint256 prevSupplyIndex = reserve._supplyIndex;
        console.log("prevSupplyIndex: ", prevSupplyIndex);
        uint256 supplyRate = reserve._currentSupplyRate;
        console.log("supplyRate: ", supplyRate);
        uint256 supplyIndex = rcl.simpleInterest(supplyRate, uint256(reserveLastUpdated), currentTimestamp);
        reserve._supplyIndex = (supplyIndex * prevSupplyIndex)/Constants.PINT;
        console.log("SupplyIndex: ", supplyIndex);
        
        
        // update borrow index
        uint256 prevBorrowIndex = reserve._borrowIndex;
        console.log("prevBorrowIndex: ", prevBorrowIndex);
        console.log(address(reserve._dToken));
        console.log("Total debt tokens:", reserve._dToken.totalSupply());
        IERC20 debtToken = reserve._dToken;
        uint256 totalDebt = debtToken.totalSupply();
        console.log("Total debt tokens:", totalDebt / 1e8);
        if( totalDebt > 0) { // Don't have to compute borrow index as there is no borrow
            console.log("I am inside to compute the borrow");
            uint256 borrowRate = reserve._currentBorrowRate;
            uint256 borrowIndex = rcl.compoundInterest(borrowRate, reserveLastUpdated, currentTimestamp);
            reserve._borrowIndex = (borrowIndex * prevBorrowIndex) / Constants.PINT;
            console.log("BorrowIndex:", borrowIndex);
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
        uint256 increment = rcl.simpleInterest(supplyIndex, reserveTimestamp, block.timestamp);
        supplyIndex = (increment * supplyIndex) / Constants.PINT;
        return supplyIndex;
    }

    function getNormalizedDebt(ReserveData storage reserve) internal view returns (uint256) {
        uint256 reserveTimestamp = reserve._lastUpdatedTimestamp;
        uint256 borrowIndex = reserve._borrowIndex;

        if (reserveTimestamp == block.timestamp) {
            return borrowIndex;
        }

        IRateCalculator rcl = reserve._rcl;
        uint256 increment = rcl.compoundInterest(borrowIndex, reserveTimestamp, block.timestamp);
        borrowIndex = (increment * borrowIndex) / Constants.PINT;
        return borrowIndex;
    }

    function updateRates(ReserveData storage reserve, 
        uint256 totalBorrwedDebt,
        uint256 totalliquidity,
        uint256 supplyAdded,
        uint256 supplyRemoved,
        uint256 borrowRequested,
        uint256 borrowRepayed
    ) internal {
        console.log("Total debt: ", totalBorrwedDebt);
        uint256 debt = totalBorrwedDebt + borrowRequested - borrowRepayed;
        uint256 liquidity = totalliquidity + supplyAdded - supplyRemoved;
        uint256 utilization = debt * Constants.PINT;
        liquidity = liquidity + totalBorrwedDebt; // At this stage the borrow did not happen - don't need to correct the denominator
        utilization = utilization / liquidity;

        console.log("Utilization: ", utilization);

        IRateCalculator rcl = reserve._rcl;

        uint256 _borrowRate = rcl.borrowRate(utilization);
        uint256 _supplyRate = rcl.supplyRate(utilization);

        console.log(_borrowRate);
        console.log(_supplyRate);

        reserve._currentBorrowRate = _borrowRate;
        reserve._currentSupplyRate = _supplyRate;
    }
}