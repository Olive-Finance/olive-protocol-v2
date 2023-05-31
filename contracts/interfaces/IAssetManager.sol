// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IAssetManager { 
    function getPrice(address _asset, uint256 _value) external view returns (uint256);

    function getBurnPrice(address _asset, uint256 _value) external view returns (uint256);

    function addLiquidityForAccount(address _user, address _asset, uint256 _value) external returns (uint256);

    function removeLiquidityForAccount(address _user, address _asset, uint256 _value) external returns (uint256);
}