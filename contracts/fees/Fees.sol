// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IFees} from './interfaces/IFees.sol';

import {Allowed} from '../utils/Allowed.sol';
import {Governable} from '../utils/Governable.sol';

import {Constants} from '../lib/Constants.sol';


contract Fees is IFees, Allowed, Governable {
    //treasury
    address public treasury;

    // percentages
    uint256 public pFee;
    uint256 public mFee;
    uint256 public keeperFee;
    uint256 public liquidationFee;
    uint256 public liquidatorFee;

    // Empty constructor
    constructor() Allowed(msg.sender) Governable(msg.sender) {}

    function getPFee() external view override returns (uint256) { 
        return pFee; 
    }

    function getMFee() external view override returns (uint256) { 
        return mFee;
    }

    function getTreasury() external view override returns (address) {
        return treasury;
    }

    function getLiquidationFee() external view override returns (uint256) {
        return liquidationFee;
    }

    function getLiquidatorFee() external view override returns (uint256) {
        return liquidatorFee;
    }

    function getLiquidationTreasuryFee() external view override returns (uint256) {
        return (Constants.HUNDRED_PERCENT - liquidatorFee);
    }

    function setTreasury(address _treasury) external override onlyOwner {
        require(_treasury != address(0), "FEE: Invalid treasury address");
        treasury = _treasury;
    }

    function setPFee(uint256 _pFee) external override onlyGov {
        require(_pFee <= Constants.MAX_PERFORMANCE_FEE, "FEE: Invalid perfromance fee");
        pFee = _pFee;
    }

    function setMFee(uint256 _mFee) external override onlyGov {
        require(_mFee <= Constants.MAX_MANAGEMENT_FEE, "FEE: Invalid management fee");
        mFee = _mFee;
    }

    function setLiquidationFee(uint256 _liquidationFee) external override onlyGov {
        liquidationFee = _liquidationFee;
    }

    function setLiquidatorFee(uint256 _liquidatorFee) external override onlyGov {
        require(Constants.HUNDRED_PERCENT >= _liquidatorFee, "FEE: Invalid liquidator fee");
        liquidatorFee = _liquidatorFee;
    }
}