// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {IVaultCore} from './interfaces/IVaultCore.sol';

import {Allowed} from '../utils/Allowed.sol';
import {Constants} from '../lib/Constants.sol';

abstract contract VaultCore is IVaultCore, Allowed {
    //Token addresses
    IERC20 public asset;
    IERC20 public oToken;
    IERC20 public sToken;

    //Address for strategy
    address public strategy;

    //Olive treasury address
    address public treasury;

    // Pool for borrowing
    address public lendingPool;

    //Price per share
    uint256 public pps = Constants.PINT;

    // Contract for doing vault actions - deposit, withdraw, leverage, deleverage
    address public vaultManager;

    // Contract for doing vault liquidation & super liquidation
    address public vaultKeeper;

    // Vault parameters
    uint256 public MAX_LEVERAGE;
    uint256 public MIN_LEVERAGE;
    uint256 public LIQUIDATION_THRESHOLD;
    uint256 public HF_THRESHOLD = Constants.PINT;

    // Empty constructor - all the values will be set by setter functions
    constructor(address owner) Allowed(owner) {}

    modifier onlyMoK() {
        require(
            msg.sender == vaultManager || msg.sender == vaultKeeper,
            "VC: Not an manager / keeper"
        );
        _;
    }

    // Vault setter functions
    function setVaultManager(address _vaultManager) external onlyOwner {
        require(_vaultManager != address(0), "VC: Invalid vault manager");
        vaultManager = _vaultManager;
    }

    function setVaultKeeper(address _vaultKeeper) external onlyOwner {
        require(_vaultKeeper != address(0), "VC: Invalid vault keeper");
        vaultKeeper = _vaultKeeper;
    }

    function setLendingPool(address _lendingPool) external onlyOwner {
        require(_lendingPool != address(0), "VC: Invalid lending pool");
        lendingPool = _lendingPool;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(
            _treasury != address(0) && _treasury != address(this),
            "VC: Invalid treasury address"
        );
        treasury = _treasury;
    }

    function setLeverage(uint256 _minLeverage, uint256 _maxLeverage) external onlyOwner {
        require(_maxLeverage > _minLeverage, "VC: Invalid leverage");
        MIN_LEVERAGE = _minLeverage;
        MAX_LEVERAGE = _maxLeverage;
    }

    function setTokens(
        address _asset,
        address _oToken,
        address _sToken
    ) external onlyOwner {
        require(
            _asset != address(0) &&
                _oToken != address(0) &&
                _sToken != address(0),
            "VC: Invalid tokens"
        );
        asset = IERC20(_asset);
        oToken = IERC20(_oToken);
        sToken = IERC20(_sToken);
    }

    function setPPS(uint256 _pps) external override whenNotPaused onlyMoK {
        pps = _pps;
    }

    // Vault view functions
    function getPPS() external view override returns (uint256) {
        return pps;
    }

    function getTreasury() external view override returns (address) {
        return treasury;
    }

    function getAssetToken() external view override returns (address) {
        return address(asset);
    }

    function getLedgerToken() external view override returns (address) {
        return address(oToken);
    }

    function getLendingPool() external view override returns (address) {
        return lendingPool;
    }

    function getStrategy() external view override returns (address) {
        return strategy;
    }

    function getHFThreshold() external view override returns (uint256) {
        return HF_THRESHOLD;
    }

    function getLiquidationThreshold()
        external
        view
        override
        returns (uint256)
    {
        return LIQUIDATION_THRESHOLD;
    }

    function getMinLeverage() external view override returns (uint256) {
        return MIN_LEVERAGE;
    }

    function getMaxLeverage() external view override returns (uint256) {
        return MAX_LEVERAGE;
    }

    function totalDeposits() external view override returns (uint256) {
        return asset.balanceOf(strategy);
    }

    // Mint / Burn / Token transfer functions
    function mintShares(
        address _user,
        uint256 _amount
    ) external override whenNotPaused onlyMoK {
        require(_user != address(0) && _amount > 0, "VC: Invalid inputs");
        IMintable(address(oToken)).mint(_user, _amount);
    }

    function burnShares(
        address _user,
        uint256 _amount
    ) external override whenNotPaused onlyMoK {
        require(_user != address(0) && _amount > 0, "VC: Invalid inputs");
        require(
            oToken.balanceOf(_user) >= _amount,
            "VC: Insufficient balance"
        );
        IMintable(address(oToken)).burn(_user, _amount);
    }

    function transferAsset(address _to, uint256 _amount) external onlyMoK {
        _transfer(_to, _amount);
    }

    function transferToStrategy(uint256 _amount) external onlyMoK {
        _transfer(strategy, _amount);
    }

    function _transfer(address _to, uint256 _amount) internal whenNotPaused {
        require(
            asset.balanceOf(address(this)) >= _amount,
            "VC: Inssuffient asset balance"
        );
        require(_to != address(0) && _amount > 0, "VC: Invalid inputs");
        asset.transfer(_to, _amount);
    }
}