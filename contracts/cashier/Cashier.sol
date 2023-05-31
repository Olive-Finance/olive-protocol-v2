// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ICashier} from '../interfaces/ICashier.sol';
import {ILendingPool} from '../interfaces/ILendingPool.sol';
import {Allowed} from '../utils/modifiers/Allowed.sol';
import {IOlive} from '../interfaces/IOlive.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {IStrategy} from '../interfaces/IStrategy.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IAssetManager} from '../interfaces/IAssetManager.sol';

import "hardhat/console.sol";

contract Cashier is ICashier, Allowed {
    IOlive private _vault;

    constructor() Allowed(msg.sender) {}

    function setVault(address vault) public onlyAllowed returns (bool) {
        require(vault != address(0), "CSH: Invalid valult");
        _vault = IOlive(vault);
        return true;
    }

    function deleverage(uint8 _toLeverage) external override returns (bool) {}

    function repay(
        address _debtToken,
        uint256 _amount
    ) external override returns (bool) {}

    function withdraw(uint256 _shares) external override returns (bool) {}
}