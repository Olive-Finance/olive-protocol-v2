// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IFees {
    // functions
    function setTreasury(address _treasury) external;
    function setPFee(uint256 _pFee) external;
    function setMFee(uint256 _mFee) external;
    function setKeeperFee(uint256 _keeperFee) external;
    function setLiquidationFee(uint256 _liquidationFee) external;

    // view functions
    function getTreasury() external view returns (address);
    function getPFee() external view returns (uint256);
    function getMFee() external view returns (uint256);
    function getKeeperFee() external view returns (uint256);
    function getLiquidationFee() external view returns (uint256);

    event TreasuryChanged(address indexed _treasury);
}