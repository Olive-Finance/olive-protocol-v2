// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Allowed} from "../utils/Allowed.sol";
import {Constants} from "../lib/Constants.sol";

import {IAssetManager} from '../strategies/interfaces/IAssetManager.sol';
import {ILendingPool} from "../pools/interfaces/ILendingPool.sol";
import {IStrategy} from '../strategies/interfaces/IStrategy.sol';
import {IVaultManager} from "./interfaces/IVaultManager.sol";
import {IVaultCore} from "./interfaces/IVaultCore.sol";


contract VaultManager is IVaultManager, Allowed {
    IVaultCore vaultCore;

    //Address for Asset Manager
    IAssetManager public _assetManager;

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
            require(
                userTxnBlockStore[caller] != block.number,
                "VM: Txn not allowed"
            );
        }
        _;
    }

    // Post - modifiers
    modifier hfCheck() {
        address caller = msg.sender;
        _;
        require(
            this.hf(caller) > vaultCore.getHFThreshold(),
            "VM: Degarded HF, Liquidation risk"
        );
    }

    function setVaultCore(address _vaultCore) external {
        require(
            _vaultCore != address(0) && _vaultCore != address(this),
            "VM: Invalid core"
        );
        vaultCore = IVaultCore(_vaultCore);
    }

    function getPosValueInAsset(address _user) public view returns (uint256) {
        require(_user != address(0), "VM: Invalid address");
        IERC20 oToken = IERC20(vaultCore.getLedgerToken());
        return (oToken.balanceOf(_user) * vaultCore.getPPS()) / Constants.PINT;
    }

    function getDebtValueInAsset(address _user) public view returns (uint256) {
        require(_user != address(0), "VM: Invalid address");
        ILendingPool pool = ILendingPool(vaultCore.getLendingPool());
        return
            _assetManager.exchangeValue(
                pool.wantToken(),
                address(vaultCore.getAssetToken()),
                pool.getDebt(_user)
            );
    }

    function hf(address _user) external view returns (uint256) {
        uint256 debt = getDebtValueInAsset(_user);
        uint256 posValue = getPosValueInAsset(_user);
        if (debt == 0) {
            return Constants.MAX_INT;
        }
        return (posValue * Constants.PINT) / debt;
    }

    function getLeverage(
        address _user
    ) external view override returns (uint256) {
        uint256 posValue = getPosValueInAsset(_user);
        uint256 debt = getDebtValueInAsset(_user);
        if (debt == 0) {
            return vaultCore.getMinLeverage();
        }

        uint256 collateral = posValue - debt;
        if (collateral <= 0) {
            return Constants.MAX_INT;
        }

        return (posValue * Constants.PINT) / collateral;
    }

    function balanceOf() public view returns (uint256) {
        return IStrategy(vaultCore.getStrategy()).balanceOf(address(this));
    }

    function totalSupply() public view returns (uint256) {
        return IERC20(vaultCore.getLedgerToken()).totalSupply();
    }

    function getBurnableShares(
        address _user
    ) external view override returns (uint256) {
        uint256 debt = getDebtValueInAsset(_user);
        uint256 posValue = getPosValueInAsset(_user);

        uint256 userLeverage = this.getLeverage(_user);
        uint256 userHF = this.hf(_user);

        if (userLeverage >= vaultCore.getMaxLeverage()) {
            return 0;
        }
        if (userHF <= vaultCore.getHFThreshold()) {
            return 0;
        }
        uint256 c1 = (debt * Constants.PINT) /
            vaultCore.getLiquidationThreshold();
        uint256 c2 = (debt * vaultCore.getMinLeverage()) /
            (vaultCore.getMaxLeverage() - Constants.PINT);
        c1 = c1 > c2 ? c1 : c2;
        return posValue - c1;
    }

    // Internal functions
    function slipped(
        uint256 _expected,
        uint256 _actual,
        uint256 _tolarance
    ) internal view returns (bool) {
        return
            !(_actual >=
                (_expected * (Constants.PINT - _tolarance)) / Constants.PINT);
    }

    function _borrow(
        address _user,
        uint256 _amount
    ) internal returns (uint256) {
        require(_amount > 0, "VM: Invalid borrow amount");
        require(_user != address(0), "VM: Invalid user address");
        return
            ILendingPool(vaultCore.getLendingPool()).borrow(
                address(this),
                _user,
                _amount
            );
    }

    function _buy(address _token, uint256 _amount) internal returns (uint256) {
        require(
            _token != address(0) &&
                _token == ILendingPool(vaultCore.getLendingPool()).wantToken(),
            "VM: Invalid token"
        );
        require(_amount > 0, "VM: Invalid amount");
        return _assetManager.buy(address(this), _token, _amount);
    }

    function _mint(address _user, uint256 _amount) internal returns (uint256) {
        uint256 _shares = (_amount * Constants.PINT) / vaultCore.getPPS();
        vaultCore.mintShares(_user, _shares);
        userTxnBlockStore[_user] = block.number;
        return _shares;
    }

    function _sell(address _token, uint256 _amount) internal returns (uint256) {
        require(
            _token != address(0) &&
                _token == ILendingPool(vaultCore.getLendingPool()).wantToken(),
            "VM: Invalid token"
        );
        require(_amount > 0, "VM: Invalid amount");
        return _assetManager.sell(address(this), _token, _amount);
    }

    function _repay(address _user, uint256 _amount) internal returns (uint256) {
        ILendingPool(vaultCore.getLendingPool()).repay(
            address(this),
            _user,
            _amount
        );
        return _amount;
    }

    function _deploy(uint256 _amount) internal returns (uint256) {
        require(_amount > 0, "VM: Invalid amount for deploy");
        vaultCore.transferToStrategy(_amount);
        IStrategy(vaultCore.getStrategy()).deposit(address(vaultCore), _amount);
    }

    function _redeem(uint256 _shares) internal returns (uint256) {
        require(_shares > 0, "VM: Invalid shares");
        return
            IStrategy(vaultCore.getStrategy()).withdraw(
                address(vaultCore),
                _shares
            );
    }

    function _borrowNBuy(
        address _user,
        uint256 _debt
    ) internal returns (uint256) {
        require(_debt > 0, "OLV: Invalid debt");
        require(
            _user != address(0) && _user != address(this),
            "OLV: Invalid Address"
        );
        ILendingPool pool = ILendingPool(vaultCore.getLendingPool());
        IERC20 want = IERC20(pool.wantToken());
        uint256 debtInWant = _assetManager.exchangeValue(
            vaultCore.getAssetToken(),
            address(want),
            _debt
        );
        uint256 borrowed = _borrow(_user, debtInWant);
        bool isApproved = want.approve(address(_assetManager), borrowed);
        if (!isApproved) revert("OLV: Approval failed");
        return _buy(pool.wantToken(), borrowed);
    }

    // Call post harvest and compound
    function setPricePerShare() internal {
        uint256 pps = Constants.PINT;
        if (totalSupply() != 0) {
            pps = (balanceOf() * Constants.PINT) / totalSupply();
        }
        vaultCore.setPPS(pps);
    }

    // Vault functions
    function deposit(
        uint256 _amount,
        uint256 _leverage,
        uint256 _expShares,
        uint256 _slippage
    ) external override blockCheck hfCheck returns (bool) {
        require(
            _leverage >= vaultCore.getMinLeverage() &&
                _leverage <= vaultCore.getMaxLeverage(),
            "VM: Invalid leverage value"
        );
        address _user = msg.sender;
        uint256 totalCollateral = getPosValueInAsset(_user) -
            getDebtValueInAsset(_user) +
            _amount;
        uint256 debt = ((_leverage - this.getLeverage(_user)) *
            totalCollateral) / Constants.PINT;
        uint256 bought = 0;

        IERC20(vaultCore.getAssetToken()).transferFrom(
            _user,
            address(vaultCore),
            _amount
        );
        if (debt > 0) {
            bought = _borrowNBuy(_user, debt);
        }
        _deploy(bought + _amount);
        uint256 minted = _mint(_user, bought + _amount);

        if (slipped(_expShares, minted, _slippage))
            revert("VM: Position slipped");
        return true;
    }

    function leverage(
        uint256 _leverage,
        uint256 _expShares,
        uint256 _slippage
    ) external override hfCheck returns (bool) {
        require(
            _leverage >= vaultCore.getMinLeverage() &&
                _leverage <= vaultCore.getMaxLeverage(),
            "VM: Invalid leverage value"
        );
        address _user = msg.sender;
        uint256 collateral = getPosValueInAsset(_user) -
            getDebtValueInAsset(_user);
        uint256 debt = ((_leverage - this.getLeverage(_user)) * collateral) /
            Constants.PINT;

        uint256 bought = _borrowNBuy(_user, debt);

        _deploy(bought);
        uint256 minted = _mint(_user, bought);

        if (slipped(_expShares, minted, _slippage))
            revert("VM: Position slipped");
        return true;
    }

    function deleverage(
        uint256 _leverage,
        uint256 _repayAmount,
        uint256 _slippage
    ) external override blockCheck hfCheck returns (bool) {
        address _user = msg.sender;
        uint256 paid = _deleverageForUser(_user, _leverage);
        if (slipped(_repayAmount, paid, _slippage))
            revert("OLV: Postion slipped");
        return true;
    }

    function _deleverageForUser(
        address _user,
        uint256 _leverage
    ) internal hfCheck returns (uint256) {
        require(
            _leverage >= vaultCore.getMinLeverage() &&
                _leverage <= vaultCore.getMaxLeverage(),
            "OLV: Invalid deleverage position"
        );

        uint256 _userLeverage = this.getLeverage(_user);
        require(_leverage < _userLeverage, "OLV: Invalid leverage");

        uint256 collateral = getPosValueInAsset(_user) -
            getDebtValueInAsset(_user);
        uint256 _shares = ((_userLeverage - _leverage) * collateral) /
            Constants.PINT;

        vaultCore.burnShares(_user, _shares);

        //burn the shares - OToken = SToken
        uint256 value = _redeem(_shares);
        uint256 sold = _sell(
            ILendingPool(vaultCore.getLendingPool()).wantToken(),
            value
        );

        return _repay(_user, sold);
    }

    function withdraw(
        uint256 _shares,
        uint256 _expTokens,
        uint256 _slippage
    ) external override blockCheck hfCheck returns (bool) {
        address _user = msg.sender;
        uint256 redeemed = _withdrawForUser(_user, _shares);
        if (slipped(_expTokens, redeemed, _slippage))
            revert("OLV: Postion slipped");
        return true;
    }

    function _withdrawForUser(
        address _user,
        uint256 _shares
    ) internal hfCheck returns (uint256) {
        require(_user != address(0), "OLV: Invalid address");
        require(_shares > 0, "OLV: Nothing to widthdraw");

        uint256 userShares = IERC20(vaultCore.getLedgerToken()).balanceOf(
            _user
        );
        require(userShares >= _shares, "OLV: Shares overflow");
        require(
            _shares <= this.getBurnableShares(_user),
            "OLV: Over leveraged"
        );

        vaultCore.burnShares(_user, _shares);
        uint256 value = _redeem(_shares);
        vaultCore.transferAsset(_user, _redeem(_shares));
        return value;
    }

    function closePosition(address _user) external override returns (bool) {
        _deleverageForUser(_user, vaultCore.getMinLeverage());
        uint256 remainingShares = this.getBurnableShares(_user);
        _withdrawForUser(_user, remainingShares);
        return true;
    }
}