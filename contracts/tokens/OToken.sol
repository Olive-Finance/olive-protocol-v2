// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IMintable} from '../interfaces/IMintable.sol';

import {Allowed} from '../utils/Allowed.sol';

contract OToken is ERC20, Allowed, IMintable {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Allowed(msg.sender) {}

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

    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal virtual override {
        // todo add the hf check for transfer
    }
}
