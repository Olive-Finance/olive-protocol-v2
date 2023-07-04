// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {ILendingPool} from './pools/interfaces/ILendingPool.sol';
import {IMintable} from './interfaces/IMintable.sol';
import {IStrategy} from './strategies/interfaces/IStrategy.sol';
import {IAssetManager} from './strategies/interfaces/IAssetManager.sol';

import {IOlive} from './interfaces/IOlive.sol';

import {Constants} from './lib/Constants.sol';

import {Allowed} from './interfaces/Allowed.sol';

import "hardhat/console.sol";

contract OliveV2 is IOlive, Allowed {

    //Address locations for each of the tokens
    IERC20 public asset;
    address public oToken;

    //Address for strategy
    IStrategy public strategy;

    //Address for Asset Manager
    IAssetManager public assetManager;

    //Olive treasury address
    address public treasury;

    // Pool for borrowing
    ILendingPool public lendingPool;
  
    // Vault parameters
    uint256 public MAX_LEVERAGE;
    uint256 public MIN_LEVERAGE;
    uint256 public LIQUIDATION_THRESHOLD;

    uint256 public HF_THRESHOLD = Constants.PINT;

    // Struct to store the txn block number
    mapping(address => uint256) public lastTxnBlock;

    // Allowed address for same block transactions
    mapping(address => bool) public allowedAddresses;

    constructor(
        address _asset,
        address _oToken,
        address _strategy,
        address _assetManager,
        address _lendingPool,
        uint256 _minLeverage,
        uint256 _maxLeverage,
        uint256 _lqThreshold
    ) Allowed(msg.sender) Pausable() {
        asset = IERC20(_asset);
        oToken = _oToken;
        strategy = IStrategy(_strategy);
        assetManager = IAssetManager(_assetManager);
        lendingPool = ILendingPool(_lendingPool);

        // Setting the default values
        MIN_LEVERAGE = _minLeverage;
        MAX_LEVERAGE = _maxLeverage;
        LIQUIDATION_THRESHOLD = _lqThreshold;
    }

    // Vault setter functions
    function setTreasury(address _treasury) public onlyAllowed returns (bool) {
        require(_treasury != address(0) && _treasury != address(this), "OLV: Invalid treasury address");
        treasury = _treasury;
        return true;
    }

    function setLiquidationThreshold(uint256 _threshold) public onlyAllowed returns (bool) {
        require(_threshold <= Constants.PINT, "OLV: Invalid liquidation threshold");
        LIQUIDATION_THRESHOLD = _threshold;
        return true;
    }

    function setMinLeverage(uint256 _minLeverage) public onlyAllowed returns(bool) {
        require(_minLeverage >= Constants.PINT, "OLV: Invalid min leverage value");
        MIN_LEVERAGE = _minLeverage;
        return true;
    }

    function setMaxLeverage(uint256 _maxLeverage) public onlyAllowed returns(bool) {
        require(_maxLeverage > MIN_LEVERAGE, "OLV: Invalid max leverage value");
        MAX_LEVERAGE = _maxLeverage;
        return true;
    }

    // List of modifiers for protection
    // Pre - modifiers
    modifier flashTxnCheck() {
        address caller = msg.sender;
        if (!allowedAddresses[caller]) {
            require(lastTxnBlock[caller] != block.number, "OLV: Flash Txn not allowed");
        }
        _;
    }

    // Post - modifiers
    modifier hfCheck() {
        address caller = msg.sender;
        _;
        require(this.hf(caller) > HF_THRESHOLD, "OLV: Degarded HF, Liquidation risk");
    }

    // List of view functions
    function getPositionValueInAsset(address _user) public pure view returns (uint256) {
        require(_user != address(0), "OLV: Invalid address");
        IERC20 _oToken = IERC20(oToken);
        return (_oToken.balanceOf(_user) * this.getPricePerShare()) / Constants.PINT;
    }

    function getDebtValueInAsset(address _user) public pure view returns (uint256) {
        require(_user != address(0), "OLV: Invalid address");
        uint256 debt = lendingPool.getDebt(_user); // want token usdc
        address want = lendingPool.wantToken();
        return _assetManager.exchangeValue(address(want), address(_asset), debt);
    }

    function getPricePerShare() external pure view override returns (uint256) {
       return (balanceOf() * Constants.PINT) / totalSupply() ;
    }

    function balanceOf() public pure view returns (uint256) {
        return asset.balanceOf(address(strategy)) + asset.balanceOf(address(this));
    }

    function totalSupply() public pure view returns (uint256) {
        return IERC20(oToken).totalSupply();
    }

    function getLeverage(address _user) external pure view override returns (uint256) {
        uint256 posValue = getPositionValueInAsset(_user);
        uint256 debt = getDebtValueInAsset(_user);
        if (debt == 0) {
            return MIN_LEVERAGE;
        }

        uint256 collateral = posValue - debt;
        if (collateral <= 0) {
            return Constants.MAX_INT;
        }

        return (posValue * Constants.PINT) / collateral;
    }

    function hf(address _user) external pure view returns (uint256) {
        uint256 debt = getDebtValueInAsset(_user);
        uint256 posValue = getPositionValueInAsset(_user);
        if (debt == 0) {
            return Constants.MAX_INT;
        }
        return (posValue * LIQUIDATION_THRESHOLD) / debt;
    }

    function maxWithdraw(address _user) external pure view override returns (uint256) {
        uint256 debt = getDebtValueInAsset(_user);
        uint256 posValue = getPosValueInAsset(_user);

        uint256 userLeverage = this.getLeverage(_user);
        uint256 userHF = this.hf(_user);

        if (userLeverage >= MAX_LEVERAGE) {
            return 0;
        }
        if (userHF <= HF_THRESHOLD) {
            return 0;
        }
        uint256 c1 = (debt * Constants.PINT) / LIQUIDATION_THRESHOLD;
        uint256 c2 = (debt * MAX_LEVERAGE) / (MAX_LEVERAGE - Constants.PINT);
        c1 = c1 > c2 ? c1 : c2;
        return posValue - c1;
    }

    function previewDeposit(address _user, uint256 _leverage, uint256 _collateral) public view returns (uint256) {
        uint256 totalCollateral =  getPosValueInAsset(_user) - getDebtValueInAsset(_user) + _collateral;
        require(totalCollateral > 0, "OLV: total collateral < 0");
        require(_leverage >= this.getLeverage(_user), "OLV: Invalid leverage");
        uint256 debt = ((_leverage - this.getLeverage(_user)) * totalCollateral) / Constants.PINT;
        return ((debt + _collateral) * Constants.PINT) / this.getPricePerShare();
    }

    function isOverSlippage(
        uint256 _expected,
        uint256 _actual,
        uint256 _tolerance
    ) internal pure returns (bool) {
        return _actual < (_expected * (Constants.PINT - _tolerance)) / Constants.PINT;
    }

    // Vault functions
    function deposit(
        uint256 _amount,
        uint256 _leverage,
        uint256 _expectedShares,
        uint256 _acceptableSlippage
    ) external override blockCheck hfCheck returns (bool) {
        require(_leverage >= this.getLeverage(_user) && _leverage <= MAX_LEVERAGE, "OLV: Invalid leverage value");
        address _user = msg.sender;
        uint256 totalCollateral =  getPosValueInAsset(_user) - getDebtValueInAsset(_user) + _amount;
        uint256 debt = ((_leverage - this.getLeverage(_user)) * totalCollateral) / Constants.PINT;
        uint256 bought = 0;

        _asset.transferFrom(_user, address(this), _amount);
        if (debt > 0) {
            bought = _borrowNBuy(_user, debt);
        }
        _deploy(bought + _amount);
        uint256 minted = _mint(_user, bought + _amount);

        if (isOverSlippage(_expectedShares, minted, _acceptableSlippage)) revert('OLV: Position slipped');
        return true;
    }

    function leverage(uint256 _leverage, uint256 _expectedShares, uint256 _acceptableSlippage) external override hfCheck returns (bool)  {
        require(_leverage > MIN_LEVERAGE && _leverage <= MAX_LEVERAGE, "OLV: Invalid leverage");
        address _user = msg.sender;
        uint256 collateral =  getPosValueInAsset(_user) - getDebtValueInAsset(_user);
        uint256 debt = ((_leverage - this.getLeverage(_user)) * collateral) / Constants.PINT;
        
        uint256 bought = _borrowNBuy(_user, debt);

        _deploy(bought);
        uint256 minted = _mint(_user, bought);

        if (isOverSlippage(_expectedShares, minted, _acceptableSlippage)) revert('OLV: Position slipped');
        return true;
    }

    function _borrowNBuy(address _user, uint256 _debt) internal returns (uint256) {
        require(_debt > 0, "OLV: Invalid debt");
        require(_user != address(0) && _user != address(this), "OLV: Invalid Address");
        IERC20 want = IERC20(lendingPool.wantToken());
        uint256 debtInWant = _assetManager.exchangeValue(address(_asset), address(want), _debt);
        uint256 borrowed = _borrow(_user, debtInWant);
        bool isApproved = want.approve(address(_assetManager), borrowed);
        if (!isApproved) revert("OLV: Approval failed");
        return _buy(lendingPool.wantToken(), borrowed);
    }

    function _borrow(address _user, uint256 _amount) internal returns (uint256) {
        require(_amount > 0, "OLV: Invalid borrow amount");
        require(_user != address(0), "OLV: Invalid user address");
        return lendingPool.borrow(address(this), _user, _amount);
    }

    function _buy(address _token, uint256 _amount) internal returns (uint256) {
        require(_token != address(0) && _token == lendingPool.wantToken(), "OLV: Invalid token");
        require(_amount > 0, "OLV: Invalid amount");
        return _assetManager.buy(address(this), _token, _amount);
    }

    function _mint(address _user, uint256 _amount) internal returns (uint256) {
        IMintable oToken = IMintable(_oToken);
        uint256 _shares = (_amount * Constants.PINT) / this.getPricePerShare();
        oToken.mint(_user, _shares);
        lastTxnBlock[_user] = block.number;
        return _shares;
    }

    function _burn(address _user, uint256 _shares) internal returns (uint256) {
        IMintable oBurnToken = IMintable(_oToken);
        oBurnToken.burn(_user, _shares);
        lastTxnBlock[_user] = block.number;
        return _shares;
    }

    function _sell(address _token, uint256 _amount) internal returns (uint256) {
       require(_token != address(0) && _token == lendingPool.wantToken(), "OLV: Invalid token");
       require(_amount > 0, "OLV: Invalid amount");
       return _assetManager.sell(address(this), _token, _amount);
    }

    function _repay(address _user, uint256 _amount) internal returns (uint256) {
        lendingPool.repay(address(this), _user, _amount);
        return _amount;
    }

    function _deploy(uint256 _amount) internal returns (uint256) {
        require(_amount > 0, "OLV: Invalid amount for deploy");
        _asset.transfer(address(_strategy), _amount);
        _strategy.deposit(address(this), _amount); 
    }

    function _redeem(uint256 _shares) internal returns (uint256) {
        require(_shares > 0, "OLV: Invalid shares");
        return _strategy.withdraw(address(this), _shares); 
    }

    function deleverage(
        uint256 _leverage,
        uint256 _repayAmount,
        uint256 _acceptableSlippage
    ) external override blockCheck hfCheck returns (bool) {
        address _user = msg.sender;
        uint256 paid = _deleverageForUser(_user, _leverage);
        if (isOverSlippage(_repayAmount, paid, _acceptableSlippage)) revert ("OLV: Postion slipped");
        return true;
    }

    function _deleverageForUser(
        address _user,
        uint256 _leverage
    ) internal hfCheck returns (uint256) {
        require(
            _leverage >= MIN_LEVERAGE && _leverage <= MAX_LEVERAGE,
            "OLV: Invalid deleverage position"
        );

        uint256 _userLeverage = this.getLeverage(_user);
        require(_leverage < _userLeverage, "OLV: Invalid leverage");

        uint256 collateral =  getPosValueInAsset(_user) - getDebtValueInAsset(_user);
        uint256 _shares = ((_userLeverage - _leverage) * collateral) / Constants.PINT;

        _burn(_user, _shares);

        //burn the shares - OToken = SToken
        uint256 value = _redeem(_shares);
        uint256 sold = _sell(lendingPool.wantToken(), value);

        return _repay(_user, sold);
    }

    function withdraw(
        uint256 _shares,
        uint256 _expTokens,
        uint256 _acceptableSlippage
    ) external override blockCheck hfCheck returns (bool) {
        address _user = msg.sender;
        uint256 redeemed = _withdrawForUser(_user, _shares);
        if (isOverSlippage(_expTokens, redeemed, _acceptableSlippage)) revert ("OLV: Postion slipped");
        return true;
    }

    function _withdrawForUser(
        address _user,
        uint256 _shares
    ) internal hfCheck returns (uint256) {
        require(_user != address(0), "OLV: Invalid address");
        require(_shares > 0, "OLV: Nothing to widthdraw");

        IERC20 oToken = IERC20(_oToken);
        uint256 userShare = oToken.balanceOf(_user);
        require(_shares <= userShare, "OLV: Shares overflow");
        require(
            _shares <= this.maxWithdraw(_user),
            "OLV: Over leveraged"
        );

        _burn(_user, _shares);
        uint256 value = _redeem(_shares);

        _asset.transfer(_user, value);
        return value;
    }

    function closePosition(address _user) external override returns (bool) {
        _deleverageForUser(_user, MIN_LEVERAGE);
        uint256 remainingShares = this.maxWithdraw(_user);
        _withdrawForUser(_user, remainingShares);
        return true;
    }
}