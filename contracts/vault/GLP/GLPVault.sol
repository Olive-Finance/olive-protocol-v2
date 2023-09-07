// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Constants} from "../../lib/Constants.sol";
import {IPriceHelper} from "../../helper/interfaces/IPriceHelper.sol";
import {ILendingPool} from "../../pools/interfaces/ILendingPool.sol";
import {IGLPRouter, IGLPManager} from "../../strategies/GLP/interfaces/IGMXRouter.sol";

import {ArbSys} from "../../interfaces/IArbSys.sol";
import {VaultCore} from "../VaultCore.sol";

contract GLPVault is VaultCore {
    IGLPRouter public glpRouter;
    IPriceHelper public priceHelper;

    uint256 public GLP_PRICE_PRECISION = 10 ** 30; // Price precision in GLP
    address public arbSysAddress = address(100);

    // Empty constructor
    constructor() VaultCore(msg.sender) {}

    function setArbSysAddress(address _arbSysAddress) external onlyOwner {
        require(_arbSysAddress != address(0), "GLPC: Invalid Arb System address");
        arbSysAddress = _arbSysAddress;
    }

    function setGLPPrecision(uint256 _precision) external onlyOwner {
        require(_precision > 0, "GLPC: Invalid precision");
        GLP_PRICE_PRECISION = _precision;
    }

    function setRewardsRouter(address _glpRouter) external onlyOwner {
        require(_glpRouter != address(0), "GLPC: Invalid router");
        glpRouter = IGLPRouter(_glpRouter);
    }

    function setPriceHelper(address _priceHelper) external onlyOwner {
        require(_priceHelper != address(0), "GLPC: Invalid price helper");
        priceHelper = IPriceHelper(_priceHelper);
    }

    function buy(address _tokenIn, uint256 _amount) external whenNotPaused nonReentrant onlyMoK returns (uint256) {
        require(_tokenIn != address(0) && _amount > 0, "GLPC: Invalid inputs");
        require(IERC20(_tokenIn).balanceOf(address(this)) > 0, "GLPC: Insufficient balance");
        return glpRouter.mintAndStakeGlp(_tokenIn, _amount, 0, 0);
    }

    function sell(address _tokenOut, uint256 _amount) external whenNotPaused nonReentrant onlyMoK returns (uint256) {
        require(_tokenOut != address(0) && _amount > 0, "GLPC: Invalid inputs");
        require(asset.balanceOf(address(this)) > 0, "GLPC: Insufficient balance");
        uint256 wantValue = glpRouter.unstakeAndRedeemGlp(_tokenOut, _amount, 0, address(this));
        return wantValue;
    }

    function priceOfAsset() public view override returns (uint256) {
        return (IGLPManager(glpRouter.glpManager()).getPrice(true) * Constants.PINT) / GLP_PRICE_PRECISION;
    }

    function getTokenValueInAsset(address _token, uint256 _tokenValue) public view override returns (uint256) {
        if (_tokenValue == 0) {
            return 0;
        }
        uint8 decimalDiff =  IERC20Metadata(address(asset)).decimals() - IERC20Metadata(_token).decimals();
        return ((_tokenValue * priceHelper.getPriceOf(_token)) * (10**decimalDiff)) / priceOfAsset();
    }

    function getTokenValueforAsset(address _token, uint256 _assetValue) external view returns (uint256) {
        if (_assetValue == 0) {
            return 0;
        }
        uint8 decimalDiff =  IERC20Metadata(address(asset)).decimals() - IERC20Metadata(_token).decimals();
        return (_assetValue * priceOfAsset()) / (priceHelper.getPriceOf(_token) * (10**decimalDiff));
    }

    function getPosition(address _user) public view override returns (uint256) {
        require(_user != address(0), "GLPC: Invalid address");
        return (oToken.balanceOf(_user) * getPPS()) / Constants.PINT;
    }

    function getDebt(address _user) public view override returns (uint256) {
        require(_user != address(0), "GLPC: Invalid address");
        ILendingPool pool = ILendingPool(lendingPool);
        return getTokenValueInAsset(pool.wantToken(), pool.getDebt(_user));
    }

    function getCollateral(address _user) external view override returns (uint256) {
        return getPosition(_user) - getDebt(_user);
    }

    function hf(address _user) public view override returns (uint256) {
        uint256 debt = getDebt(_user);
        if (debt == 0) {
            return Constants.MAX_INT;
        }
        return (getPosition(_user) * LIQUIDATION_THRESHOLD) / debt;
    }

    function isHealthy(address _user) external view override returns (bool) {
        return hf(_user) >= HF_THRESHOLD;
    }

    function setAllowance(address token, address spender, bool max) external onlyOwner {
        require(token != address(0) && spender != address(0), "GLPC: Invalid addresses");
        IERC20(token).approve(spender, max ? Constants.MAX_INT : 0);
    }

    function blockNumber() external view override returns (uint256) {
        // ArbSys is a precompiled contract at address(100)
        // address(100) == 0x0000000000000000000000000000000000000064
        return ArbSys(arbSysAddress).arbBlockNumber();
    }
}
