// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';

import {ILendingPool} from './interfaces/ILendingPool.sol';
import {IRateCalculator} from './interfaces/IRateCalculator.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {Allowed} from '../interfaces/Allowed.sol';

import {Reserve} from './library/Reserve.sol';

import "hardhat/console.sol";

contract Pool is ILendingPool, Allowed {
    using SafeMath for uint256;
    using Reserve for Reserve.ReserveData;

    Reserve.ReserveData public reserve;

    uint256 constant ONE_HUNDERED = 1e2;

    constructor(
        address aToken,
        address dToken,
        address want,
        address rcl
    ) Allowed(msg.sender) {
        // Initiating the reserve
        reserve.init(aToken, dToken, want, rcl, address(this));
    }

    // View functions
    function _totalBorrowedDebt() internal view returns (uint256) {
        IERC20 dToken = reserve._dToken;
        uint256 supply = dToken.totalSupply();
        console.log("_borrowed debt: ", supply);
        console.log("_timestamp: ", block.timestamp);
        return supply.mul(reserve.getNormalizedDebt()).div(Reserve.PINT);
    }

    function _totalLiquidity() internal view returns (uint256) {
        address pool = reserve._pool;
        IERC20 want = reserve._want;
        return want.balanceOf(pool);
    }

    function utilization() external view override returns (uint256) {
        uint256 debt = _totalBorrowedDebt();
        uint256 supply = _totalLiquidity();

        uint256 util = debt.mul(Reserve.PINT);
        util = util.div(debt.add(supply));
        return util;
    }

    function debtToken() external view override returns (address) {
        IERC20 dToken = reserve._dToken;
        return address(dToken);
    }

    function wantToken() external view override returns (address) {
        IERC20 want = reserve._want;
        return address(want);
    }

    function maxAllowedAmount() external view override returns (uint256) {
        return uint256(1e28);
    }

    // Internal repeated functions
    function reserveUpdates(
        uint256 _supplied,
        uint256 _withdrawn,
        uint256 _borrowed,
        uint256 _repayed
    ) internal returns (bool) {
        // Common function to be called befor execution of deposit, borrow, repay, withdraw
        reserve.updateState();
        uint256 totalBorrowedDebt = _totalBorrowedDebt();
        uint256 totalLiquidity = _totalLiquidity();
        reserve.updateRates(
            totalBorrowedDebt,
            totalLiquidity,
            _supplied,
            _withdrawn,
            _borrowed,
            _repayed
        );
        return true;
    }

    function borrow(
        address _toAccount,
        address _user,
        uint256 _amount // USDC
    ) external override onlyAllowed returns (uint256) {
        require(_toAccount != address(0), "POL: Null address");
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        bool updated = reserveUpdates(uint256(0), uint256(0), _amount, uint256(0));
        require(updated, "POL: State update failed");

        IERC20 dToken = reserve._dToken;
        IMintable doToken = IMintable(address(dToken));

        uint256 borrowIndex = reserve._borrowIndex;
        uint256 scaledAmount = _amount.mul(Reserve.PINT).div(borrowIndex);

        doToken.mint(_user, scaledAmount);

        IERC20 want = reserve._want;
        want.transfer(_toAccount, _amount);

        return _amount;
    }

    function fund(
        address _user,
        uint256 _amount // USDC
    ) external override returns (bool) {
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        bool updated = reserveUpdates(_amount, uint256(0), uint256(0), uint256(0));
        require(updated, "POL: State update failed");

        IERC20 want = reserve._want;
        want.transferFrom(_user, address(this), _amount);

        uint256 supplyIndex = reserve._supplyIndex;
        uint256 scaledAmount = _amount.mul(Reserve.PINT).div(supplyIndex);

        IERC20 aToken = reserve._aToken;
        IMintable mintableAToken = IMintable(address(aToken));

        console.log("Atoken Transferred: ", scaledAmount);

        mintableAToken.mint(_user, scaledAmount);

        return true;
    }

    function withdraw(
        address _user,
        uint256 _amount // aToken - change to shares
    ) external override returns (bool) {
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        bool updated = reserveUpdates(uint256(0), _amount, uint256(0), uint256(0));
        require(updated, "POL: State update failed");

        uint256 supplyIndex = reserve._supplyIndex;
        uint256 wantAmount = _amount.mul(supplyIndex).div(Reserve.PINT);

        IERC20 aToken = reserve._aToken;
        IMintable mintableAToken = IMintable(address(aToken));

        mintableAToken.burn(_user, _amount);

        console.log("Want Transferred: ", wantAmount);

        IERC20 want = reserve._want;
        want.transfer(_user, wantAmount);

        return true;
    }

    function borrowRate() external view override returns (uint256) {
        IRateCalculator rcl = reserve._rcl;
        uint256 br = rcl.calculateBorrowRate(this.utilization());
        return br.mul(ONE_HUNDERED).div(Reserve.PINT);
    }

    function supplyRate() external view override returns (uint256) {
        IRateCalculator rcl = reserve._rcl;
        uint256 u = this.utilization();
        uint256 sr = rcl.calculateSupplyRate(rcl.calculateBorrowRate(u), u);
        return sr.mul(ONE_HUNDERED).div(Reserve.PINT);
    }

    function repay(
        address _fromAccount,
        address _user,
        uint256 _amount // USDC 
    ) external override returns (bool) {
        require(_amount > 0, "POL: Zero/Negative amount");
        require(_user != address(0), "POL: Null address");

        bool updated = reserveUpdates(uint256(0), uint256(0), uint256(0), _amount);
        require(updated, "POL: State update failed");

        uint256 borrowIndex = reserve._borrowIndex;
        uint256 toBurnAmount = _amount.mul(Reserve.PINT).div(borrowIndex);

        uint256 toTransfer = _amount.mul(borrowIndex).div(Reserve.PINT);

        IERC20 want = reserve._want;
        want.transferFrom(_fromAccount, address(this), _amount);

        console.log("Atoken Transferred: ", _amount);

        IERC20 dToken = reserve._dToken;
        IMintable doToken = IMintable(address(dToken));
        doToken.burn(_user, toBurnAmount);

        return true;
    }

    function getDebtInWant(address _user) public view returns (uint256) {
        console.log("timeStamp : ", block.timestamp);
        IERC20 dToken = reserve._dToken;
        uint256 balance = dToken.balanceOf(_user);
        if (balance == 0) {
            return balance;
        }
        uint256 ndi = reserve.getNormalizedDebt();
        return ndi.mul(balance).div(Reserve.PINT);
    }

    function getIncomeInWant(address _user) public view returns (uint256) {
        console.log("timeStamp : ", block.timestamp);
        IERC20 aToken = reserve._aToken;
        uint256 balance = aToken.balanceOf(_user);
        if (balance == 0) {
            return balance;
        }
        uint256 nii = reserve.getNormalizedIncome();
        return nii.mul(balance).div(Reserve.PINT);
    }
}