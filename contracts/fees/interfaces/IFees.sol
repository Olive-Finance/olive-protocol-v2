// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IFees {
    // functions
    function setTreasury(address _treasury) external;
    function setPFee(uint256 _pFee) external;
    function setMFee(uint256 _mFee) external;
    function setLiquidationFee(uint256 _liquidationFee) external;
    function setLiquidatorFee(uint256 _liquidatorFee) external;
    function setFee(uint256 _fee, uint256 _updatedAt) external;
    function setRewardRateForOliveHolders(uint256 _rewardRate) external;
    function setYieldFeeLimit(uint256 _yieldFeeLimit) external;

    // view functions
    function getTreasury() external view returns (address);
    function getPFee() external view returns (uint256);
    function getMFee() external view returns (uint256);
    function getLiquidationFee() external view returns (uint256);
    function getLiquidatorFee() external view returns (uint256);
    function getLiquidationTreasuryFee() external view returns (uint256);
    function getAccumulatedFee() external view returns (uint256);
    function getLastUpdatedAt() external view returns (uint256);
    function getRewardRateForOliveHolders() external view returns (uint256);
    function getYieldFeeLimit() external view returns (uint256);

    event TreasuryChanged(address indexed _treasury);
}