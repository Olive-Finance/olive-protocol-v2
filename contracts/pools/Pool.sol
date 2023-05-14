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
    address private _asset;
    address private _aToken; // token for liquidity providers
    address private _doToken; // debt token represented as collateral
    address private _aoToken; // A token given a receipt for collateral locked
    address private _oToken; // A generated oToken from the valut is used as collateral here

    struct PoolStorage {
        uint256 _totalAssets;
        uint256 _totalDebt;
        uint256 _totalFees;
        uint256 _lastComputed;
        uint256 _totalCollateral;
    }

    PoolStorage private poolStore;

    // Definition of constants
    uint256 private MAX_BPS = 10000;
    uint256 private liquidationThreshold = 9000;
    uint256 private constant SECONDS_IN_YEAR = 31536000;

    mapping(address => uint256) private lastAccessed;

    constructor(
        address asset,
        address aToken,
        address doToken,
        address oToken,
        address aoToken
    ) Allowed(msg.sender) {
        // Setting the address
        _asset = asset;
        _aToken = aToken;
        _doToken = doToken;
        _oToken = oToken;
        _aoToken = aoToken;

        // Pool storage initialization
        poolStore._lastComputed = block.timestamp;
        poolStore._totalAssets = 0;
        poolStore._totalCollateral = 0;
        poolStore._totalDebt = 0;
        poolStore._totalFees = 0;
    }

    function borrow(
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
        asset.transfer(_user, _amount); //assets are transferred to _receiver

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
        bool result = asset.approve(address(this), _amount);
        require(result, "LPool: No Approval");
        asset.transferFrom(_user, address(this), _amount);

        IMintable aToken = IMintable(_aToken);
        aToken.mint(_user, _amount);

        poolStore._totalAssets = poolStore._totalAssets.add(_amount);
        return true;
    }

    function submitCollateral(
        address _user,
        uint256 _amount
    ) external override returns (bool) {
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        IERC20 oToken = IERC20(_oToken);
        oToken.transferFrom(_user, address(this), _amount);

        IMintable aoToken = IMintable(_aoToken);
        aoToken.mint(_user, _amount);

        poolStore._totalCollateral = poolStore._totalCollateral.add(_amount);
        return true;
    }

    function retrieveCollateral(
        address _user,
        uint256 _amount
    ) external override returns (bool) {
        require(_user != address(0), "POL: Null address");
        require(_amount > 0, "POL: Zero/Negative amount");

        IMintable aoToken = IMintable(_aoToken);
        aoToken.burn(_user, _amount);

        IERC20 oToken = IERC20(_oToken);
        oToken.transfer(_user, _amount);

        poolStore._totalCollateral = poolStore._totalCollateral.sub(_amount, 'POL: Low funds');

        return true;
    }

    function interestRate() external pure override returns (uint256) {
        return 800;
    }

    function healthFactor(
        address _user
    ) external view override returns (uint256) {
        IERC20 doToken = IERC20(_doToken);
        uint256 debt = doToken.balanceOf(_user);

        if (debt == 0) {
            return MAX_BPS;
        }

        console.log('Debt: ', debt.div(1e8));

        IERC20 cToken = IERC20(_aoToken);
        uint256 collateral = cToken.balanceOf(_user);

        if (collateral == 0) {
            return 0;
        }
        console.log('Collateral: ', collateral.div(1e8));

        uint256 fees = debt *
            (block.timestamp - lastAccessed[_user]) *
            this.interestRate();
        

        fees = fees.div(313536000).div(MAX_BPS);
        console.log("Fees: ", fees.div(1e8));
        uint256 hf = collateral.mul(MAX_BPS).div(debt + fees);
        console.log('HF local: ', hf);
        hf *= liquidationThreshold;
        hf /= (MAX_BPS * 1e2);
        return hf;
    }

    function repay(
        address _user,
        uint256 _amount,
        uint256 _shares,
        bool _tbc
    ) external override returns (bool) {
        require(_amount > 0, "POL: Zero/Negative amount");

        IERC20 asset = IERC20(_asset);

        asset.transferFrom(_user, address(this), (_amount));

        poolStore._totalDebt = poolStore._totalDebt.sub(_amount, 'POL: No debt');
        
        IMintable doToken = IMintable(_doToken);
        doToken.burn(_user, _shares);

        if(_tbc) {
            this.retrieveCollateral(_user, _shares);
        }
        return true;
    }

    // todo deleverage 

    function releaseAllCollateral(address _user) internal returns (bool) {
        IERC20 cToken = IERC20(_aoToken);
        uint256 collateral = cToken.balanceOf(_user);
        this.retrieveCollateral(_user, collateral);
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

    function getTotalSharesToWithdraw(
        address _user
    ) external override view returns (uint256) {
        IERC20 aoToken = IERC20(_aoToken);
        uint256 aoBalance = aoToken.balanceOf(_user);

        IERC20 doToken = IERC20(_doToken);
        uint256 doTokenBalance = doToken.balanceOf(_user);


        if (doTokenBalance == 0) {
            return aoBalance;
        }

        // Convert the PPS for aoToken and doToken
        uint256 balance = MAX_BPS.sub(liquidationThreshold);
        balance = balance.mul(aoBalance);
        balance = balance.div(MAX_BPS);

        return balance;
    }
}