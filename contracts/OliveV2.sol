// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IMintable} from './interfaces/IMintable.sol';
import {IOliveV2} from './interfaces/IOliveV2.sol';
import {ILendingPool} from './interfaces/ILendingPool.sol';
import {IStrategy} from './interfaces/IStrategy.sol';

import "hardhat/console.sol";

contract OliveV2 is IOliveV2 {
    using SafeMath for uint256;
    using SafeMath for uint8;

    //Address locations for each of the tokens
    address private _asset;
    address private _oToken;
    address private _strategy;
    address private _aoToken;
    address private _doToken;

    ILendingPool private _pool;

    //Olive treasury address
    address private _treasury;

    // Definition of constants
    uint256 private MAX_BPS = 10000;

    // Block
    mapping(address => uint256) private userDepositBlockStore;

    constructor(
        address asset,
        address oToken,
        address vault,
        address pool,
        address aoToken,
        address doToken
    ) {
        _asset = asset;
        _oToken = oToken;
        _strategy = vault;
        _aoToken = aoToken;
        _doToken = doToken;

        // Based on the pool address instantiate lending pool
        _pool = ILendingPool(pool);
    }

    // todo slipage - vault share condition
    function deposit(uint256 amount) external override returns (bool) {
        return _depositFor(msg.sender, amount);
    }

    // todo - avoid withdraw and deposit in the same block
    function depositWLeverage(
        uint256 _amount,
        uint8 _leverage
    ) external override returns (bool) {
        require(_amount > 0, "OLV: Zero/Negative amount");
        require((_leverage > 1 && _leverage <= 5), "OLV: No leverage");

        uint256 amountToBorrow = _leverage.sub(1).mul(_amount);

        address user = msg.sender;

        uint256 borrowed = _pool.borrow(user, amountToBorrow); //4x
        console.log(borrowed);

        uint256 totalAmount = borrowed + _amount;

        _depositFor(user, totalAmount); // At this stage user should have oToken equivalant of borrowed + amount

        require(this.hf(user) > 100, "OLV: Leverage failed");

        return true;
    }

    function _depositFor(
        address _user,
        uint amount
    ) internal returns (bool) {
        require(amount > 0, "ERC20: Zero/Negative amount");

        IERC20 asset = IERC20(_asset);
        asset.transferFrom(_user, address(this), amount);

        IMintable oToken = IMintable(_oToken);
        oToken.mint(_user, amount);

        IStrategy strategy = IStrategy(_strategy);
        asset.transfer(_strategy, amount); 

        strategy.deposit(address(this), amount); 

        bool depositedCollateral = _pool.submitCollateral(_user, amount); 
        
        require(depositedCollateral, "OLV: No collateral");

        userDepositBlockStore[_user] = block.number;
        return true;
    }

    function leverage(uint256 _toLeverage) external override returns (bool) {
        require((_toLeverage > 1 && _toLeverage <= 5), "OLV: No leverage");
        address user = msg.sender;
        uint256 _currLeverage = this.getCurrentLeverage(user);
        require(_currLeverage.div(1e2) <= 5, 'OLV: Over leveraged');

        IERC20 aoToken = IERC20(_aoToken);
        uint256 aoBalance = aoToken.balanceOf(user);

        IERC20 doToken = IERC20(_doToken);
        uint256 doTokenBalance = doToken.balanceOf(user);

        uint256 userAssets = aoBalance - doTokenBalance;

        uint256 amountToBorrow = _toLeverage.mul(1e2).sub(_currLeverage, 'OLV: Over leveraged!');
        amountToBorrow = amountToBorrow.mul(userAssets).div(1e2);

        uint256 borrowed = _pool.borrow(user, amountToBorrow); //4x
        console.log(borrowed);

        _depositFor(user, amountToBorrow); // At this stage user should have oToken equivalant of borrowed + amount

        require(this.hf(user) > 100, "OLV: Leverage failed");

        return true;
    }

    function deleverage(uint256 _shares) external override returns (bool) {
        address user = msg.sender;
        return _deleverageForUser(user, _shares);
    }

    function _deleverageForUser(address user, uint256 _shares) internal returns (bool) {
        require(_shares > 0, "OLV: Nothing to deleverage");
        require(
            userDepositBlockStore[user] != block.number,
            "OLV: Fishy transaction"
        );
        
        IERC20 doToken = IERC20(_doToken);
        uint256 doTokenBalance = doToken.balanceOf(user);
        console.log('shares: ', _shares);
        console.log('shares: ', doTokenBalance);
        require(_shares <= doTokenBalance, 'OLV: Deleverage overflow');
        
        IERC20 aoToken = IERC20(_aoToken);
        uint256 aoBalance = aoToken.balanceOf(user);
        require(_shares <= aoBalance, 'OLV: Low funds');

        uint256 _amount = _shares.mul(this.getPricePerShare(0));
        IStrategy strategy = IStrategy(_strategy);
        strategy.withdraw(user, _amount);

        _pool.repay(user, _amount, _shares, true);

        // Burn the released oTokens
        IMintable oToken = IMintable(_oToken);
        oToken.burn(user, _shares);

        require(this.hf(user) >=100, 'OLV: Health issue');
        return true;
    }

    function repay(uint256 _amount) external override returns (bool) {
        address user = msg.sender;
        return _repayForUser(user, _amount);
    }

    function _repayForUser(address user, uint256 _amount) internal returns (bool) {
        require(_amount > 0, "OLV: Nothing to deleverage");
        require(
            userDepositBlockStore[user] != block.number,
            "OLV: Fishy transaction"
        );

        uint256 _shares = _amount.div(this.getPricePerShare(0));

        IERC20 doToken = IERC20(_doToken);
        uint256 doTokenBalance = doToken.balanceOf(user);
        require(_shares <= doTokenBalance, 'OLV: Deleverage overflow');

        _pool.repay(user, _amount, _shares, false);

        require(this.hf(user) >=100, 'OLV: Health issue');
        return true;
    }


    function withdraw(uint256 _shares) external override returns (bool) {
        address user = msg.sender;
        return _withdrawForUser(user, _shares);
    }

    function _withdrawForUser(address user, uint256 _shares) internal returns (bool) {
        require(_shares > 0, "OLV: Nothing to widthdraw");
        require(
            userDepositBlockStore[user] != block.number,
            "OLV: Fishy transaction"
        );
        IERC20 aoToken = IERC20(_aoToken);
        uint256 aoBalance = aoToken.balanceOf(user);
        require(_shares <= this.getTotalWithdrawableShares(user), 'OLV: Over levered');
        require(_shares <= aoBalance, 'OLV: Shares overflow');

        IStrategy strategy = IStrategy(_strategy);
        strategy.withdraw(user, _shares); // Tokens are with user contract

        _pool.retrieveCollateral(user, _shares);

        IMintable oBurnableToken = IMintable(_oToken);
        oBurnableToken.burn(user, _shares);

        require(_pool.healthFactor(user) >= 100, "OLV: Unhealthy Position");
        return true;
    }
    
    function hf(address _user) public view returns (uint256) {
        return _pool.healthFactor(_user);
    }

    
    // List of view functions
    function getTotalWithdrawableShares(
        address _user
    ) external view override returns (uint256) {
        return _pool.getTotalSharesToWithdraw(_user);
    }

    function getPricePerShare(
        uint256 shareType
    ) external view override returns (uint256) {
        return 1;
    }

    function getCurrentLeverage(
        address _user
    ) external view override returns (uint256) {
        IERC20 aoToken = IERC20(_aoToken);
        uint256 aoBalance = aoToken.balanceOf(_user);
        console.log('ATokenBalance: ', aoBalance.div(1e8));

        IERC20 doToken = IERC20(_doToken);
        uint256 doTokenBalance = doToken.balanceOf(_user);

        if (doTokenBalance == 0) {
            return 0;
        }
        console.log('Debt: ', doTokenBalance.div(1e8));

        uint256 userAssets = aoBalance - doTokenBalance;
        console.log('Assets: ', userAssets.div(1e8));

        if (userAssets == 0) {
            return MAX_BPS;
        }

        uint256 _leverage = doTokenBalance.mul(1e2).div(userAssets).add(1e2);
        return _leverage;
    }

    function closePosition() external override returns (bool) {
        address user = msg.sender;

        IERC20 doToken = IERC20(_doToken);
        uint256 debtShares = doToken.balanceOf(user);

        _deleverageForUser(user, debtShares);

        uint256 remainingShares = this.getTotalWithdrawableShares(user);
        _withdrawForUser(user, remainingShares);

        return true;
    }
}