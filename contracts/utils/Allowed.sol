// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Allowed is Pausable, ReentrancyGuard {

    // Token managers information
    address public ownerAddr;
    mapping(address => bool) public allowed;

    constructor(address owner) Pausable() ReentrancyGuard() {
        ownerAddr = owner;
        allowed[owner] = true;
    }

    function enable(bool en) external {
        if (en) {
            _pause();
        } else {
            _unpause();
        }
    }

    /**
     * Modifier functions
     */
    modifier onlyOwner() {
        require(msg.sender == ownerAddr, "ALW: Not an owner");
        _;
    }

    modifier onlyAllowed() {
        require(allowed[msg.sender], "ALW: Insufficient privilages");
        _;
    }

    /**
     * List of setter functions  
     */
    function setOwner(address _owner) external onlyOwner returns (bool) {
        ownerAddr = _owner;
        return true;
    }

    function grantRole(address _user) external onlyOwner returns (bool) {
        allowed[_user] = true;
        return true;
    }

    function revokeRole(address _user) external onlyOwner returns (bool) {
        allowed[_user] = false;
        return true;
    }
}