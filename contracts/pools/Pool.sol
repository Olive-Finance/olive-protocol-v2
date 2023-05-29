// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {ILendingPool} from '../interfaces/ILendingPool.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {Allowed} from '../utils/modifiers/Allowed.sol';
import "hardhat/console.sol";

contract Pool is ILendingPool, Allowed {
    using SafeMath for uint256;

    //List of addresses
    address private _asset; // asset a.k.a want token
    address private _aToken; // token for liquidity providers
    address private _doToken; // debt token represented as collateral

    struct PoolStorage {
        uint256 _totalAssets;
        uint256 _totalDebt;
        uint256 _totalFees;
        uint256 _lastComputed;
    }

    PoolStorage private poolStore;

    // Definition of constants
    uint256 private MAX_BPS = 10000;
    uint256 private liquidationThreshold = 9000;
    uint256 private constant SECONDS_IN_YEAR = 31536000;
    uint256 private MAX_UTILIZATION = 0.8e4;

    mapping(address => uint256) private lastAccessed;

    constructor(
        address asset,
        address aToken,
        address doToken
    ) Allowed(msg.sender) {
        // Setting the address
        _asset = asset;
        _aToken = aToken;
        _doToken = doToken;

        // Pool storage initialization
        poolStore._lastComputed = block.timestamp;
        poolStore._totalAssets = 0;
        poolStore._totalDebt = 0;
        poolStore._totalFees = 0;
    }

    function borrow(
        address _toAccount,
        address _user,
        uint256 _amount
    ) external override onlyAllowed returns (uint256) {
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        poolStore._totalAssets = poolStore._totalAssets.sub(
            _amount,
            "ERC20: Low funds"
        );
        IERC20 asset = IERC20(_asset);
        asset.transfer(_toAccount, _amount); //assets are transferred to _receiver

        IMintable doToken = IMintable(_doToken);
        doToken.mint(_user, _amount);

        lastAccessed[_user] = block.timestamp; // todo - do double check this if we really want it
        poolStore._totalDebt = poolStore._totalDebt.add(_amount);

        return _amount;
    }

    function fund(
        address _user,
        uint256 _amount
    ) external override returns (bool) {
        // Add the funds to Total Assets
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        IERC20 asset = IERC20(_asset);
        asset.transferFrom(_user, address(this), _amount);

        IMintable aToken = IMintable(_aToken);
        aToken.mint(_user, _amount);

        poolStore._totalAssets = poolStore._totalAssets.add(_amount);
        return true;
    }

    function interestRate() external pure override returns (uint256) {
        return 800;
    }

    function repay(
        address _fromAccount,
        address _user,
        uint256 _amount
    ) external override returns (bool) {
        require(_amount > 0, "POL: Zero/Negative amount");

        IERC20 asset = IERC20(_asset);
        asset.transferFrom(_fromAccount, address(this), (_amount));

        poolStore._totalDebt = poolStore._totalDebt.sub(
            _amount,
            "POL: No debt"
        );

        uint256 _shares = convertAmountToShares(_amount);

        IMintable doToken = IMintable(_doToken);
        doToken.burn(_user, _shares);

        return true;
    }

    function convertAmountToShares(
        uint256 _debtAmount
    ) internal view returns (uint256) {
        return _debtAmount;
    }

    function liquidate(
        address[] calldata _users
    ) external override returns (bool) {
        // burn the oTokens from the vault
        // Get the assets back
        // Charge 10% fee
    }

    function setLiquidationThreshold(
        uint256 _threshold
    ) public onlyAllowed returns (bool) {
        liquidationThreshold = _threshold;
        return true;
    }

    function viewPool() public view returns (PoolStorage memory) {
        return poolStore;
    }

    function viewUtilization() public view returns (uint256) {
        return
            (poolStore._totalDebt * 100) /
            (poolStore._totalAssets + poolStore._totalDebt);
    }

    function utilization() external view override returns (uint256) {
        return
            poolStore._totalDebt.mul(1e4).div(
                poolStore._totalAssets.add(poolStore._totalDebt)
            );
    }

    function healthFactor(
        address _user
    ) external view override returns (uint256) {}

    function debtToken() external view override returns (address) {
        return _doToken;
    }

    function wantToken() external view override returns (address) {
        return _asset;
    }

    function maxAllowedUtilization() external view override returns (uint256) {
        return MAX_UTILIZATION;
    }

    function maxAllowedAmount() external view override returns (uint256) {
        uint256 _assets = poolStore._totalAssets;
        uint256 _debts = poolStore._totalDebt;
        _assets = _assets.add(_debts);
        uint256 _maxAllowed = _assets.mul(MAX_UTILIZATION).div(MAX_BPS);
        _maxAllowed = _maxAllowed.sub(_debts, 'POL: over borrowed');
        return _maxAllowed;
    }
}