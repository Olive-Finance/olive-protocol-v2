// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IVaultCore {
    function getPPS() external view returns (uint256);
    function getHFThreshold() external view returns (uint256);
    function getMinLeverage() external view returns (uint256);
    function getMaxLeverage() external view returns (uint256);
    function getLiquidationThreshold() external view returns (uint256);
    function getAssetToken() external view returns (address);
    function getLedgerToken() external view returns (address);
    function getLendingPool() external view returns (address);
    function getStrategy() external view returns (address);
    function totalDeposits() external view returns (uint256);

    function mintShares(address _user, uint256 _amount) external;
    function burnShares(address _user, uint256 _amount) external;
    function transferAsset(address _to, uint256 _amount) external;

    // Buy function would be specific for the type of vault
    function buy(address _tokenIn, uint256 _amount) external returns (uint256);
    function sell(address _tokenOut, uint256 _amount) external returns (uint256);

    // Price of asset
    function priceOfAsset() external view returns (uint256);

    // Asset value 
    function getTokenValueInAsset(address _token, uint256 _tokenValue) external view returns (uint256);
    function getTokenValueforAsset(address _token, uint256 _tokenValue) external view returns (uint256);

    // The values are always given in terms of Asset
    function getPosition(address _user) external view returns (uint256);
    function getDebt(address _user) external view returns (uint256);
    function getCollateral(address _user) external view returns (uint256);

    function hf(address _user) external view returns (uint256);
    function isHealthy(address _user) external view returns (bool);

    function blockNumber() external view returns (uint256);
}