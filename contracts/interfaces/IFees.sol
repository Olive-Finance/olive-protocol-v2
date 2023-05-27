// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IFees {

    function computePerfFees(address _token, uint256 _amount) external view returns (uint256);

    function computeMngtFees(address _token, uint256 _amount) external view returns (uint256);

    function computeLdtyFees(address _token, uint256 _amount) external view returns (uint256);

    function setPerfFee() external returns (bool);

    function setMngtFee() external returns (bool);

    function setLdtyFee() external returns (bool);

    function mintFees(address _token, uint256 _toMint) external returns (bool);
}

