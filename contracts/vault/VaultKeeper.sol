// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Allowed} from "../utils/Allowed.sol";
import {Constants} from "../lib/Constants.sol";
import {Governable} from "../utils/Governable.sol";

import {IStrategy} from "../strategies/interfaces/IStrategy.sol";
import {IVaultCore} from "./interfaces/IVaultCore.sol";
import {IVaultManager} from "./interfaces/IVaultManager.sol";
import {ILendingPool} from "../pools/interfaces/ILendingPool.sol";
import {IFees} from "../fees/interfaces/IFees.sol";
import {IVaultKeeper} from "../vault/interfaces/IVaultKeeper.sol";

contract VaultKeeper is IVaultKeeper, Allowed, Governable {
    IVaultCore public vaultCore;
    IVaultManager public vaultManager;
    IFees public fees;

    // Allowed keepers
    mapping(address => bool) public liquidators;

    // Empty constructor
    constructor() Allowed(msg.sender) Governable(msg.sender) {}

    modifier onlyLiquidator() {
        require(liquidators[msg.sender], "VK: Not authorised");
        _;
    }

    function setVaultCore(address _vaultCore) external onlyOwner {
        require(
            _vaultCore != address(0) && _vaultCore != address(this),
            "VK: Invalid core"
        );
        vaultCore = IVaultCore(_vaultCore);
    }

    function setVaultManager(address _vaultManager) external onlyOwner {
        require(
            _vaultManager != address(0) && _vaultManager != address(this),
            "VK: Invalid core"
        );
        vaultManager = IVaultManager(_vaultManager);
    }

    function setLiquidator(address _liquidator, bool toActivate) external onlyGov {
        require(_liquidator != address(0), "VK: Invalid keeper");
        liquidators[_liquidator] = toActivate;
        emit LiquidatorChanged(_liquidator, toActivate, block.timestamp);
    }
    
    function setFees(address _fees) external onlyOwner {
        require(_fees != address(0) && _fees != address(this), "VM: Invalid fees");
        fees = IFees(_fees);
    }

    function harvest() external override {
        computeFees();
        IStrategy strategy = IStrategy(vaultCore.getStrategy());
        strategy.harvest();
    }

    function liquidation(address _user, uint256 _toRepay, bool _toStake) external onlyLiquidator {
        address liquidator = msg.sender;
        // position check
        require(!vaultCore.isHealthy(_user), "VK: Position is healthy");

        // pool transfer check
        ILendingPool pool = ILendingPool(vaultCore.getLendingPool());
        IERC20 want = IERC20(pool.wantToken());
        require(want.allowance(liquidator, address(pool)) >= _toRepay, "VK: Insufficient allowance to pool");
        
        // Getting the debt in want
        uint256 debt = pool.getDebt(_user);
        uint256 debtInAsset = vaultCore.getDebt(_user);
        uint256 position = vaultCore.getPosition(_user);
        uint256 positionInWant = vaultCore.getTokenValueforAsset(address(want), position);
        uint256 toLiquidator;
        uint256 toTreasury;

        if (position > debtInAsset) {
            (toLiquidator, toTreasury) = handleExcess(liquidator, _user, debt, position, _toRepay, address(want));
        } else {
            toLiquidator = handleBadDebt(liquidator, _user, position, positionInWant, _toRepay);
        }
        _transfer(liquidator, _toShares(toLiquidator), _toStake);
        if (toTreasury > 0) {
            _transfer(fees.getTreasury(), _toShares(toTreasury), true);
        }
    }

    function handleExcess(address _liquidator, address _user, uint256 _debtInWant, uint256 _position, uint256 _toRepay, address _want) internal returns (uint256, uint256) {
        uint256 toPay = min(_debtInWant, _toRepay);
        uint256 toPayInAsset = vaultCore.getTokenValueInAsset(_want, toPay);
        uint256 feeInAsset = (toPayInAsset * fees.getLiquidationFee())/Constants.HUNDRED_PERCENT;
        uint256 liquidatorFee;

        if (_position - toPayInAsset < feeInAsset) {
            feeInAsset = _position - toPayInAsset;
        } 
        vaultCore.burnShares(_user, _toShares(feeInAsset + toPayInAsset));
        _repay(_liquidator, _user, toPay, 0);
        liquidatorFee = (feeInAsset * fees.getLiquidatorFee())/Constants.HUNDRED_PERCENT;
        return (toPayInAsset + liquidatorFee, feeInAsset - liquidatorFee);
    }

    function handleBadDebt(address _liquidator, address _user, uint256 _position, uint256 _positionInWant, uint256 _toRepay) internal returns (uint256) {
        uint256 toPay = min(_positionInWant, _toRepay);
        uint256 toTransfer = (_position * toPay) / _positionInWant;
        uint256 sFactor = (toTransfer * Constants.PINT) / _position; // sFactor - is settlement factor
        vaultCore.burnShares(_user, _toShares(toTransfer));
        _repay(_liquidator, _user, toPay, sFactor);
        return toTransfer;
    }

    function _toShares(uint256 _amount) internal view returns (uint256) {
        return (_amount * Constants.PINT) / vaultCore.getPPS();
    }

    function _transfer(address _liquidator, uint256 _shares, bool _toStake) internal {
        if (_toStake) {
            vaultCore.mintShares(_liquidator, _shares);
            return;
        }
        computeFees();
        uint256 sold = IStrategy(vaultCore.getStrategy()).withdraw(address(vaultCore), _shares);
        vaultCore.transferAsset(_liquidator, sold);
    }

    function _repay(address _liquidator, address _user, uint256 _amount, uint256 _sFactor) internal {
        ILendingPool pool = ILendingPool(vaultCore.getLendingPool());
        if (_sFactor > 0) {
             pool.repayWithSettle(_liquidator, address(vaultCore), _user, _amount, _sFactor);
        } else {
            pool.repay(_liquidator, address(vaultCore), _user, _amount);
        }
    }

    function min(uint256 x, uint256 y) internal returns (uint256) {
        return x>y?y:x;
    }

    function computeFees() public {
        uint256 newFee = (vaultManager.balance() * fees.getMFee() * 
        (block.timestamp - fees.getLastUpdatedAt())) / (Constants.HUNDRED_PERCENT * Constants.YEAR_IN_SECONDS);
        fees.setFee(fees.getAccumulatedFee() + newFee, block.timestamp);
    }
}