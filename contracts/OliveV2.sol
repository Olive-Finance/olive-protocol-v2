// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IMintable} from './interfaces/IMintable.sol';
import {IOliveV2} from './interfaces/IOliveV2.sol';
import {ILendingPool} from './interfaces/ILendingPool.sol';
import {IStrategy} from './interfaces/IStrategy.sol';
import {Allowed} from './utils/modifiers/Allowed.sol';
import {IGLPManager} from './interfaces/IGLPManager.sol';

import "hardhat/console.sol";

contract OliveV2 is IOliveV2, Allowed {
    using SafeMath for uint256;
    using SafeMath for uint8;

    //Address locations for each of the tokens
    address private _asset;
    address private _oToken;
    address private _doToken;

    //Address for strategy
    address private _strategy;

    //Address for GLP Manager
    address private _glpManager;

    //Olive treasury address
    address private _treasury;

    // Definition of constants
    uint256 private MAX_BPS = 10000;

    // Block
    mapping(address => uint256) private userDepositBlockStore;

    ILendingPool[] private _pools;
    mapping(address => bool) private _enabledPools;
    mapping(address => address) private _debtTokenPoolMap;

    //Vault variables
    uint256 private _totalCollateral;

    constructor(
        address asset,
        address oToken,
        address strategy,
        address glpManager

    ) Allowed(msg.sender) {
        _asset = asset;
        _oToken = oToken;

        _strategy = strategy;

        _glpManager = glpManager;
    }

    // todo slipage - vault share condition
    function deposit(uint256 _amount, uint8 _leverage) external override returns (bool) {
        address _depositor = msg.sender;
        address _contract = address(this);
        if (_leverage <= 1) {
            return _depositForUser(_depositor, _amount, uint256(0));
        }

        // Function calls to leverage the open positions
        require((_leverage > 1 && _leverage <= 5), "OLV: No leverage");
        uint256 amountToBorrow = _leverage.sub(1).mul(_amount);

        ILendingPool poolToBorrow = getLendingPoolForBorrow(); //Get the pool

        IERC20 want = IERC20(poolToBorrow.wantToken());
        uint256 borrowed = poolToBorrow.borrow(_contract, _depositor, amountToBorrow); // User would have got the asset tokens

        IGLPManager glpManager = IGLPManager(_glpManager);
        bool isApproved = want.approve(_glpManager, borrowed);
        require(isApproved, 'OLV: GLP approve failed');

        uint256 glpMinted = glpManager.addLiquidityForAccount(_contract, poolToBorrow.wantToken(), borrowed); // todo add slippage

        _depositForUser(_depositor, _amount, glpMinted);

        // todo - should we check the user balance; as a require
        return true;
    }

    function _depositForUser(
        address _user,
        uint _userOwned, 
        uint _userBorrowed
    ) internal returns (bool) {
        uint256 amount = _userOwned.add(_userBorrowed);
        IERC20 asset = IERC20(_asset);

        uint256 prevContractBalance = asset.balanceOf(address(this));
        bool verifyBalance = prevContractBalance >= _userBorrowed;
        require(verifyBalance, "OLV: Missing tokens");

        if (_userOwned > 0) {
            asset.transferFrom(_user, address(this), _userOwned);
            uint256 postContractBalance = asset.balanceOf(address(this));
            verifyBalance = postContractBalance == prevContractBalance.add(_userOwned);
            require(verifyBalance, "OLV: Missing tokens");
        }

        IMintable oToken = IMintable(_oToken);
        oToken.mint(_user, amount);

        IStrategy strategy = IStrategy(_strategy);
        asset.transfer(_strategy, amount); 

        strategy.deposit(address(this), amount); 

        require(this.hf(_user) > 100, "OLV: Deposit failed");

        userDepositBlockStore[_user] = block.number;
        return true;
    }

    function setLendingPool(address _poolAddr) public onlyAllowed returns (bool) {
        require(!_enabledPools[_poolAddr], "OLV: Pool exists");
        ILendingPool pool = ILendingPool(_poolAddr);
        _pools.push(pool);
        _enabledPools[_poolAddr] = true;
        _debtTokenPoolMap[pool.debtToken()] = _poolAddr;
        return true;
    }

    function getLendingPoolForBorrow() internal view returns (ILendingPool) {
        uint i;
        ILendingPool _minUtilPool = _pools[0];
        uint256 _util = MAX_BPS;
        for(i = 0; i < _pools.length; i += 1) {
            ILendingPool temp = _pools[i];
            uint256 tempUtil = temp.utilization();
            if ( tempUtil <= _util) {
                _minUtilPool = temp;
                _util = tempUtil;
            }
        } 
        return _minUtilPool;
    }

    function leverage(uint256 _toLeverage) external override returns (bool) {
        require((_toLeverage > 1 && _toLeverage <= 5), "OLV: No leverage");
        address user = msg.sender;
        address _contract = address(this);
        uint256 _currLeverage = this.getCurrentLeverage(user);
        require(_currLeverage.div(1e2) <= 5, 'OLV: Over leveraged');

        IERC20 oToken = IERC20(_oToken);
        uint256 collateral = oToken.balanceOf(user);
        uint256 debt = getDebtBalance(user);
        uint256 userAssets = collateral - debt;

        uint256 amountToBorrow = _toLeverage.mul(1e2).sub(_currLeverage, 'OLV: Over leveraged!');
        amountToBorrow = amountToBorrow.mul(userAssets).div(1e2);

        ILendingPool poolToBorrow = getLendingPoolForBorrow(); //Get the pool

        uint256 borrowed = poolToBorrow.borrow(_contract, user, amountToBorrow); //4x

        IERC20 want = IERC20(poolToBorrow.wantToken());
        IGLPManager glpManager = IGLPManager(_glpManager);
        bool isApproved = want.approve(_glpManager, borrowed);
        require(isApproved, 'OLV: GLP approve failed');
        uint256 glpMinted = glpManager.addLiquidityForAccount(_contract, poolToBorrow.wantToken(), borrowed); // todo add slippage

        _depositForUser(user, uint256(0), glpMinted);
        return true;
    }

    function deleverage(uint256 _shares) external override returns (bool) {
        address user = msg.sender;
        return _deleverageForUser(user, _shares);
    }

    function _deleverageForUser(address  user, uint256 _shares) internal returns (bool) {
        require(_shares > 0, "OLV: Nothing to deleverage");
        require(
            userDepositBlockStore[user] != block.number,
            "OLV: Fishy transaction"
        );
        
        uint256 debt = getDebtBalance(user);
        
        console.log('shares: ', _shares);
        console.log('shares: ', debt);
        require(_shares <= debt, 'OLV: Deleverage overflow');
        
        IERC20 oToken = IERC20(_oToken);
        uint256 collateral = oToken.balanceOf(user);
        require(_shares <= collateral, 'OLV: Low funds');
        
        IGLPManager glpManager = IGLPManager(_glpManager);
        (ILendingPool poolToRepay, uint256 debtBalance) = getLendingPoolForRepay(user);

        uint256 totalWants = transferWantToUser(user, glpManager, poolToRepay, _shares);

        //settle debt 
        uint256 debtToRepay = debtBalance >= totalWants ? totalWants : debtBalance; 

        poolToRepay.repay(user, debtToRepay);

        // Burn the released oTokens
        IMintable oBurnToken = IMintable(_oToken);
        oBurnToken.burn(user, _shares);

        require(this.hf(user) >=100, 'OLV: Health issue');
        return true;
    }


    function transferWantToUser(
        address user, 
        IGLPManager glpManager, 
        ILendingPool pool, 
        uint256 shares
    ) internal returns (uint256) {
        require(user != address(0), "OLV: Null address");
        require(shares > 0, "OLV: Invalid shares" );

        address _contract = address(this);
        
        uint256 _amount = shares.mul(this.getPricePerShare(0));
        IStrategy strategy = IStrategy(_strategy);
        strategy.withdraw(address(this), _amount); // GLP tokens are with Olive contract
        
        address wantAddress = pool.wantToken();
        IERC20 wantToken = IERC20(wantAddress);
        uint256 totalWants = glpManager.removeLiquidityForAccount(_contract, wantAddress, _amount);

        wantToken.transfer(user, totalWants); // todo remaining balance stays with user in the form of want token

        return totalWants;
    } 

    function getLendingPoolForRepay(address _user) internal view returns (ILendingPool, uint256) {
        uint i;
        ILendingPool _maxDebtPool = _pools[0];
        uint256 debt = 0;
        for(i = 0; i < _pools.length; i += 1) {
            ILendingPool temp = _pools[i];
            IERC20 dToken = IERC20(temp.debtToken());
            uint256 dBalance = dToken.balanceOf(_user);
            if ( dBalance >= debt) {
                _maxDebtPool = temp;
                debt = dBalance;
            }
        } 
        return (_maxDebtPool, debt);
    }

    function repay(address _debtToken, uint256 _amount) external override returns (bool) {
        address user = msg.sender;
        return _repayForUser(user, _debtToken, _amount);
    }

    function _repayForUser(address user, address _debtToken,  uint256 _amount) internal returns (bool) {
        require(_amount > 0, "OLV: Nothing to repay");
        require(
            userDepositBlockStore[user] != block.number,
            "OLV: Fishy transaction"
        );

        uint256 _shares = _amount.div(this.getPricePerShare(0));
        ILendingPool pool = ILendingPool(_debtTokenPoolMap[_debtToken]);

        console.log('Pool Address: ', address(pool));

        IERC20 doToken = IERC20(_debtToken);
        uint256 doTokenBalance = doToken.balanceOf(user);
        require(_shares <= doTokenBalance, 'OLV: Deleverage overflow');

        pool.repay(user, _amount);

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

        address _contract = address(this);
        IERC20 oToken = IERC20(_oToken);
        uint256 collateral = oToken.balanceOf(user);
        require(_shares <= this.getTotalWithdrawableShares(user), 'OLV: Over leveraged');
        require(_shares <= collateral, 'OLV: Shares overflow');

        IStrategy strategy = IStrategy(_strategy);
        uint256 glpWithdrawn = strategy.withdraw(_contract, _shares); // Tokens are with Olive

        IERC20 asset = IERC20(_asset);
        asset.transfer(user, glpWithdrawn);

        IMintable oBurnableToken = IMintable(_oToken);
        oBurnableToken.burn(user, _shares);

        console.log(this.hf(user));

        require(this.hf(user) >= 100, "OLV: Unhealthy Position");
        return true;
    }
    
    function hf(address _user) public view returns (uint256) {
        uint256 debt = getDebtBalance(_user);

        IERC20 colToken = IERC20(_oToken);
        uint256 userCollateral = colToken.balanceOf(_user);
        
        if (debt == 0) {
            return MAX_BPS;
        }

        return userCollateral.mul(0.9e4).div(debt).div(1e2);
    }


    function getDebtBalance(address _user) internal view returns (uint256) {
        uint8 i;
        uint256 debtBalance;

        // todo convert the balance into asset

        for (i = 0; i < _pools.length; i += 1) {
            IERC20 debtToken = IERC20(_pools[i].debtToken());
            debtBalance = debtBalance.add(debtToken.balanceOf(_user));
        }

        return debtBalance;
    }
    
    // List of view functions
    function getTotalWithdrawableShares(
        address _user
    ) external  override view returns (uint256) {
        // todo - residual value fixes
        uint256 debt = getDebtBalance(_user);
        uint256 totalWithdrawable = debt.mul(MAX_BPS).div(0.9e4);
        IERC20 oToken = IERC20(_oToken);
        uint256 collateral = oToken.balanceOf(_user);

        return collateral.sub(totalWithdrawable, 'OLV: Under collateral'); 
    }

    function getPricePerShare(
        uint256 shareType
    ) external view override returns (uint256) {
        return 1;
    }

    function getCurrentLeverage(
        address _user
    ) external view override returns (uint256) {
        IERC20 oToken = IERC20(_oToken);
        uint256 collateral = oToken.balanceOf(_user);
        console.log('ATokenBalance: ', collateral.div(1e8));

        uint256 debt = getDebtBalance(_user);

        if (debt == 0) {
            return 0;
        }
        console.log('Debt: ', debt.div(1e8));

        uint256 userAssets = collateral - debt;
        console.log('Assets: ', userAssets.div(1e8));

        if (userAssets == 0) {
            return MAX_BPS;
        }

        uint256 _leverage = debt.mul(1e2).div(userAssets).add(1e2);
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
