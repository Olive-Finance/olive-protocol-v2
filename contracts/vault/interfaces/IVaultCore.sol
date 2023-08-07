// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IVaultCore {
    function getPPS() external view returns (uint256);
    function getHFThreshold() external view returns (uint256);
    function getMinLeverage() external view returns (uint256);
    function getMaxLeverage() external view returns (uint256);
    function getLiquidationThreshold() external view returns (uint256);
    function getTreasury() external view returns (address);
    function getAssetToken() external view returns (address);
    function getLedgerToken() external view returns (address);
    function getLendingPool() external view returns (address);
    function getStrategy() external view returns (address);
    function totalDeposits() external view returns (uint256);

    function setPPS(uint256 _pps) external; 
    function mintShares(address _user, uint256 _amount) external;
    function burnShares(address _user, uint256 _amount) external;
    function transferAsset(address _to, uint256 _amount) external;
    function transferToStrategy(uint256 _amount) external;
}