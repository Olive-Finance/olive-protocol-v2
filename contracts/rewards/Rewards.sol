// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IFees} from '../fees/interfaces/IFees.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {IPriceHelper} from '../helper/interfaces/IPriceHelper.sol';
import {IRewards} from './interfaces/IRewards.sol';

import {Allowed} from '../utils/Allowed.sol';
import {Constants} from '../lib/Constants.sol';


contract Rewards is IRewards, Allowed {
    address[] public rewardTokens; // ERC20 reward tokens
    IMintable public orToken; //Olive reward token
    mapping(address => uint256) balances; // to validate token trasfer from notifier
    IPriceHelper public priceHelper;
    IFees public fees;
    address public stableToken;
    
    // empty constructor
    constructor() Allowed(msg.sender) {}

    function setPriceHelper(address _helper) external onlyOwner {
        require(_helper != address(0), "RWDS: Invalid address");
        priceHelper = IPriceHelper(_helper);
    }

    function setFees(address _fees) external onlyOwner {
        require(_fees != address(0), "RWDS: Incalid address");
        fees = IFees(fees);
    }

    function setTokens(address _orToken, address _stableToken) external onlyOwner {
        require(_orToken != address(0) && _stableToken != address(0), "RWDS: Invalid address");
        orToken = IMintable(_orToken);
        stableToken = _stableToken;
    }

    function addToken(address _token) external onlyOwner {
        require(_token != address(0) && _token != address(this), "RWDS: Invalid address");
        rewardTokens.push(_token);
    }
    
    function removeToken(uint index) external onlyOwner {
        require(balances[rewardTokens[index]] == 0, "RWDS: Nonzero balance");
        require(index <= rewardTokens.length -1, "RWDS: index out of bounds");
        rewardTokens[index] = rewardTokens[rewardTokens.length - 1];
        rewardTokens.pop();
    }

    function getTokenLength() external view returns (uint256) {
        return rewardTokens.length ;
    }

    function totalRewards() public view returns (uint256) {
        uint256 result;
        for (uint i = 0; i < rewardTokens.length; i++) {
            result += (IERC20(rewardTokens[i]).balanceOf(address(this)) * priceHelper.getPriceOf(rewardTokens[i]))/Constants.PINT;
        }
        return result;
    }

    function notifyReward(address _token, uint256 _amount) external override onlyAllowed whenNotPaused nonReentrant {
        require(_token != address(0) && _amount > 0, "RWDS: Invalid");
        require((IERC20(_token).balanceOf(address(this)) - balances[_token]) >= _amount, "RWDS: No tokens");
        uint256 toMint = (_amount * priceHelper.getPriceOf(_token)) / Constants.PINT;
        balances[_token] += _amount;
        orToken.mint(fees.getTreasury(), (toMint * fees.getPFee())/Constants.PINT);
        orToken.mint(msg.sender, (toMint * (Constants.HUNDRED_PERCENT - fees.getPFee()))/Constants.PINT);
        emit Reward(msg.sender, _token, _amount);
    }

    function convertTo(address _from, address _to) external override returns (uint256) {
        // todo swapping
    }

    function exchangeTo(address _token, uint256 _shares) external override {
        require(_shares > 0 && _token != address(0), "RWS: Invalid input/s");
        _exchange(msg.sender, _token, _shares);
    }

    function exchange(uint256 _shares) external override {
        require(_shares > 0, "RWS: Invalid input");
        _exchange(msg.sender, stableToken, _shares);
    }

    function _exchange(address _user, address _token, uint256 _shares) internal whenNotPaused nonReentrant {
        uint256 amount = (_shares * this.getPrice()) / Constants.PINT;
        uint256 _toTrasfer = (amount * Constants.PINT) / priceHelper.getPriceOf(_token);
        IERC20 token = IERC20(_token);
        require(token.balanceOf(address(this)) >= _toTrasfer, "RWS: Insufficient balance");
        orToken.burn(_user, _shares);
        balances[_token] -= _toTrasfer;
        token.transfer(_user, _toTrasfer);
        emit Exchanged(_user, stableToken, amount);
    }

    function getPrice() external view override returns(uint256) {
        uint256 rTotalSupply = IERC20(address(orToken)).totalSupply();
        if ( rTotalSupply == 0) {
            return Constants.PINT;
        }
        return (totalRewards() * Constants.PINT) / rTotalSupply;
    }
}