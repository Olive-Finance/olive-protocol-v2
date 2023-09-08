// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IRateCalculator} from "./interfaces/IRateCalculator.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {IFees} from "../fees/interfaces/IFees.sol";
import {Allowed} from "../utils/Allowed.sol";

import {Reserve} from "./library/Reserve.sol";
import {Constants}  from "../lib/Constants.sol";

contract LendingPool is ILendingPool, Allowed {
    using Reserve for Reserve.ReserveData;

    Reserve.ReserveData public reserve;
    IFees public fees;
    uint256 public totalFees;
    uint256 public badDebt;

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
        return (reserve.getNormalizedIncome() * balance)/Constants.PINT;
    }

    function debtCorrection() public view returns (uint256) {
        uint256 totalSupplied = (reserve.getNormalizedIncome() * reserve._aToken.totalSupply()) / Constants.PINT;
        if (badDebt >= totalSupplied) return Constants.ZERO;
        return ((totalSupplied - badDebt) * Constants.PINT) / totalSupplied;
    }

    function repayBadDebt(uint256 _amount) external {
        require(_amount > 0, "POL: Zero/Negative amount");
        uint256 toRepay = _amount > badDebt ? badDebt : _amount;
        reserve._want.transferFrom(msg.sender, address(this), toRepay);
        badDebt -= toRepay;
    }

    function setFees(address _fees) external onlyOwner {
        require(_fees != address(0), "POL: Invalid fees address");
        fees = IFees(_fees);
    }

    function mintFees(uint256 _amount) external onlyOwner {
        if (_amount <= 0) return ;
        uint256 scaledAmount = (totalFees * Constants.PINT) / reserve._supplyIndex;
        IMintable(address(reserve._aToken)).mint(fees.getTreasury(), scaledAmount);
    }

    // Internal repeated function
    function updateReserve(
        uint256 _supply,
        uint256 _withdraw,
        uint256 _borrow,
        uint256 _repay
    ) internal returns (bool) {
        uint256 toTreasury = reserve.updateState();
        totalFees += toTreasury;
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
        address _to,
        address _user,
        uint256 _amount // Want token
    ) external override onlyAllowed whenNotPaused nonReentrant returns (uint256) {
        require(_to != address(0), "POL: Null address");
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");
        require(_amount <= _available(), "POL: Insufficient liquidity to borrow");

        updateReserve(uint256(0), uint256(0), _amount, uint256(0));

        uint256 scaledBalance = (_amount * Constants.PINT) / reserve._borrowIndex;
        IMintable(address(reserve._dToken)).mint(_user, scaledBalance);
        reserve._want.transfer(_to, _amount);

        return _amount;
    }

    function supply(
        uint256 _amount // Want token
    ) external override whenNotPaused nonReentrant returns (bool) {
        address _user = msg.sender;
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        updateReserve(_amount, uint256(0), uint256(0), uint256(0));

        reserve._want.transferFrom(_user, address(this), _amount);
        uint256 scaledAmount = (_amount * Constants.PINT) / reserve._supplyIndex;
        IMintable(address(reserve._aToken)).mint(_user, scaledAmount);

        return true;
    }

    function withdraw(uint256 _shares) external whenNotPaused nonReentrant override returns (bool) {
        address _user = msg.sender;
        require(_shares > 0, "POL: Zero/Negative amount");
        IERC20 aToken = reserve._aToken;
        require(_shares <= aToken.balanceOf(_user), "POL: Not enough shares");

        uint256 value = (reserve.getNormalizedIncome() * _shares) / Constants.PINT ;
        updateReserve(uint256(0), value, uint256(0), uint256(0));

        uint256 wantAmount = (_shares * reserve._supplyIndex) / Constants.PINT;

        // Socialising the bad debt
        // todo : add test case with burning all the supply tokens - badDebt should be zero (Given there are no dTokens in circulation)
        // todo : debtConnection factor should be same for all the users - validate this as test case

        uint256 dc = debtCorrection(); 
        badDebt -= wantAmount * (Constants.PINT - dc)/Constants.PINT;
        wantAmount = (wantAmount * dc) / Constants.PINT;
        
        require(wantAmount <= _available(), "POL: Insufficient liquidity to withdraw");
        
        IMintable(address(aToken)).burn(_user, _shares);
        reserve._want.transfer(_user, wantAmount);

        return true;
    }

    function repay(
        address _from,
        address _user,
        uint256 _amount // Want token
    ) external override returns (bool) {
        return _repayDebt(_from, _user, _amount);
    }

    function _repayDebt(
        address _from,
        address _user,
        uint256 _amount
    ) internal whenNotPaused nonReentrant returns (bool) {
        require(_amount > 0, "POL: Zero/Negative amount");
        require(_user != address(0), "POL: Null address");

        updateReserve(uint256(0), uint256(0), uint256(0), _amount);
         
        uint256 burnableShares = (_amount * Constants.PINT) / reserve._borrowIndex ;
        reserve._want.transferFrom(_from, address(this), _amount);

        IMintable(address(reserve._dToken)).burn(_user, burnableShares);
        return true;
    }
 
    function _settle(address _user) internal {
        uint256 debt = reserve._dToken.balanceOf(_user);
        if (debt == 0) return;
        uint256 _bDebt = (debt * reserve.getNormalizedDebt()) / Constants.PINT;
        badDebt += _bDebt; 
        IMintable(address(reserve._dToken)).burn(_user, debt);
    }

    function repayWithSettle(
        address _from, 
        address _user, 
        uint256 amount
    ) external override onlyAllowed returns (bool) {
        _repayDebt(_from, _user, amount);
        _settle(_user);
        return true;
    }
}