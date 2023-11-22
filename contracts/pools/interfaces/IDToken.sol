// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IDToken {
    // function to get the balance of debt of given vault
    function debtOf(address _user, address _vault) external view returns (uint256);
    function mintuv(address _vault, address _user, uint256 _amount) external returns (bool);
    function burnuv(address _vault, address _user, uint256 _amount) external returns (bool);
}