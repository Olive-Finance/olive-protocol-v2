// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import {IFees} from "./interfaces/IFees.sol";

import {Allowed} from "../interfaces/Allowed.sol";

contract Fees is IFees, Allowed {
    constructor() Allowed(msg.sender) {} 

    function computePerfFees(address _token, uint256 _amount) external view override returns (uint256) {}

    function computeMngtFees(address _token, uint256 _amount) external view override returns (uint256) {}

    function computeLdtyFees(address _token, uint256 _amount) external view override returns (uint256) {}

    function setPerfFee() external override returns (bool) {}

    function setMngtFee() external override returns (bool) {}

    function setLdtyFee() external override returns (bool) {}

    function mintFees(address _token, uint256 _toMint) external override returns (bool) {}
}