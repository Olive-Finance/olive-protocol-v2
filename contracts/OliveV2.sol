// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {ILendingPool} from './pools/interfaces/ILendingPool.sol';
import {IMintable} from './interfaces/IMintable.sol';
import {IStrategy} from './strategies/interfaces/IStrategy.sol';
import {IAssetManager} from './strategies/interfaces/IAssetManager.sol';

import {IOlive} from './interfaces/IOlive.sol';

import {Constants} from './utils/Contants.sol';

import {Allowed} from './interfaces/Allowed.sol';

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
    ILendingPool public _lendingPool;
  
    // Vault parameters
    uint256 public MAX_LEVERAGE;
    uint256 public MIN_LEVERAGE;
    uint256 public SLIPPAGE_TOLERANCE;
    uint256 public LIQUIDATION_THRESHOLD;

    uint256 public HF_THRESHOLD = Constants.PINT;

    // Struct to store the txn block number
    mapping(address => uint256) public userTxnBlockStore;

    // Allowed address for same block transactions
    mapping(address => bool) public allowedTxtor;

    // OTokens - Asset will share the same decimals

    constructor(
        address asset,
        address oToken,
        address strategy,
        address assetManager,
        address pool,
        uint256 minLeverage,
        uint256 maxLeverage,
        uint256 lqThreshold
    ) Allowed(msg.sender) Pausable() {
        _asset = IERC20(asset);
        _oToken = oToken;
        _strategy = IStrategy(strategy);
        _assetManager = IAssetManager(assetManager);
        _lendingPool = ILendingPool(pool);

        // Setting the default values
        MIN_LEVERAGE = minLeverage;
        MAX_LEVERAGE = maxLeverage;
        LIQUIDATION_THRESHOLD = lqThreshold;
    }

    // Vault setter functions
    function setTreasury(address treasury) public onlyAllowed returns (bool) {
        require(treasury != address(0), "OLV: Invalid treasury address");
        require(
            treasury != address(this),
            "OLV: treasury can't be the current contract"
        );
        _treasury = treasury;
        return true;
    }

    function setLiquidationThreshold(
        uint256 threshold
    ) public onlyAllowed returns (bool) {
        require(
            threshold <= Constants.PINT,
            "OLV: Invalid liquidation threshold"
        );
        LIQUIDATION_THRESHOLD = threshold;
        return true;
    }

    function setMinLeverage(uint256 minLeverage) public onlyAllowed returns(bool) {
        require(
            minLeverage >= Constants.PINT,
            "OLV: Invalid min leverage value"
        );
        MIN_LEVERAGE = minLeverage;
        return true;
    }

    function setMaxLeverage(uint256 maxLeverage) public onlyAllowed returns(bool) {
        require(
            maxLeverage > MIN_LEVERAGE && maxLeverage > MAX_LEVERAGE,
            "OLV: Invalid min leverage value"
        );
        MAX_LEVERAGE = maxLeverage;
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
    function getPosValueInAsset(address _user) public view returns (uint256) {
        require(_user != address(0), "OLV: Invalid address");
        IERC20 oToken = IERC20(_oToken);
        uint256 collateral = oToken.balanceOf(_user);
        uint256 price = this.getPricePerShare();
        return collateral.mul(price).div(Constants.PINT); // Price per share is stored in 1e18
    }

    function getDebtValueInAsset(address _user) public view returns (uint256) {
        require(_user != address(0), "OLV: Invalid address");
        uint256 debt = _lendingPool.getDebtInWant(_user); // want token usdc
        address want = _lendingPool.wantToken();
        return _assetManager.exchangeValue(address(want), address(_asset), debt);
    }

    function getPricePerShare() external view override returns (uint256) {
       return balanceOf().mul(Constants.PINT).div(totalSupply());
    }

    function balanceOf() public view returns (uint256) {
        return _asset.balanceOf(address(_strategy)).add(_asset.balanceOf(address(this)));
    }

    function totalSupply() public view returns (uint256) {
        return IERC20(_oToken).totalSupply();
    }

    function getLeverage(
        address _user
    ) external view override returns (uint256) {
        uint256 posValue = getPosValueInAsset(_user);
        uint256 debt = getDebtValueInAsset(_user);
        if (debt == 0) {
            return MIN_LEVERAGE;
        }

        uint256 collateral = posValue - debt;
        if (collateral <= 0) {
            return Constants.MAX_INT;
        }

        return posValue.mul(Constants.PINT).div(collateral);
    }

    function hf(address _user) external view returns (uint256) {
        uint256 debt = getDebtValueInAsset(_user);
        uint256 posValue = getPosValueInAsset(_user);

        if (debt == 0) {
            return Constants.MAX_INT;
        }

        return posValue.mul(LIQUIDATION_THRESHOLD).div(debt);
    }

    function getBurnableShares(
        address _user
    ) external view override returns (uint256) {
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
        uint256 c1 = debt.mul(Constants.PINT).div(LIQUIDATION_THRESHOLD);
        uint256 c2 = debt.mul(MAX_LEVERAGE).div(MAX_LEVERAGE.sub(Constants.PINT));
        c1 = c1 > c2 ? c1 : c2;
        return posValue.sub(c1);
    }

    // Vault functions
    function deposit(
        uint256 _collateral,
        uint256 _leverage,
        uint256 _expectedShares,
        uint256 _slippage
    ) external override blockCheck hfCheck returns (bool) {
        // validations
        require(
            _leverage >= MIN_LEVERAGE && _leverage <= MAX_LEVERAGE,
            "OLV: Invalid leverage value"
        );
        address _user = _msgSender();
        require(_user != address(0), "OLV: Invalid user");

        address _vault = address(this);

        // todo optimize the repeated code
        uint256 _mintedShares;
        if (_leverage == MIN_LEVERAGE) {
            _mintedShares = _deposit(_vault, _user, _collateral, uint256(0)) ;
            require(!isSlipped(_expectedShares, _mintedShares, _slippage), "OLV: Position is splipped");
            return true;
        }

        uint256 _debt = _leverage.sub(Constants.PINT).mul(_collateral).div(Constants.PINT);
        return _executeLeverage(_vault, _user, _collateral, _debt, _expectedShares, _slippage);
    }

    function leverage(uint256 _leverage, uint256 _expectedShares, uint256 _slippage) external override returns (uint256) {
        address _vault = address(this);
        require(
            (_leverage > MIN_LEVERAGE && _leverage <= MAX_LEVERAGE),
            "OLV: No leverage"
        );
        address _user = _msgSender();
        uint256 _userLeverage = this.getLeverage(_user);
        require(
            _leverage > _userLeverage,
            "OLV: Position is already leveraged"
        );

        uint256 posValue = getPosValueInAsset(_user);
        uint256 debt = getDebtValueInAsset(_user);
        uint256 _collateral = posValue - debt;

        // _debt corresponds to, new debt in asset value
        uint256 _debt = _leverage.sub(_userLeverage).mul(_collateral).div(Constants.PINT);

        return _executeLeverage(_vault, _user, uint256(0), _debt);
    }

    function _executeLeverage(
        address _vault,
        address _user,
        uint256 _collateral,
        uint256 _debt,
        uint256 _expectedShares,
        uint256 _slippage
    ) internal returns (bool) {
        require(_vault != address(0), "OLV: Invalid borrowe address");
        require(_user != address(0), "OLV: Invalid user address");
        require(_collateral > 0, "OLV: Invalid asset amount");

        // Convert them to total want to be borrowed
        IERC20 want = IERC20(_lendingPool.wantToken());
        uint256 _debtInWant = _assetManager.exchangeValue(address(_asset), address(want), _debt);

        // Borrow and Buy
        uint256 _bought = _borrowNBuy(_vault, _user, _debtInWant);

        // deposit and return the number of OTokens
        uint256 _mintedShares = _deposit(_vault, _user, _collateral, _bought);
        require(!isSlipped(_expectedShares, _mintedShares, _slippage), "OLV: Position is slipped");
        return true;
    }

    function _borrowNBuy(
        address _vault,
        address _user,
        uint256 _debtInWant
    ) internal returns (uint256) {
        //validations
        require(_vault != address(0), "OLV: Invalid borrowe address");
        require(_user != address(0), "OLV: Invalid user address");
        require(_debtInWant > 0, "OLV: Invalid borrow amount");

        // Execute borrow for total imputed want tokens
        IERC20 want = IERC20(_lendingPool.wantToken());
        uint256 _before = want.balanceOf(_vault);
        uint256 _borrowed = _lendingPool.borrow(_vault, _user, _debtInWant);
        uint256 _after = want.balanceOf(_vault);
        require(
            _after.sub(_before) >= _debtInWant,
            "OLV: Borrow failed"
        );

        // Buy asset from borrowed amount
        _before = _asset.balanceOf(_vault);
        bool isApproved = want.approve(address(_assetManager), _borrowed);
        require(isApproved, "OLV: GLP approve failed");
        uint256 _bought = _assetManager.addLiquidityForAccount(  // todo - have the simple names buy / sell for assets interface
            _vault,
            address(want),
            _borrowed
        );
        _after = _asset.balanceOf(_vault);
        require(_after.sub(_before) >= _bought, "OLV: Buying failed");

        return _bought;
    }

    function isSlipped(
        uint256 computed,
        uint256 actual,
        uint256 tolerance
    ) internal view returns (bool) {
        return computed > actual.mul(Constants.PINT.sub(tolerance)).div(Constants.PINT);
    }

    function _deposit(
        address _vault,
        address _user,
        uint _collateral,
        uint _debt
    ) internal hfCheck returns (uint256) {
        require(_vault != address(0), "OLV: Invalid borrower addresss");
        require(_user != address(0), "OLV: Invalid user address");

        uint256 amount = _collateral.add(_debt);

        uint256 _before = _asset.balanceOf(_vault); // vault address
        bool verifyBalance = _before >= _debt;
        require(verifyBalance, "OLV: Missing tokens");

        if (_collateral > 0) {
            _asset.transferFrom(_user, _vault, _collateral);
            uint256 _after = _asset.balanceOf(_vault);
            verifyBalance = _after >= _before.add(_collateral);
            require(verifyBalance, "OLV: Missing tokens");
        }

        _asset.transfer(address(_strategy), amount);
        _strategy.deposit(_vault, amount); // mint sToken

        IMintable oToken = IMintable(_oToken);
        uint256 sharesToMint = amount.mul(Constants.PINT).div(this.getPricePerShare());
        oToken.mint(_user, sharesToMint);

        userTxnBlockStore[_user] = block.number;
        return sharesToMint;
    }

    function deleverage(
        uint256 _leverage,
        uint256 _repayAmount,
        uint256 _slippage
    ) external override blockCheck hfCheck returns (bool) {
        address _user = _msgSender();
        return _deleverageForUser(_user, _leverage);
    }

    function _deleverageForUser(
        address _user,
        uint256 _leverage,
        uint256 _repayAmount,
        uint256 _slippage
    ) internal hfCheck returns (bool) {
        address _burner = address(this);
        require(_user != address(0), "OLV: Invalid user address");
        require(
            _leverage >= MIN_LEVERAGE && _leverage <= MAX_LEVERAGE,
            "OLV: Invalid deleverage position"
        );

        uint256 _userLeverage = this.getCurrentLeverage(_user);
        require(_leverage < _userLeverage, "OLV: Invalid leverage");

        uint256 collateral = getPosValueInAsset(_user); // Collateral in LP
        uint256 debt = getDebtValueInAsset(_user); // Balance in LP

        require(collateral >= debt, "OLV: Not enough collateral");
        uint256 _sharesToBurn = _userLeverage.sub(_leverage);
        _sharesToBurn = _sharesToBurn.mul(collateral.sub(debt));
        _sharesToBurn = _sharesToBurn.div(Constants.PINT); //todo add price per share and convert shares to asset value

        console.log("shares to collateral: ", collateral);
        console.log("shares to debt: ", debt);
        console.log("shares to burn: ", _sharesToBurn);
        require(_sharesToBurn < collateral, "OLV: Invalid burn");

        // Burn the released oTokens
        IMintable oBurnToken = IMintable(_oToken);
        oBurnToken.burn(_user, _sharesToBurn);

        (uint256 _Retrieved, uint256 _Repaid) = _zappNRepay(
            _burner,
            _user,
            _sharesToBurn,
            debt
        );

        // Give back the dust / remaining balance to user
        if (_Repaid < _Retrieved) {
            _asset.transfer(_user, _Retrieved.sub(_Repaid));
        }

        userTxnBlockStore[_user] = block.number;
        return true;
    }

    function _zappNRepay(
        address _burner,
        address _user,
        uint256 _sharesToBurn,
        uint256 debt
    ) internal returns (uint256, uint256) {
        //Validations
        require(_burner != address(0), "OLV: Invalid burner");
        require(_user != address(0), "OLV: Invalid user");
        require(_sharesToBurn > 0, "OLV: Invalid asset vaule");

        // Get assets from strategy
        uint256 _prevAssetBal = _asset.balanceOf(_burner);
        uint256 _assetRetrieved = _strategy.withdraw(_burner, _sharesToBurn); // Tokens are with Olive
        uint256 _postAssetBal = _asset.balanceOf(_burner);
        require(
            _postAssetBal.sub(_prevAssetBal) >= _assetRetrieved,
            "OLV: Withdraw from strategy failed"
        );

        uint256 toRepay = _assetRetrieved > debt ? debt : _assetRetrieved;
        uint256 repaid = _repayToPool(_burner, _user, toRepay);
        return (_assetRetrieved, repaid);
    }

    function _repayToPool(
        address _burner,
        address _user,
        uint256 toRepay
    ) internal hfCheck returns (uint256) {
        require(_burner != address(0), "OLV: Invalid burner");
        require(_user != address(0), "OLV: Invalid user");

        // Convert the assets to want - zap
        IERC20 want = IERC20(_lendingPool.wantToken());
        uint256 _prevWantBal = want.balanceOf(_burner);
        uint256 _wantZapped = _assetManager.removeLiquidityForAccount(
            _burner,
            address(want),
            toRepay
        );
        uint256 _postWantBal = want.balanceOf(_burner);
        require(
            _postWantBal.sub(_prevWantBal) >= _wantZapped,
            "OLV: Reverse zapping failed"
        );

        bool isApproved = want.approve(address(_lendingPool), _wantZapped);
        require(isApproved, "OLV: Approved failed to transfer to pool");
        _lendingPool.repay(_burner, _user, _wantZapped);

        return toRepay;
    }

    function withdraw(
        uint256 _shares,
        uint256 _expTokens,
        uint256 _slip
    ) external override blockCheck hfCheck returns (bool) {
        address _user = _msgSender();
        return _withdrawForUser(_user, _shares);
    }

    function _withdrawForUser(
        address _user,
        uint256 _shares
    ) internal hfCheck returns (bool) {
        require(_user != address(0), "OLV: Invalid address");
        require(_shares > 0, "OLV: Nothing to widthdraw");

        address _contract = address(this);
        IERC20 oToken = IERC20(_oToken);
        uint256 userShare = oToken.balanceOf(_user);
        require(_shares <= userShare, "OLV: Shares overflow");
        require(
            _shares <= this.getTotalWithdrawableShares(_user),
            "OLV: Over leveraged"
        );

        IMintable oBurnableToken = IMintable(_oToken);
        oBurnableToken.burn(_user, _shares);

        uint256 glpWithdrawn = _strategy.withdraw(_contract, _shares); // Tokens are with Olive

        _asset.transfer(_user, glpWithdrawn);
        userTxnBlockStore[_user] = block.number;
        return true;
    }

    function closePosition(address user) external override returns (bool) {
        _deleverageForUser(_user, MIN_LEVERAGE);
        uint256 remainingShares = this.getBurnableShares(_user);
        _withdrawForUser(_user, remainingShares);
        return true;
    }
}