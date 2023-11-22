// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {IDToken} from '../pools/interfaces/IDToken.sol';

import {Allowed} from '../utils/Allowed.sol';

contract DToken is ERC20, Allowed, IMintable, IDToken {

    uint8 precision = 18;

    // This is the mapping to store the information of debt per vault
    mapping(address => mapping(address => uint256)) public debtPerVault;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _precision
    ) ERC20(_name, _symbol) Allowed(msg.sender) {
        precision = _precision;
    }

    function decimals() public view virtual override returns (uint8) {
        return precision;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override {
        revert("DToken: Debt can't be transferred");
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

    function mintuv(
        address _vault,
        address _user,
        uint256 _amount
    ) external override onlyAllowed returns (bool) {
        require(_amount > 0, "ERC20: Invalid amount");
        _mint(_user, _amount);
        debtPerVault[_vault][_user] += _amount;
        emit Mint(msg.sender, _user, _amount);
        return true;
    }

    function burnuv(
        address _vault,
        address _user,
        uint256 _amount
    ) external override onlyAllowed returns (bool) {
        require(_amount > 0, "ERC20: Invalid amount");
        require(balanceOf(_user) >= _amount, "ERC20: Insufficient balance");
        require(debtPerVault[_vault][_user] >= _amount, "ERC20: Insufficient debt");
        _burn(_user, _amount);
        debtPerVault[_vault][_user] -= _amount;
        emit Burn(msg.sender, _user, _amount);
        return true;
    }

    function debtOf(address _vault, address _user) external override view returns (uint256) {
        return debtPerVault[_vault][_user];
    }
}
