// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

interface IAssetManager { 
    function exchangeValue(address _from, address _to, uint256 _amount) external view returns (uint256);

    function addLiquidityForAccount(address _user, address _asset, uint256 _value) external returns (uint256);

    function removeLiquidityForAccount(address _user, address _asset, uint256 _value) external returns (uint256);
}