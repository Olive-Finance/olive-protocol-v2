// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {ERC20Votes, ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Governable} from "../utils/Governable.sol";
import {IRewardManager} from "../interfaces/IRewardManager.sol";

import {Constants} from "../lib/Constants.sol";

contract esOLIVE is ERC20Votes, Governable {
    mapping(address => bool) public esOLIVEMinter;
    IRewardManager public oliveMgr;

    uint256 maxMinted = Constants.ESOLIVE_MAX_EMISSION;
    uint256 public totalMinted;

    constructor(address _oliveMgr) ERC20Permit("esOLIVE") 
    ERC20("Escrow Olive Token", "esOLIVE") Governable(msg.sender){
        oliveMgr = IRewardManager(_oliveMgr);
    }
    
     modifier onlyAllowed(){
        address caller = msg.sender;
        require(caller == address(oliveMgr) || esOLIVEMinter[caller] == true,"esOLIVE: not authorized");
        _;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        revert("not authorized");
    }

    function setMinter(address[] calldata _contracts, bool[] calldata _bools) external onlyGov {
        for (uint256 i = 0; i < _contracts.length; i++) {
            esOLIVEMinter[_contracts[i]] = _bools[i];
        }
    }

    function setOliveManager(address _oliveMgr) external onlyGov {
        require(_oliveMgr != address(0), "esOLIVE: Invalid oliveManager address");
        oliveMgr = IRewardManager(_oliveMgr);
    }

    function mint(address _user, uint256 _amount) external onlyAllowed returns (bool) {
        address caller = msg.sender;
        uint256 reward = _amount; 
        if (caller != address(oliveMgr)) {
            oliveMgr.refreshReward(_user);
            if (totalMinted + reward > maxMinted) {
                reward = maxMinted - totalMinted;
            }
            totalMinted += reward;
        }
        _mint(_user, reward);
        return true;
    }

    function burn(address _user, uint256 _amount) external onlyAllowed returns (bool) {
        address caller = msg.sender;
             require(balanceOf(_user) >= _amount, "esOLIVE: Insufficient balance");
        if (caller != address(oliveMgr)) { // todo check any contract is calling this in any usecase
            oliveMgr.refreshReward(_user);
        }
        _burn(_user, _amount);
        return true;
    }
}
