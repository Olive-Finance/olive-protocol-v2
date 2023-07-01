// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

interface IMintable {
    // function definitions
    function mint(address _user, uint256 _amount) external returns (bool);
    function burn(address _user, uint256 _amount) external returns (bool); 

    //events 
    event Minted(address _caller, address indexed _user, uint256 _amount);
    event Burned(address _caller, address indexed _user, uint256 _amount);
}