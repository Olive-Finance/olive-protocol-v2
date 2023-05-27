// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IMintable} from './interfaces/IMintable.sol';
import {IOliveV2} from './interfaces/IOliveV2.sol';
import {ILendingPool} from './interfaces/ILendingPool.sol';
import {IStrategy} from './interfaces/IStrategy.sol';
import {Allowed} from './utils/modifiers/Allowed.sol';
import {ILPManager} from './interfaces/ILPManager.sol';

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

    //Address for LP Manager
    address private _lpManager;

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
        address lpManager
    ) Allowed(msg.sender) {
        _asset = asset;
        _oToken = oToken;
        _strategy = strategy;
        _lpManager = lpManager;
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
        uint256 glpMinted = _borrowAndMintLP(_contract, _depositor, amountToBorrow);

        _depositForUser(_depositor, _amount, glpMinted);

        return true;
    }

    function getMaxAvailabilityPool() public view returns (ILendingPool, uint256) {
        uint8 i;
        ILendingPool _maxPool = _pools[0];
        ILPManager lpManager = ILPManager(_lpManager);

        uint256 _maxBorrowable = 0;
        uint256 _totalBorrowable = 0;
        for(i = 0; i < _pools.length; i += 1) {
            ILendingPool temp = _pools[i];
            address want = temp.wantToken();

            uint256 _poolWant = temp.maxAllowedAmount();
            _poolWant = lpManager.getPrice(want, _poolWant);
            _totalBorrowable = _totalBorrowable.add(_poolWant);

            if (_poolWant > _maxBorrowable) {
                _maxPool = temp;
                _maxBorrowable = _poolWant;
            }
        } 
        return (_maxPool, _totalBorrowable);
    }

    /**
     * Function which does the borrowing and minting
     * 
     * The logic of the borrow and minting as follows 
     * Step1: Borrow from max available pool
     * Step2: Borrow the remaining balance from other pools
     * 
     * @param _borrower the account to which the tokens would land
     * @param _user on who's behalf the tokens are borrowed
     * @param _amount total amount of tokens to be borrowed in LP Value
     */
    function _borrowAndMintLP(address _borrower, address _user, uint256 _amount) internal returns (uint256) {
        require(_borrower != address(0), "OLV: Invalid borrower");
        require(_user != address(0), "OLV, Invalid user");
        require(_amount > 0, "OLV: Invalid amount to borrow");

        (ILendingPool pool,  uint256 totalBorrowable) = getMaxAvailabilityPool();

        // Do a validation of total size of pool to be less than _toBorrow
        require(totalBorrowable >= _amount, 'OLV: Insuffient borrow');

        // Borrow from pool
        (uint256 _poolBorrowed, uint256 lpMinted) = _borrowAndMintFromPool(pool, _borrower, _user, _amount);

        // Once the total amount is borrowed does not need to go to second function 
        if (_poolBorrowed >= _amount) {
            return lpMinted;
        }

        uint256 remmaingBorrow = _amount.sub(_poolBorrowed, "OLV: Logical error");

        (address[] memory _tokens, uint256[] memory _borrowed) = _borrowForUserFromPools(_borrower, _user, remmaingBorrow); // TODO - update to add the price component
        
        require(_tokens.length == _borrowed.length, "OLV: Invalid borrow");

        uint8 i;
        for (i = 0; i < _tokens.length; i += 1) {
            uint256 borrowed = _borrowed[i];

            // This protects for any empty array values - Since the memory variable is used
            // had to add this extra protection
            if (borrowed <= 0) {
                continue;
            }

            uint256 minted = _mintLP(_tokens[i], borrowed);
            lpMinted = lpMinted.add(minted);
        }

        return lpMinted;
    }

    function _borrowAndMintFromPool(
        ILendingPool pool,
        address _borrower, 
        address _user, 
        uint256 _amount
        ) internal returns (uint256, uint256) {
        require(_borrower != address(0), "OLV: Invalid borrower");
        require(_user != address(0), "OLV, Invalid user");
        require(_amount > 0, "OLV: Invalid amount to borrow"); 

        uint256 maxBorrowable = pool.maxAllowedAmount();
        require(maxBorrowable >= 0, "OLV: Insufficient funds");

        uint256 toBorrow = maxBorrowable > _amount ? _amount : maxBorrowable; 
        
        uint256 borrowed = _executeBorrow(pool, _borrower, _user, toBorrow);
        uint256 minted = _mintLP(pool.wantToken(),  borrowed);
        return (toBorrow, minted);
    }


    /**
     * This is the core function to interact with lending pools
     * 
     * Following cases are considere for implementation
     *
     * a. Get the pool with lowest utilization - waterfall model is implemented
     * b. The total amount to be borrowed is less than the total pool size
     * c. Multiple borrowings will be triggered and amount will be converted to underlying LP token
     * 
     * @param _borrower the account to which the tokens would land
     * @param _user on who's behalf the tokens are borrowed
     * @param _toBorrow total amount of tokens to be borrowed
     */
    function _borrowForUserFromPools(
        address _borrower, 
        address _user, 
        uint256 _toBorrow
        ) internal returns(address[] memory, uint256[] memory) {
        uint256 _toBorrowFromPool = _toBorrow;
        uint8 i;
        uint256 size = _pools.length;
        address[] memory _tokens = new address[] (size);
        uint256[] memory _borrowed = new uint256[] (size);

        // Iterate over the pools and borrow the amounts
        for (i = 0; i < _pools.length; i += 1) {
            ILendingPool _loaded = _pools[i];
            uint256 _borrowLimit = _loaded.maxAllowedAmount();
            uint256 _amount = _toBorrowFromPool > _borrowLimit ? _borrowLimit : _toBorrowFromPool;
            if (_amount <= 0 ) {
                continue;
            }
            uint256 borrowed = _executeBorrow(_loaded, _borrower, _user, _amount);
            _tokens[i] = _loaded.wantToken();
            _borrowed[i] = borrowed;
            _toBorrowFromPool = _toBorrowFromPool.sub(borrowed, 'OLV: Fishy Transaction');
            if (_toBorrowFromPool == 0) {
                break;
            }
        }

        if (_toBorrowFromPool > 0) {
             revert('OLV: Insuffieint funds');
        }
        // return the list of assets and amounts returns two arrays
        return (_tokens, _borrowed);
    }

    function _getTotalBorrowable() internal view returns (uint256) {
        uint256 _totalBorrowable = 0;
        uint8 i;
        for (i = 0; i < _pools.length; i += 1) {
            ILendingPool _loaded = _pools[i];
            _totalBorrowable  = _totalBorrowable.add(_loaded.maxAllowedAmount());
        }
        return _totalBorrowable;
    }

    function _executeBorrow(
        ILendingPool _pool, 
        address _borrower, 
        address _user, 
        uint256 _toBorrow
        ) internal returns (uint256) {
        ILPManager lpManager = ILPManager(_lpManager);
        IERC20 want = IERC20(_pool.wantToken());

        uint256 _wantToBorrow = lpManager.getBurnPrice(address(want), _toBorrow);
        
        uint256 balBeforeBorrow = want.balanceOf(_borrower);
        uint256 borrowed = _pool.borrow(_borrower, _user, _wantToBorrow);
        uint256 balAfterBorrow = want.balanceOf(_borrower);
        balAfterBorrow = balAfterBorrow.sub(balBeforeBorrow, "OLV: Invalid borrow");

        require(balAfterBorrow >= borrowed, "OLV: Invalid borrow");
        return borrowed;
    } 

    function _mintLP(address _token, uint256 _borrowed) internal returns (uint256) {
        address _borrower = address(this);
        IERC20 want = IERC20(_token);
        ILPManager glpManager = ILPManager(_lpManager);
        bool isApproved = want.approve(_lpManager, _borrowed);
        require(isApproved, 'OLV: GLP approve failed');

        // todo add splippage
        uint256 glpMinted = glpManager.addLiquidityForAccount(_borrower, _token, _borrowed); 

        return glpMinted;
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

        uint256 glpMinted = _borrowAndMintLP(_contract, user, amountToBorrow);

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
        
        ILPManager glpManager = ILPManager(_lpManager);
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
        ILPManager glpManager, 
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


    function getDebtBalance(address _user) public view returns (uint256) {
        uint8 i;
        uint256 debtBalance = 0;

        // todo convert the balance into asset
        for (i = 0; i < _pools.length; i += 1) {
            ILendingPool temp = _pools[i];
            IERC20 debtToken = IERC20(temp.debtToken());
            address want = temp.wantToken();

            ILPManager lpManager = ILPManager(_lpManager);
            // todo - verify how the interest is added 
            debtBalance += lpManager.getPrice(want, debtToken.balanceOf(_user));
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
