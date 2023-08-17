// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {IVaultCore} from '../vault/interfaces/IVaultCore.sol';

import {Allowed} from '../utils/Allowed.sol';

contract OToken is ERC20, Allowed, IMintable {
    IVaultCore public vaultCore;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Allowed(msg.sender) {}

    function setVaultCore(address _vaultCore) external onlyOwner {
        require(_vaultCore != address(0), "OToken: Invalid vault core address");
        vaultCore = IVaultCore(_vaultCore);
    }

    function mint(
        address _user,
        uint256 _amount
    ) external override onlyAllowed returns (bool) {
        require(_amount > 0, "ERC20: Invalid amount");
        _mint(_user, _amount);
        emit Mint(msg.sender, _user, _amount);
        return true;
    }

    function burn(
        address _user,
        uint256 _amount
    ) external override onlyAllowed returns (bool) {
        require(_amount > 0, "ERC20: Invalid amount");
        require(balanceOf(_user) >= _amount, "ERC20: Insufficient balance");
        _burn(_user, _amount);
        emit Burn(msg.sender, _user, _amount);
        return true;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        require(vaultCore.isHealthy(owner), "OToken: unhealthy position");
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        require(vaultCore.isHealthy(from), "OToken: unhealthy position");
        return true;
    }

}
