// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';

import {IMintable} from '../interfaces/IMintable.sol';

import {Allowed} from '../interfaces/Allowed.sol';

import "hardhat/console.sol";

contract Token is IERC20, IERC20Metadata, IMintable, Allowed {
    using SafeMath for uint256;

    // Token storable information
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    // Token metadata
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory n, string memory s, uint8 d) Allowed(msg.sender) {
        _name = n;
        _symbol = s;
        _decimals = d;
        _totalSupply = 0;
    }

    function transfer(
        address _to,
        uint256 _amount
    ) external override returns (bool) {
        require(false, "ERC20: Debt tokens are non-trasferable");
        return true;
    }

    function approve(
        address _spender,
        uint256 _amount
    ) external override returns (bool) {
        require(_spender != address(0), "ERC20: Null address");
        require(_amount > 0, "ERC20: Zero/Negative amount");
        address from = msg.sender;
        _allowances[from][_spender] += _amount;
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external override returns (bool) {
        require(false, "ERC20: Debt tokens are non-trasferable");
    }

    function mint(
        address _to,
        uint256 _amount
    ) external override onlyAllowed returns (bool) {
        require(_to != address(0), 'ERC20: Null address');
        require(_amount > 0, 'ERC20: Zero/Negative amount');
        _totalSupply += _amount;
        _balances[_to] = _balances[_to].add(_amount);
        return true;
    }

    function burn(
        address _from,
        uint256 _amount
    ) external override onlyAllowed  returns (bool) {
        require(_from != address(0), 'ERC20: Null address');
        require(_amount > 0, 'ERC20: Zero/Negative amount');
        _balances[_from] = _balances[_from].sub(_amount, 'ERC20: Insufficient balance');
        _totalSupply = _totalSupply.sub(_amount, 'ERC20: Insufficient balance');
        return true;
    }

    /**
     * View functions
     */

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address _account
    ) external view override returns (uint256) {
        return _balances[_account];
    }

    function allowance(
        address _owner,
        address _spender
    ) external view override returns (uint256) {
        return _allowances[_owner][_spender];
    }
}
