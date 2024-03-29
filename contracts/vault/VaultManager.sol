// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Allowed} from "../utils/Allowed.sol";
import {Constants} from "../lib/Constants.sol";

import {ILendingPool} from "../pools/interfaces/ILendingPool.sol";
import {IStrategy} from '../strategies/interfaces/IStrategy.sol';
import {IVaultManager} from "./interfaces/IVaultManager.sol";
import {IVaultCore} from "./interfaces/IVaultCore.sol";
import {IFees} from "../fees/interfaces/IFees.sol";

contract VaultManager is IVaultManager, Allowed {
    IVaultCore public vaultCore;
    IFees public fees;

    // Struct to store the txn block number
    mapping(address => uint256) public userTxnBlockStore;

    // Allowed address for same block transactions
    mapping(address => bool) public allowedTxtor;

    // Empty constructor
    constructor() Allowed(msg.sender) {}

    // Pre - modifiers
    modifier blockCheck() {
        address caller = msg.sender;
        if (!allowedTxtor[caller]) {
            require(userTxnBlockStore[caller] != vaultCore.blockNumber(), "VM: Txn not allowed");
        }
        _;
    }

    // Post - modifiers
    modifier hfCheck() {
        address caller = msg.sender;
        _;
        require(vaultCore.isHealthy(caller), "VM: Degarded HF, Liquidation risk");
    }

    function setVaultCore(address _vaultCore) external onlyOwner {
        require(
            _vaultCore != address(0) && _vaultCore != address(this),
            "VM: Invalid core"
        );
        vaultCore = IVaultCore(_vaultCore);
    }

    function setSameBlockTxnFor(address _user, bool _toAllow) external onlyOwner {
        require(_user != address(0), "VM: Invalid user");
        allowedTxtor[_user] = _toAllow;
    }

    function getLeverage(address _user) public view override returns (uint256) {
        uint256 posValue = vaultCore.getPosition(_user);
        uint256 debt = vaultCore.getDebt(_user);
        if (debt == 0) {
            return vaultCore.getMinLeverage();
        }

        uint256 collateral = posValue - debt;
        if (collateral <= 0) {
            return Constants.MAX_INT;
        }

        return (posValue * Constants.PINT) / collateral;
    }

    function balance() public view override returns (uint256) {
        return IStrategy(vaultCore.getStrategy()).balanceOf(address(vaultCore));
    }

    function totalSupply() public view override returns (uint256) {
        return IERC20(vaultCore.getLedgerToken()).totalSupply();
    }

    function getBurnableShares(address _user) external view override returns (uint256) {
        uint256 debt = vaultCore.getDebt(_user);
        uint256 position = vaultCore.getPosition(_user);

        uint256 userLeverage = getLeverage(_user);

        if (userLeverage >= vaultCore.getMaxLeverage()) {
            return 0;
        }
        if (!vaultCore.isHealthy(_user)) {
            return 0;
        }
        uint256 c1 = (debt * Constants.PINT) /
            vaultCore.getLiquidationThreshold();
        uint256 c2 = (debt * vaultCore.getMaxLeverage()) /
            (vaultCore.getMaxLeverage() - Constants.PINT);
        c1 = c1 > c2 ? c1 : c2;
        return ((position - c1) * Constants.PINT) / vaultCore.getPPS();
    }

    // Internal functions 
    function hasExcess (
        uint256 _expected,
        uint256 _actual,
        uint256 _tolarance
    ) internal pure returns (bool) {
        return
            (_actual >=
                (_expected * (Constants.PINT - _tolarance)) / Constants.PINT);
    }

    function setFees(address _fees) external onlyOwner {
        require(_fees != address(0) && _fees != address(this), "VM: Invalid fees");
        fees = IFees(_fees);
    }

    function _borrow(address _user, uint256 _amount) internal returns (uint256) {
        require(_amount > 0, "VM: Invalid borrow amount");
        require(_user != address(0), "VM: Invalid user address");
        return ILendingPool(vaultCore.getLendingPool()).borrow(address(vaultCore), _user, _amount);
    }

    function _mint(address _user, uint256 _amount) internal returns (uint256) {
        uint256 _shares = (_amount * Constants.PINT) / vaultCore.getPPS();
        vaultCore.mintShares(_user, _shares);
        userTxnBlockStore[_user] = vaultCore.blockNumber();
        return _shares;
    }

    function _repay(address _user, uint256 _amount) internal returns (uint256) {
        ILendingPool(vaultCore.getLendingPool()).repay(address(vaultCore), _user, _amount);
        userTxnBlockStore[_user] = vaultCore.blockNumber();
        return _amount;
    }

    function _deploy(uint256 _amount) internal {
        require(_amount > 0, "VM: Invalid amount for deploy");
        computeFees();
        IStrategy(vaultCore.getStrategy()).deposit(address(vaultCore), _amount);
    }

    function _redeem(uint256 _shares) internal returns (uint256) {
        require(_shares > 0, "VM: Invalid shares");
        computeFees();
        return IStrategy(vaultCore.getStrategy()).withdraw(address(vaultCore), _shares);
    }

    function _borrowNBuy(address _user, uint256 _debt) internal returns (uint256) {
        require(_debt > 0, "VM: Invalid debt");
        require(_user != address(0) && _user != address(this), "VM: Invalid Address");
        address want = ILendingPool(vaultCore.getLendingPool()).wantToken();
        uint256 debtInWant = vaultCore.getTokenValueforAsset(want, _debt);
        uint256 borrowed = _borrow(_user, debtInWant);
        return vaultCore.buy(want, borrowed);
    }

    // Vault functions
    function deposit(uint256 _amount, uint256 _leverage, uint256 _expShares, uint256 _slippage)
     external override blockCheck returns (bool) {
        return _deposit(msg.sender, _amount, _leverage, _expShares, _slippage);
    }

    function leverage(uint256 _leverage, uint256 _expShares, uint256 _slippage) 
     external override blockCheck  returns (bool) {
        return _deposit(msg.sender, 0, _leverage, _expShares, _slippage);
    }

    function _getDebt(address _user, uint256 _curLeverage, uint256 _toLeverage, uint256 _amount) internal view returns (uint256) {
        uint256 collateral = vaultCore.getCollateral(_user);
        // As the leverage increases based on time, and precision is maintained at 18, this correction is needed. 
        // This ensures the _toLeverage should always be greater than _curLeverage
        uint256 newLeverage = _curLeverage > _toLeverage ? _curLeverage: _toLeverage; 
        uint256 debt = (collateral * (newLeverage - _curLeverage)) + (_amount * (newLeverage - vaultCore.getMinLeverage()));
        return (debt / Constants.PINT); 
    }

    function _deposit(address _user, uint256 _amount, uint256 _leverage, uint256 _expShares, uint256 _slippage) whenNotPaused nonReentrant hfCheck internal returns (bool) {
        uint256 curLeverage = getLeverage(_user);
        require(_leverage >= vaultCore.getMinLeverage() && _leverage <= vaultCore.getMaxLeverage(),
            "VM: Invalid leverage value"
        );
        uint256 debt = _getDebt(_user, curLeverage, _leverage, _amount);
        uint256 bought;
        IERC20(vaultCore.getAssetToken()).transferFrom(_user, address(vaultCore), _amount);
        if (debt > 0) {
            bought = _borrowNBuy(_user, debt);
        }
        uint256 toDeposit = bought + _amount;
        _deploy(toDeposit);
        uint256 minted = _mint(_user, toDeposit);
        require(hasExcess(_expShares, minted, _slippage), "VM: Position slipped"); 
        emit Deposit(address(this), _user, toDeposit);
        return true;
    }

    function deleverage(
        uint256 _leverage,
        uint256 _repayAmount,
        uint256 _slippage
    ) external override whenNotPaused nonReentrant blockCheck returns (bool) {
        address _user = msg.sender;
        uint256 _userLeverage = getLeverage(_user);
        uint256 paid = _deleverageForUser(_user, _leverage);
        require(hasExcess(_repayAmount, paid, _slippage), "VM: Postion slipped");
        emit Leverage(address(this), _user, _userLeverage, _leverage);
        return true;
    }

    function _deleverageForUser(
        address _user,
        uint256 _leverage
    ) internal hfCheck returns (uint256) {
        uint256 _userLeverage = getLeverage(_user);
        require(_leverage < _userLeverage, "VM: Invalid leverage");
        uint256 _shares = ((_userLeverage - _leverage) * vaultCore.getCollateral(_user)) / vaultCore.getPPS();
        vaultCore.burnShares(_user, _shares);
        uint256 sold = vaultCore.sell(ILendingPool(vaultCore.getLendingPool()).wantToken(), _redeem(_shares));
        return _repay(_user, sold);
    }

    function withdraw(
        uint256 _shares,
        uint256 _expTokens,
        uint256 _slippage
    ) external override whenNotPaused nonReentrant blockCheck hfCheck returns (bool) {
        address _user = msg.sender;
        uint256 redeemed = _withdrawForUser(_user, _shares);
        require(hasExcess(_expTokens, redeemed, _slippage), "VM: Postion slipped");
        emit Withdraw(address(this), _user, redeemed);
        return true;
    }

    function _withdrawForUser(
        address _user,
        uint256 _shares
    ) internal hfCheck returns (uint256) {
        require(_user != address(0), "VM: Invalid address");
        require(_shares > 0, "VM: Nothing to widthdraw");
        require(IERC20(vaultCore.getLedgerToken()).balanceOf(_user) >= _shares, "VM: Shares overflow");
        require(_shares <= this.getBurnableShares(_user), "VM: Over leveraged");

        vaultCore.burnShares(_user, _shares);
        uint256 value = _redeem(_shares);
        vaultCore.transferAsset(_user, value);
        userTxnBlockStore[_user] = vaultCore.blockNumber();
        return value;
    }

    function computeFees() public {
        uint256 newFee = (balance() * fees.getMFee() * 
        (block.timestamp - fees.getLastUpdatedAt())) / (Constants.HUNDRED_PERCENT * Constants.YEAR_IN_SECONDS);
        fees.setFee(fees.getAccumulatedFee() + newFee, block.timestamp);
    }
}