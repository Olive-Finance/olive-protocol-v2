// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IMintable {
    // function definitions
    function mint(address _user, uint256 _amount) external returns (bool);
    function burn(address _user, uint256 _amount) external returns (bool);

    //events 
    event Mint(address indexed _caller, address indexed _user, uint256 _amount);
    event Burn(address indexed _caller, address indexed _user, uint256 _amount);
}