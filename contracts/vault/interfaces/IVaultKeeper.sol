// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IVaultKeeper {
    function harvest() external;
    function liquidation(address _user) external;
}