// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Constants} from "../lib/Constants.sol";
import {Allowed} from "../utils/Allowed.sol";
import {Governable} from "../utils/Governable.sol";

contract Olive is ERC20, Allowed, Governable{
    address public oliveMgr;
    address public keeper;
    uint256 maxSupply = Constants.OLIVE_MAX_SUPPLY;

    constructor(address _oliveMgr) ERC20("Olive Finance", "OLIVE")
     Allowed(msg.sender) Governable(msg.sender) {
        oliveMgr = _oliveMgr;
        keeper = msg.sender;
    }

    modifier onlyMoK() {
        require(msg.sender == keeper || msg.sender == oliveMgr, "Olive: Unauthorized");
        _; 
    }

    function setKeeper(address _keeper) external onlyOwner {
        require(_keeper != address(0) && _keeper != address(this), "Olive: Invalid keeper");
        keeper = _keeper;
    }

    function setOliveManager(address _oliveMgr) external onlyOwner {
        require(_oliveMgr != address(0) && _oliveMgr != address(this), "Olive: Invalid Manager");
        oliveMgr = _oliveMgr;
    }

    function mint(address user, uint256 amount) external onlyMoK returns (bool) {
        require(totalSupply() + amount <= maxSupply, "Olive: Exceeding total supply");
        _mint(user, amount);
        return true;
    }

    function burn(address user, uint256 amount) external onlyMoK returns (bool) {
        require(balanceOf(user) >= amount, "Olive: Insufficient balance");
        _burn(user, amount);
        return true;
    }
}