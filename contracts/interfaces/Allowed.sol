// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


contract Allowed{

    // Token managers information
    address private _ownerAddr;
    mapping(address => bool) private _allowed;

    constructor(address owner) {
        _ownerAddr = owner;
        _allowed[owner] = true;
    }

    /**
     * Modifier functions
     */
    modifier onlyOwner() {
        require(msg.sender == _ownerAddr, "ERC20: Not an owner");
        _;
    }

    modifier onlyAllowed() {
        require(_allowed[msg.sender], "ERC20: Insufficient privilages");
        _;
    }

    /**
     * List of setter functions  
     */
    function setOwner(address _owner) public onlyOwner returns (bool) {
        _ownerAddr = _owner;
        return true;
    }

    function grantRole(address _user) public onlyOwner returns (bool) {
        _allowed[_user] = true;
        return true;
    }

    function revokeRole(address _user) public onlyOwner returns (bool) {
        _allowed[_user] = false;
        return true;
    }

    function getOwner() public view returns(address) {
        return _ownerAddr;
    }

    function isAllowed(address user) public view returns (bool) {
        return _allowed[user];
    }
}