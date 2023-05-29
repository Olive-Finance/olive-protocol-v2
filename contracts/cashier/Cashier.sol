// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ICashier} from '../interfaces/ICashier.sol';
import {ILendingPool} from '../interfaces/ILendingPool.sol';
import {Allowed} from '../utils/modifiers/Allowed.sol';
import {IOliveV2} from '../interfaces/IOliveV2.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {IStrategy} from '../interfaces/IStrategy.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {ILPManager} from '../interfaces/ILPManager.sol';

import "hardhat/console.sol";

contract Cashier is ICashier, Allowed {
    IOliveV2 private _vault;

    constructor() Allowed(msg.sender) {}

    function setVault(address vault) public onlyAllowed returns (bool) {
        require(vault != address(0), "CSH: Invalid valult");
        _vault = IOliveV2(vault);
        return true;
    }

    function deleverage(uint8 _toLeverage) external override returns (bool) {}

    function repay(
        address _debtToken,
        uint256 _amount
    ) external override returns (bool) {}

    function withdraw(uint256 _shares) external override returns (bool) {}
}