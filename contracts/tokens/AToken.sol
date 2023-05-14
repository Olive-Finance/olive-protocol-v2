// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IMintable} from '../interfaces/IMintable.sol';

contract AToken is IERC20, IERC20Metadata, IMintable {

    using SafeMath for uint256;

    // Token storable information
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    // Token managers information
    address private _ownerAddr;
    mapping(address => bool) private _allowed;

    // Token metadata
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory n, string memory s, uint8 d) {
        _name = n;
        _symbol = s;
        _decimals = d;

        _ownerAddr = msg.sender;
        _allowed[_ownerAddr] = true;
        _totalSupply = 0;
    }

    /**
     * Transfer functions
     */

    // todo - Add events

    function transfer(
        address _to,
        uint256 _amount
    ) external override returns (bool) {
        address from = msg.sender;
        return _transfer(from, _to, _amount);
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
        address spender = msg.sender;
        _allowances[_from][spender] = _allowances[_from][spender].sub(
            _amount,
            "ERC20: Insufficient allowance"
        );
        return _transfer(_from, _to, _amount);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (bool) {
        require(_to != address(0), "ERC20: Null address");
        require(_amount > 0, "ERC20: Zero/Negative amount");
        _balances[_from] = _balances[_from].sub(
            _amount,
            "ERC20: Insufficient Balance"
        );
        _balances[_to] = _balances[_to].add(_amount);
        return true;
    }

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

