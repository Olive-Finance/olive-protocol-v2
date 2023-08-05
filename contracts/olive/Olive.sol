// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Constants} from "../lib/Constants.sol";
import {Allowed} from "../utils/Allowed.sol";

contract Olive is ERC20, Allowed {
    address public oliveMgr;
    uint256 maxSupply = Constants.OLIVE_MAX_SUPPLY;

    constructor(address _oliveMgr) ERC20("OliveFinance Token", "OLV") Allowed(msg.sender) {
        oliveMgr = _oliveMgr;
    }

    function setOliveManager(address _oliveMgr) external onlyOwner {
        oliveMgr = _oliveMgr;
    }

    function mint(address user, uint256 amount) external returns (bool) {
        require(msg.sender == oliveMgr, "Olive: Only OliveManager authorised");
        require(totalSupply() + amount <= maxSupply, "Olive: Exceeding total supply");
        _mint(user, amount);
        return true;
    }

    function burn(address user, uint256 amount) external returns (bool) {
        require(msg.sender == oliveMgr, "Olive: Only OliveManager authorised");
        require(balanceOf(user) >= amount, "Olive: Insufficient balance");
        _burn(user, amount);
        return true;
    }
}