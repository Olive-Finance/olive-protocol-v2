// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Constants} from "../../lib/Constants.sol";
import {IPriceHelper} from "../../helper/interfaces/IPriceHelper.sol";

import {VaultCore} from "../VaultCore.sol";

import "hardhat/console.sol";

interface RewardsRouter {
    function mintAndStakeGlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp) external returns (uint256); 
    function unstakeAndRedeemGlp(address _tokenOut, uint256 _glpAmount, uint256 _minOut, address _receiver) external returns (uint256);
}

interface GLPManager {
    function getPrice(bool) external view returns (uint256);   
}

contract GLPVault is VaultCore {
    RewardsRouter public rewardsRouter;
    address public glpManager;
    IPriceHelper public priceHelper;

    uint256 public constant GLP_PRICE_PRECISION = 10 ** 30; // Price precision in GLP

    // Empty constructor
    constructor() VaultCore(msg.sender) {}

    function setRewardsRouter(address _rewardsRouter) external onlyOwner {
        require(_rewardsRouter != address(0), "GLPC: Invalid router");
        rewardsRouter = RewardsRouter(_rewardsRouter);
    }

    function setGLPManager(address _glpManager) external onlyOwner {
        require(_glpManager != address(0), "GLPC: Invalid GLP Manager" );
        glpManager = _glpManager;
    }

    function setPriceHelper(address _priceHelper) external onlyOwner {
        require(_priceHelper != address(0), "GLPC: Invalid price helper");
        priceHelper = IPriceHelper(_priceHelper);
    }

    function buy(address _tokenIn, uint256 _amount) external whenNotPaused nonReentrant onlyMoK returns (uint256) {
        require(_tokenIn != address(0) && _amount > 0, "GLPC: Invalid inputs");
        require(IERC20(_tokenIn).balanceOf(address(this)) > 0, "GLPC: Insufficient balance");
        IERC20(_tokenIn).approve(glpManager, _amount);
        return rewardsRouter.mintAndStakeGlp(_tokenIn, _amount, 0, 0);
    }

    function sell(address _tokenOut, uint256 _amount) external whenNotPaused nonReentrant onlyMoK returns (uint256) {
        require(_tokenOut != address(0) && _amount > 0, "GLPC: Invalid inputs");
        require(asset.balanceOf(address(this)) > 0, "GLPC: Insufficient balance");
        asset.approve(glpManager, _amount);
        uint256 wantVaule = rewardsRouter.unstakeAndRedeemGlp(_tokenOut, _amount, 0, address(this));
        IERC20(_tokenOut).approve(lendingPool, wantVaule); // For lendingpool to transfer the tokens
        return wantVaule;
    }

    function priceOfAsset() public view override returns (uint256) {
        return (GLPManager(glpManager).getPrice(true) * Constants.PINT) / GLP_PRICE_PRECISION;
    }

    function getTokenValueInAsset(address _token, uint256 _tokenValue) external view override returns (uint256) {
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
}
