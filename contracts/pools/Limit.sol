// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {Allowed} from "../utils/Allowed.sol";
import {Governable} from "../utils/Governable.sol";
import {ILimit} from "./interfaces/ILimit.sol";

contract Limit is ILimit, Allowed, Governable {
    address public pool;
    mapping(address => uint256) public limit;
    mapping(address => bool) public isBlackListed;

    constructor ()  Allowed(msg.sender) Governable(msg.sender) {}

    function setPool(address _pool) external onlyOwner {
        require(_pool != address(0), "LMT: Invalid pool address");
        pool = _pool;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "LMT: Invalid previlages");
        _;
    }
    
    function setLimit(address _to, uint256 _limit) onlyOwner external override {
        require(_to != address(0) && _to != address(this), "LMT: Invalid Addresss");
        limit[_to] = _limit;
        emit SetLimit(msg.sender, _to, _limit); 
    }

    function consumeLimit(address _to, uint256 _amount) onlyPool external override {
        require(limit[_to] >= _amount, "LMT: Insufficient limit");
        limit[_to] -= _amount;
    }

    function enhaceLimit(address _to, uint256 _amount) onlyPool external override {
        limit[_to] += _amount;
    }

    function setBlackList(address _to, bool _isBlackListed) onlyGov external override {
        require(_to != address(0) && _to != address(this), "LMT: Invalid Address");
        isBlackListed[_to] = _isBlackListed;
        emit SetBlackList(msg.sender, _to, _isBlackListed);
    }

    function isBlackList(address _to) external view override returns (bool) {
        return isBlackListed[_to];
    }

    function getLimit(address _to) external view override returns (uint256) {
        return limit[_to];
    }
}