// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';

import {ILendingPool} from './interfaces/ILendingPool.sol';
import {IRateCalculator} from './interfaces/IRateCalculator.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {Allowed} from '../interfaces/Allowed.sol';

import {Reserve} from './library/Reserve.sol';
import {Constants}  from '../lib/Constants.sol';

contract LendingPool is ILendingPool, Allowed {
    using Reserve for Reserve.ReserveData;

    Reserve.ReserveData public reserve;

    constructor(
        address aToken,
        address dToken,
        address want,
        address rcl
    ) Allowed(msg.sender) {
        reserve.init(aToken, dToken, want, rcl, address(this));
    }

    // View functions
    function _debt() internal view returns (uint256) {
        IERC20 dToken = reserve._dToken;
        return (dToken.totalSupply() * reserve.getNormalizedDebt())/Constants.PINT;
    }

    function _available() internal view returns (uint256) {
        IERC20 want = reserve._want;
        return want.balanceOf(address(this));
    }

    function utilization() external view override returns (uint256) {
        uint256 d = _debt();
        return (d * Constants.PINT) / (d + _available());
    }

    function debtToken() external view override returns (address) {
        return address(reserve._dToken);
    }

    function wantToken() external view override returns (address) {
        return address(reserve._want);
    }

    function borrowRate() external view override returns (uint256) {
        return reserve._rcl.borrowRate(this.utilization());
    }

    function supplyRate() external view override returns (uint256) {
        return reserve._rcl.supplyRate(this.utilization());
    }

    function getDebt(address _user) external override view returns (uint256) {
        uint256 balance = reserve._dToken.balanceOf(_user);
        if (balance == 0) {
            return balance;
        }
        return (reserve.getNormalizedDebt() * balance) / Constants.PINT;
    }

    function getBalance(address _user) external override view returns (uint256) {
        uint256 balance = reserve._aToken.balanceOf(_user);
        if (balance == 0) {
            return balance;
        }
        return (reserve.getNormalizedIncome() * balance) / Constants.PINT;
    }

    // Internal repeated function
    function updateReserve(
        uint256 _supply,
        uint256 _withdraw,
        uint256 _borrow,
        uint256 _repay
    ) internal returns (bool) {
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

        uint256 scaledBalance = (_amount * Constants.PINT) / reserve._borrowIndex;

        doToken.mint(_user, scaledBalance);

        IERC20 want = reserve._want;
        want.transfer(_vault, _amount);

        return _amount;
    }

    function supply(
        uint256 _amount // Want token
    ) external override returns (bool) {
        address _user = msg.sender;
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        updateReserve(_amount, uint256(0), uint256(0), uint256(0));

        IERC20 want = reserve._want;
        want.transferFrom(_user, address(this), _amount);

        uint256 scaledAmount = (_amount * Constants.PINT) / reserve._supplyIndex;

        IERC20 aToken = reserve._aToken;
        IMintable maToken = IMintable(address(aToken));

        maToken.mint(_user, scaledAmount);

        return true;
    }

    function withdraw(uint256 _shares) external override returns (bool) {
        address _user = msg.sender;
        require(_user != address(0), "POL: Null address");
        require(_shares > 0, "POL: Zero/Negative amount");
        IERC20 aToken = reserve._aToken;
        require(_shares <= aToken.balanceOf(_user), "POL: Not enough shares");

        uint256 value = (reserve.getNormalizedIncome() * _shares) / Constants.PINT ;
        updateReserve(uint256(0), value, uint256(0), uint256(0));

        uint256 wantAmount = (_shares * reserve._supplyIndex) / Constants.PINT;
        
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
         
        uint256 burnableShares = (_amount * Constants.PINT) / reserve._borrowIndex ;

        IERC20 want = reserve._want;
        want.transferFrom(_vault, address(this), _amount);

        IERC20 dToken = reserve._dToken;
        IMintable doToken = IMintable(address(dToken));
        doToken.burn(_user, burnableShares);

        return true;
    }
}