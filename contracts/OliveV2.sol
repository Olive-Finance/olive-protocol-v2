// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IMintable} from './interfaces/IMintable.sol';
import {IOlive} from './interfaces/IOlive.sol';
import {ILendingPool} from './interfaces/ILendingPool.sol';
import {IStrategy} from './interfaces/IStrategy.sol';
import {Allowed} from './utils/modifiers/Allowed.sol';
import {IAssetManager} from './interfaces/IAssetManager.sol';

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';

import "hardhat/console.sol";

contract OliveV2 is IOlive, Pausable, Allowed {
    using SafeMath for uint256;
    using SafeMath for uint16;

    //Address locations for each of the tokens
    IERC20 public _asset;
    address public _oToken;

    //Address for strategy
    IStrategy public _strategy;

    //Address for Asset Manager
    IAssetManager public _assetManager;

    //Olive treasury address
    address public _treasury;

    // Pool for borrowing
    ILendingPool public _pool;

    // Definition of constants
    uint256 public ONE_IN_DECIMAL_FOUR = 1e4;
    uint256 public ONE_IN_DECIMAL_TWO = 1e2;

    // Definition MIN-MAX Leverage
    uint256 public MAX_LEVERAGE; 
    uint256 public MIN_LEVERAGE; 

    uint256 public HF_THRESHOLD;

    uint256 public SLIP_TOLERANCE;

    uint256 public LIQUIDATION_THRESHOLD;

    // Struct to store the txn block number
    mapping(address => uint256) public userTxnBlockStore;

    // Allowed address for same block transactions
    mapping(address => bool) public allowedTxtor;

    constructor(
        address asset,
        address oToken,
        address strategy,
        address assetManager,
        address pool,
        uint256 minLeverage,
        uint256 maxLeverage
    ) Allowed(msg.sender) Pausable() {
        _asset = IERC20(asset);
        _oToken = oToken;
        _strategy = IStrategy(strategy);
        _assetManager = IAssetManager(assetManager);
        _pool = ILendingPool(pool);

        // Setting the default values
        MIN_LEVERAGE = minLeverage;
        MAX_LEVERAGE = maxLeverage;
        HF_THRESHOLD = 1e2;

        SLIP_TOLERANCE = 0.05e2;
        LIQUIDATION_THRESHOLD = 0.9e4;
    }

    function setTreasury(address treasury) public onlyAllowed returns (bool) {
        require(treasury != address(0), "OLV: Invalid treasury address");
        _treasury = treasury;
        return true;
    }

    function setLiquidationThreshold(uint256 threshold) public onlyAllowed returns (bool) {
        require(threshold <= ONE_IN_DECIMAL_FOUR, "OLV: Invalid liquidation threshold");
        LIQUIDATION_THRESHOLD = threshold;
        return true;
    }

    // List of modifiers for protection
    // Pre - modifiers
    modifier blockCheck() {
        address caller = _msgSender();
        if (!allowedTxtor[caller]) {
            require(
                userTxnBlockStore[caller] != block.number,
                "OLV: Txn not allowed"
            );
        }
        _;
    }

    // Post - modifiers
    modifier hfCheck() {
        address caller = _msgSender();
        _;
        require(
            this.hf(caller) > HF_THRESHOLD,
            "OLV: Degarded HF, Liquidation risk"
        );
    }

    // List of view functions
    function getCollateralInLP(address _user) public view returns (uint256) {
        require(_user != address(0), "OLV: Invalid address");
        IERC20 oToken = IERC20(_oToken);
        uint256 collateral = oToken.balanceOf(_user);
        uint256 price = this.getPricePerShare();
        collateral = collateral.mul(price);
        collateral = collateral.div(ONE_IN_DECIMAL_FOUR); // Collateral is converted to LP
        return collateral;
    }

    function getDebtInLP(address _user) public view returns (uint256) {
        require(_user != address(0), "OLV: Invalid address");
        IERC20 dToken = IERC20(_pool.debtToken());
        address want = _pool.wantToken();
        uint256 debtInLP = _assetManager.getPrice(want, dToken.balanceOf(_user));
        return debtInLP;
    }

    function getPricePerShare(
    ) external view override returns (uint256) {
        return ONE_IN_DECIMAL_FOUR;
    }

    function getCurrentLeverage(
        address _user
    ) external view override returns (uint256) {
        uint256 collateral = getCollateralInLP(_user);
        console.log('LP-eq Collateral: ', collateral.div(1e8));
        uint256 debt = getDebtInLP(_user); 
        console.log('LP-eq Debt: ', debt.div(1e8));

        if (debt == 0) {
            return MIN_LEVERAGE; // No debt case is leverage 1
        }
        console.log('Debt: ', debt.div(1e8));

        uint256 userAssets = collateral - debt;
        console.log('Assets: ', userAssets.div(1e8));

        if (userAssets == 0) {
            return ONE_IN_DECIMAL_FOUR;
        }

        uint256 _leverage = debt.mul(ONE_IN_DECIMAL_TWO).div(userAssets).add(ONE_IN_DECIMAL_TWO);
        return _leverage;
    }
    
    function hf(address _user) public view returns (uint256) {
        uint256 debt = getDebtInLP(_user);
        uint256 collateral = getCollateralInLP(_user);
        
        if (debt == 0) {
            return ONE_IN_DECIMAL_FOUR;
        }

        return collateral.mul(LIQUIDATION_THRESHOLD).div(debt).div(ONE_IN_DECIMAL_TWO);
    }

    function getTotalWithdrawableShares(
        address _user
    ) external  override view returns (uint256) {
        // todo - residual value fixes
        uint256 debt = getDebtInLP(_user);
        uint256 collateral = getCollateralInLP(_user);
        uint256 userLeverage = this.getCurrentLeverage(_user);
        uint256 userHF = this.hf(_user);
        if (userLeverage >= MAX_LEVERAGE) {
            return 0;
        }
        if (userHF <= HF_THRESHOLD) {
            return 0;
        }
        uint256 c1 = debt.mul(ONE_IN_DECIMAL_FOUR).div(LIQUIDATION_THRESHOLD);
        uint256 c2 = debt.mul(MAX_LEVERAGE).div(MAX_LEVERAGE.sub(MIN_LEVERAGE));
        c1 = c1 > c2 ? c1 : c2;
        return collateral.sub(c1);
    }

    // Vault functions

    function deposit(
        uint256 _uaAmount,
        uint16 _leverage
    ) external override blockCheck hfCheck returns (bool) {
        // validations
        require(
            _leverage >= MIN_LEVERAGE && _leverage <= MAX_LEVERAGE,
            "OLV: Invalid leverage value"
        );
        address _user = _msgSender();
        require(_user != address(0), "OLV: Invalid user");

        address _borrower = address(this);

        if (_leverage == MIN_LEVERAGE) {
            return _depositForUser(_user, _uaAmount, uint256(0));
        }

        // Compute how much more assets to be zapped for covering the leverage
        uint256 _assetDelta = _leverage.sub(ONE_IN_DECIMAL_TWO).mul(_uaAmount);
        _assetDelta = _assetDelta.div(ONE_IN_DECIMAL_TWO);

        return _executeLeverage(_borrower, _user, _assetDelta, _uaAmount);
    }

    function leverage(uint256 _leverage) external override returns (bool) {
        address _borrower = address(this);
        require((_leverage > MIN_LEVERAGE && _leverage <= MAX_LEVERAGE), "OLV: No leverage");
        address _user = _msgSender();
        uint256 _userLeverage = this.getCurrentLeverage(_user);
        require(_leverage > _userLeverage, "OLV: Position is already leveraged");

        uint256 collateral = getCollateralInLP(_user);
        uint256 debt = getDebtInLP(_user);
        uint256 _userAsset = collateral - debt;

        // Compute how much more assets to be zapped for covering the leverage
        uint256 _assetDelta = _leverage.sub(_userLeverage).mul(_userAsset);
        _assetDelta = _assetDelta.div(ONE_IN_DECIMAL_TWO);

        return _executeLeverage(_borrower, _user, _assetDelta, uint256(0));
    }

    function _executeLeverage(
        address _borrower, 
        address _user, 
        uint256 _assetDelta, uint256 _userAsset) internal returns (bool) {
        
        require(_borrower != address(0), "OLV: Invalid borrowe address");
        require(_user != address(0), "OLV: Invalid user address");
        require(_assetDelta > 0, "OLV: Invalid asset amount");

        // Convert them to total want to be borrowed
        IERC20 want = IERC20(_pool.wantToken());
        uint256 _wantToBorrow = _assetManager.getBurnPrice(
            address(want),
            _assetDelta
        );

        // Borrow and Zap
        uint256 _zapped = _borrowNZap(_borrower, _user, _wantToBorrow);

        // Check the slippage
        bool slipped = isSlipped(_assetDelta, _zapped, SLIP_TOLERANCE);
        require(!slipped, "OLV: Zapping slipped the position");
        
        // Once zapping happend, do the deposit and mint OTokens
        return _depositForUser(_user, _userAsset, _zapped);
    }

    function _borrowNZap(
        address _borrower, 
        address _user, uint256 _wantToBorrow) internal returns (uint256) {
        //validations
        require(_borrower != address(0), "OLV: Invalid borrowe address");
        require(_user != address(0), "OLV: Invalid user address");
        require(_wantToBorrow > 0, "OLV: Invalid borrow amount");
        
        // Execute borrow for total imputed want tokens
        IERC20 want = IERC20(_pool.wantToken());
        uint256 preWantBal = want.balanceOf(_borrower);
        uint256 _wantBorrowed = _pool.borrow(_borrower, _user, _wantToBorrow);
        uint256 postWantBal = want.balanceOf(_borrower);
        require(
            postWantBal.sub(preWantBal) >= _wantToBorrow,
            "OLV: Borrow failed"
        );

        // Zap borrowed assets with AssetManager
        uint256 preZapBal = _asset.balanceOf(_borrower);
        bool isApproved = want.approve(address(_assetManager), _wantBorrowed);
        require(isApproved, 'OLV: GLP approve failed');
        uint256 _zapped = _assetManager.addLiquidityForAccount(
            _borrower,
            address(want),
            _wantBorrowed
        );
        uint256 postZapBal = _asset.balanceOf(_borrower);
        require(postZapBal.sub(preZapBal) >= _zapped, "OLV: Zapping failed");

        return _zapped;
    }

    function isSlipped(
        uint256 computed,
        uint256 actual,
        uint256 tolerance
    ) internal view returns (bool) {
        if (actual >= computed) {
            return false;
        }
        uint256 slip = computed.sub(actual).mul(ONE_IN_DECIMAL_TWO);
        slip = slip.div(computed);
        return slip > tolerance;
    }

    function _depositForUser(
        address _user,
        uint _userOwned,
        uint _userBorrowed
    ) internal hfCheck returns (bool) {
        require(_user != address(0), "OLV: Invalid user address");
        
        uint256 amount = _userOwned.add(_userBorrowed);

        uint256 prevContractBalance = _asset.balanceOf(address(this));
        bool verifyBalance = prevContractBalance >= _userBorrowed;
        require(verifyBalance, "OLV: Missing tokens");

        if (_userOwned > 0) {
            _asset.transferFrom(_user, address(this), _userOwned);
            uint256 postContractBalance = _asset.balanceOf(address(this));
            verifyBalance =
                postContractBalance >= prevContractBalance.add(_userOwned);
            require(verifyBalance, "OLV: Missing tokens");
        }

        _asset.transfer(address(_strategy), amount);
        _strategy.deposit(address(this), amount);

        IMintable oToken = IMintable(_oToken);
        oToken.mint(_user, amount);

        userTxnBlockStore[_user] = block.number;
        return true;
    }

    function deleverage(uint16 _leverage) external blockCheck hfCheck override returns (bool) {
        address _user = _msgSender();
        return _deleverageForUser(_user, _leverage);
    }

    function _deleverageForUser(address _user, uint16 _leverage) internal hfCheck returns (bool) {
        address _burner = address(this);
        require(_user != address(0), "OLV: Invalid user address");
        require(_leverage >= MIN_LEVERAGE && _leverage <= MAX_LEVERAGE, "OLV: Invalid deleverage position");
        
        uint256 _userLeverage = this.getCurrentLeverage(_user);
        require (_leverage < _userLeverage, "OLV: Invalid leverage"); 

        uint256 collateral = getCollateralInLP(_user); // Collateral in LP
        uint256 debt = getDebtInLP(_user); // Balance in LP

        require(collateral >= debt, "OLV: Not enough collateral");
        uint256 _sharesToBurn = _userLeverage.sub(_leverage);
        _sharesToBurn = _sharesToBurn.mul(collateral.sub(debt));
        _sharesToBurn = _sharesToBurn.div(ONE_IN_DECIMAL_TWO); //todo add price per share and convert shares to asset value

        console.log('shares to collateral: ', collateral);
        console.log('shares to debt: ', debt);
        console.log('shares to burn: ', _sharesToBurn);
        require(_sharesToBurn < collateral, "OLV: Invalid burn");

        // Burn the released oTokens
        IMintable oBurnToken = IMintable(_oToken);
        oBurnToken.burn(_user, _sharesToBurn);

        (uint256 _Retrieved, uint256 _Repaid) = _zappNRepay(_burner, _user, _sharesToBurn, debt);

        // Give back the dust / remaining balance to user
        if (_Repaid < _Retrieved) {
            _asset.transfer(_user, _Retrieved.sub(_Repaid)); 
        }

        return true;
    }

    function _zappNRepay(
        address _burner, 
        address _user, 
        uint256 _sharesToBurn, uint256 debt) internal returns (uint256, uint256) {
        //Validations
        require(_burner != address(0), "OLV: Invalid burner");
        require(_user != address(0), "OLV: Invalid user");
        require(_sharesToBurn > 0, "OLV: Invalid asset vaule");

        // Get assets from strategy
        uint256 _prevAssetBal = _asset.balanceOf(_burner);
        uint256 _assetRetrieved = _strategy.withdraw(_burner, _sharesToBurn); // Tokens are with Olive
        uint256 _postAssetBal = _asset.balanceOf(_burner);
        require(_postAssetBal.sub(_prevAssetBal) >= _assetRetrieved, "OLV: Withdraw from strategy failed");

        uint256 toRepay = _assetRetrieved > debt ? debt: _assetRetrieved;
        uint256 repaid = _repayToPool(_burner, _user, toRepay);
        return (_assetRetrieved , repaid);
    }

    function _repayToPool(address _burner, 
        address _user, uint256 toRepay) internal hfCheck returns (uint256) {
        
        require(_burner != address(0), "OLV: Invalid burner");
        require(_user != address(0), "OLV: Invalid user");

        // Convert the assets to want - zap
        IERC20 want = IERC20(_pool.wantToken());
        uint256 _prevWantBal = want.balanceOf(_burner);
        uint256 _wantZapped = _assetManager.removeLiquidityForAccount(_burner, address(want), toRepay);
        uint256 _postWantBal = want.balanceOf(_burner);
        require(_postWantBal.sub(_prevWantBal) >= _wantZapped, "OLV: Reverse zapping failed");

        bool isApproved = want.approve(address(_pool), _wantZapped);
        require(isApproved, "OLV: Approved failed to transfer to pool");
        _pool.repay(_burner, _user, _wantZapped);

        return toRepay;
    }

    function withdraw(uint256 _shares) external blockCheck hfCheck override returns (bool) {
        address _user = _msgSender(); 
        return _withdrawForUser(_user, _shares);
    }

    function _withdrawForUser(address _user, uint256 _shares) internal hfCheck returns (bool) {
        require(_user != address(0), "OLV: Invalid address");
        require(_shares > 0, "OLV: Nothing to widthdraw");

        address _contract = address(this);
        IERC20 oToken = IERC20(_oToken);
        uint256 userShare = oToken.balanceOf(_user);
        require(_shares <= userShare, 'OLV: Shares overflow');
        require(_shares <= this.getTotalWithdrawableShares(_user), 'OLV: Over leveraged');
        
        IMintable oBurnableToken = IMintable(_oToken);
        oBurnableToken.burn(_user, _shares);

        uint256 glpWithdrawn = _strategy.withdraw(_contract, _shares); // Tokens are with Olive
       
        _asset.transfer(_user, glpWithdrawn);
        return true;
    }

    function closePosition() external override returns (bool) {
        address _user = _msgSender();
        _deleverageForUser(_user, uint8(MIN_LEVERAGE));
        uint256 remainingShares = this.getTotalWithdrawableShares(_user);
        _withdrawForUser(_user, remainingShares);
        return true;
    }
}