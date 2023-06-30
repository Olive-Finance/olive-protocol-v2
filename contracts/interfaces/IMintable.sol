// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

interface IMintable {
    function mint(address _to, uint256 _amount) external returns (bool);

    function burn(address _from, uint256 _amount) external returns (bool); 
}