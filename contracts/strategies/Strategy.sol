// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IStrategy} from '../interfaces/IStrategy.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {Allowed} from '../utils/modifiers/Allowed.sol';

contract Strategy is IStrategy, Allowed {
    //List of addresses
    address private _asset;
    address private _lpToken;

    address private _treasury;

    struct StrategyStorage {
        uint256 _totalFreeFunds;
        uint256 _totalLPFunds;
    }

    StrategyStorage private store;

    constructor(
        address asset,
        address lpToken,
        address treasury
    ) Allowed(msg.sender) {
        _asset = asset;
        _lpToken = lpToken;
        _treasury = treasury;
        store._totalFreeFunds = 0;
        store._totalLPFunds = 0;
    }

    function deposit(address _user, uint256 _amount) external override {
        require(_user != address(0), "Strat: Null address");
        require(_amount > 0, "STR: Zero/Negative amount");

        IMintable lpToken = IMintable(_lpToken);
        lpToken.mint(_user, _amount);
    }

    function withdraw(
        address _user,
        uint256 _amount
    ) external override returns (uint256) {
        // todo Withdraw - for shares, lp token
        // todo Deposit - lp token - Single strategy valut
        // user, valut, strategy address
        // todo Check around on the security point of view

        require(_amount > 0, "STR: Zero/Negative amount");

        address _depositor = msg.sender; // Olive address as it will be calling the deposit function

        IERC20 lpToken = IERC20(_lpToken); // strategy shares
        uint256 tokenBalance = lpToken.balanceOf(_depositor);

        require(tokenBalance >= _amount, "STR: Insufficient balance");

        IMintable lpBurnToken = IMintable(_lpToken);
        lpBurnToken.burn(_depositor, _amount);

        IERC20 asset = IERC20(_asset); // Transfer the amount
        asset.transfer(_user, _amount);

        return _amount;
    }

    function harvest() external override {}
}