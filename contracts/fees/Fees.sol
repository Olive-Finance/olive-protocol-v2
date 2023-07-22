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
    uint256 pFee;
    uint256 mFee;

    // Empty constructor
    constructor() Allowed(msg.sender) Governable(msg.sender) {}

    function getPFee() external view override returns (uint256) { 
        return pFee; 
    }

    function getMFee() external view override returns (uint256) { 
        return mFee;
    }

    function getTreasury() external view override onlyOwner returns (address) {
        return treasury;
    }

    function setTreasury(address _treasury) external override onlyGov {
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
}