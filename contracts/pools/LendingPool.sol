// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';

import {ILendingPool} from './interfaces/ILendingPool.sol';
import {IRateCalculator} from './interfaces/IRateCalculator.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {Allowed} from '../interfaces/Allowed.sol';

import {Reserve} from './library/Reserve.sol';
import {Constants}  from '../lib/Constants.sol';

import "hardhat/console.sol";

contract LendingPool is ILendingPool, Allowed {
    using SafeMath for uint256;
    using Reserve for Reserve.ReserveData;

    Reserve.ReserveData public reserve;

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
    function _debt() internal view returns (uint256) {
        IERC20 dToken = reserve._dToken;
        uint256 supply = dToken.totalSupply();
        return supply.mul(reserve.getNormalizedDebt()).div(Constants.PINT);
    }

    function _available() internal view returns (uint256) {
        address pool = reserve._pool;
        IERC20 want = reserve._want;
        return want.balanceOf(pool);
    }

    function utilization() external view override returns (uint256) {
        uint256 d = _debt();
        uint256 util = d.mul(Constants.PINT);
        util = util.div(d.add(_available()));
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

    function borrowRate() external view override returns (uint256) {
        IRateCalculator rcl = reserve._rcl;
        return rcl.borrowRate(this.utilization());
    }

    function supplyRate() external view override returns (uint256) {
        IRateCalculator rcl = reserve._rcl;
        return rcl.supplyRate(this.utilization());
    }

    // Internal repeated function
    function updateReserve(
        uint256 _supply,
        uint256 _withdraw, // This is coming as shares
        uint256 _borrow,
        uint256 _repay
    ) internal returns (bool) {
        // Common function to be called before execution of deposit, borrow, repay, withdraw
        reserve.updateState();

        reserve.updateRates(
            _debt(),
            _available(),
            _supply,
            _withdraw,
            _borrow,
            _repay
        );
        return true;
    }

    function borrow(
        address _vault,
        address _user,
        uint256 _amount // Want token
    ) external override onlyAllowed returns (uint256) {
        require(_vault != address(0), "POL: Null address");
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        updateReserve(uint256(0), uint256(0), _amount, uint256(0));

        IERC20 dToken = reserve._dToken;
        IMintable doToken = IMintable(address(dToken));

        uint256 borrowIndex = reserve._borrowIndex;
        uint256 scaledBalance = _amount.mul(Constants.PINT).div(borrowIndex);

        doToken.mint(_user, scaledBalance);

        IERC20 want = reserve._want;
        want.transfer(_vault, _amount);

        return _amount;
    }

    function fund(
        uint256 _amount // Want token
    ) external override returns (bool) {
        address _user = msg.sender;
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        updateReserve(_amount, uint256(0), uint256(0), uint256(0));

        IERC20 want = reserve._want;
        want.transferFrom(_user, address(this), _amount);

        uint256 supplyIndex = reserve._supplyIndex;
        uint256 scaledAmount = _amount.mul(Constants.PINT).div(supplyIndex);

        IERC20 aToken = reserve._aToken;
        IMintable maToken = IMintable(address(aToken));

        maToken.mint(_user, scaledAmount);

        return true;
    }

    function withdraw(uint256 _shares) external override returns (bool) {
        address _user = msg.sender;
        require(_user != address(0), "POL: Null address");
        require(_shares > 0, "POL: Zero/Negative amount");

        //todo fix the shares to supply balance
        updateReserve(uint256(0), _shares, uint256(0), uint256(0));

        uint256 supplyIndex = reserve._supplyIndex;
        uint256 wantAmount = _shares.mul(supplyIndex).div(Constants.PINT);

        IERC20 aToken = reserve._aToken;
        IMintable maToken = IMintable(address(aToken));

        maToken.burn(_user, _shares);

        IERC20 want = reserve._want;
        want.transfer(_user, wantAmount);

        return true;
    }

    function repay(
        address _vault,
        address _user,
        uint256 _amount // Want token
    ) external override returns (bool) {
        require(_amount > 0, "POL: Zero/Negative amount");
        require(_user != address(0), "POL: Null address");

        updateReserve(uint256(0), uint256(0), uint256(0), _amount);

        uint256 borrowIndex = reserve._borrowIndex;
        uint256 burnableShares = _amount.mul(Constants.PINT).div(borrowIndex);

        IERC20 want = reserve._want;
        want.transferFrom(_vault, address(this), _amount);

        IERC20 dToken = reserve._dToken;
        IMintable doToken = IMintable(address(dToken));
        doToken.burn(_user, burnableShares);

        return true;
    }

    function getDebt(address _user) public view returns (uint256) {
        console.log("timeStamp : ", block.timestamp);
        IERC20 dToken = reserve._dToken;
        uint256 balance = dToken.balanceOf(_user);
        if (balance == 0) {
            return balance;
        }
        return reserve.getNormalizedDebt().mul(balance).div(Constants.PINT);
    }

    function getBalance(address _user) public view returns (uint256) {
        console.log("timeStamp : ", block.timestamp);
        IERC20 aToken = reserve._aToken;
        uint256 balance = aToken.balanceOf(_user);
        if (balance == 0) {
            return balance;
        }
        uint256 nii = reserve.getNormalizedIncome();
        return nii.mul(balance).div(Constants.PINT);
    }

    function getDebtInWant(
        address _user
    ) external view override returns (uint256) {}
}