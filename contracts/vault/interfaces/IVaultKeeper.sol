// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IVaultKeeper {
    function harvest() external;
    function liquidation(address _user, uint256 _toRepay, bool _toStake) external;

    event LiquidatorChanged(address indexed _liquidator, bool indexed status, uint256 indexed timestamp);
}