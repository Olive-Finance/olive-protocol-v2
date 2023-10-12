// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {ILimit} from "./interfaces/ILimit.sol";
import {IRateCalculator} from "./interfaces/IRateCalculator.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {IFees} from "../fees/interfaces/IFees.sol";
import {IDToken} from "./interfaces/IDToken.sol";
import {Allowed} from "../utils/Allowed.sol";

import {Reserve} from "./library/Reserve.sol";
import {Constants}  from "../lib/Constants.sol";

contract LendingPool is ILendingPool, Allowed {
    using Reserve for Reserve.ReserveData;

    Reserve.ReserveData public reserve;
    IFees public fees;
    uint256 public totalFees;
    uint256 public badDebt;
    ILimit public limit;

    constructor(
        address aToken,
        address dToken,
        address want,
        address rcl,
        address _limit
    ) Allowed(msg.sender) {
        reserve.init(aToken, dToken, want, rcl);
        limit = ILimit(_limit);
    }

    // View functions
    function _debt() public view returns (uint256) {
        IERC20 dToken = reserve._dToken;
        return (dToken.totalSupply() * reserve.getNormalizedDebt())/Constants.PINT;
    }

    function _available() public view returns (uint256) {
        IERC20 aToken = reserve._aToken;
        return (aToken.totalSupply() * reserve.getNormalizedIncome())/Constants.PINT;
    }

    function utilization() external view override returns (uint256) {
        return (_debt() * Constants.PINT) / _available();
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

    function getDebtByVault(address _vault, address _user) external override view returns (uint256) {
        uint256 balance = IDToken(address(reserve._dToken)).debtOf(_vault, _user);
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

    function getMaxBorrableAmount(address _to) external override view returns (uint256) {
        if (_to == address(0)) return 0;
        uint256 v1 = reserve._want.balanceOf(address(this));
        uint256 v2 = limit.getLimit(_to);
        return v1 > v2 ? v2 : v1;
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

    function setLimit(address _limit) external onlyOwner {
        require(_limit != address(0), "POL: Invalid limit address");
        limit = ILimit(_limit);
    }

    /** Part of migration functions */
    function setTokens(address aToken, address dToken, address rcl) whenPaused external onlyOwner {
        require(aToken != address(0), "POL: Invalid aToken address");
        require(dToken != address(0), "POL: Invalid dToken address");
        reserve._aToken = IERC20(aToken);
        reserve._dToken = IERC20(dToken);
        reserve._rcl = IRateCalculator(rcl);
    }

    function setReserveParameters(uint256 _supplyRate, uint256 _borrowRate,
     uint256 _supplyIndex, uint256 _borrowIndex, uint256 _lastupdated) whenPaused external onlyOwner {
        reserve._supplyIndex = _supplyIndex;
        reserve._borrowIndex = _borrowIndex;
        reserve._lastUpdatedTimestamp = _lastupdated;
        reserve._supplyRate = _supplyRate;
        reserve._borrowRate = _borrowRate;
    }

    // Migration to new lending pool
    function migrate(address _to) external whenPaused onlyOwner {
        // transfer the tokens
        IERC20 want = reserve._want;
        want.transfer(_to, want.balanceOf(address(this)));
    }

    function mintFees() external onlyOwner {
        uint256 scaledAmount = (totalFees * Constants.PINT) / reserve._supplyIndex;
        totalFees = 0;
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
        require(!limit.isBlackList(_user), "POL: Blacklisted address"); // Blacklist check
        require(_amount > 0, "POL: Zero/Negative amount");
        require(_amount <= limit.getLimit(_to), "POL: Borrow limit exceeded"); // Limit check
        require(_amount <= _available(), "POL: Insufficient liquidity to borrow");

        updateReserve(uint256(0), uint256(0), _amount, uint256(0));
        limit.consumeLimit(_to, _amount); // Limit update

        uint256 scaledBalance = (_amount * Constants.PINT) / reserve._borrowIndex;
        IDToken(address(reserve._dToken)).mintuv(_to, _user, scaledBalance);
        reserve._want.transfer(_to, _amount);

        return _amount;
    }

    function supply(
        uint256 _amount // Want token
    ) external override whenNotPaused nonReentrant returns (bool) {
        address _user = msg.sender;
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

        uint256 dc = debtCorrection(); 
        badDebt -= wantAmount * (Constants.PINT - dc)/Constants.PINT;
        wantAmount = (wantAmount * dc) / Constants.PINT;
        
        IMintable(address(aToken)).burn(_user, _shares);
        reserve._want.transfer(_user, wantAmount);

        return true;
    }

    function repay(
        address _from,
        address _vault,
        address _user,
        uint256 _amount // Want token
    ) external override returns (bool) {
        return _repayDebt(_from, _vault, _user, _amount);
    }

    function _repayDebt(
        address _from,
        address _vault,
        address _user,
        uint256 _amount
    ) internal whenNotPaused nonReentrant returns (bool) {
        require(_amount > 0, "POL: Zero/Negative amount");
        require(_user != address(0), "POL: Null address");

        updateReserve(uint256(0), uint256(0), uint256(0), _amount);
         
        uint256 burnableShares = (_amount * Constants.PINT) / reserve._borrowIndex ;
        reserve._want.transferFrom(_from, address(this), _amount);
        IDToken(address(reserve._dToken)).burnuv(_vault, _user, burnableShares);
        limit.enhaceLimit(_vault, _amount); // todo : limit is updated to user in case of liquidation 
        return true;
    }
 
    function _settle(address _user, uint256 _sFactor) internal {
        uint256 debt = reserve._dToken.balanceOf(_user);
        if (debt == 0) return;
        uint256 _bDebt = (debt * reserve.getNormalizedDebt() * _sFactor) / Constants.PINT_POW_2;
        badDebt += _bDebt; 
        IMintable(address(reserve._dToken)).burn(_user, debt);
        emit BadDebt(_user, _bDebt);
    }

    function repayWithSettle(
        address _from, 
        address _vault,
        address _user, 
        uint256 _amount,
        uint256 _sFactor
    ) external override onlyAllowed returns (bool) {
        _repayDebt(_from, _vault, _user, _amount);
        _settle(_user, _sFactor);
        return true;
    }
}