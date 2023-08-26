// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {Constants} from "../lib/Constants.sol";

import {IFees} from "../fees/interfaces/IFees.sol";
import {IClaimRouter, IGLPRouter}  from "./GLP/interfaces/IGMXRouter.sol";
import {IRewardManager} from "../interfaces/IRewardManager.sol";
import {IVaultCore} from "../vault/interfaces/IVaultCore.sol";
import {Allowed} from "../utils/Allowed.sol";

contract GLPStrategy is IStrategy, Allowed {
    //List of addresses
    IERC20 public asset;
    IERC20 public rToken;
    IERC20 public sToken;

    // GLP Routers
    IClaimRouter public claimRouter;
    IGLPRouter public glpRouter;

    uint256 public lastHarvest;
    uint256 public pps;
    address public keeper;
    
    // Ledger for validating transfers
    uint256 public assetBalance;

    IFees public fees;

    // VaultCore for price conversions
    IVaultCore public vaultCore;

    // OliveManager
    IRewardManager public oliveRewards;

    mapping (address => mapping(address => bool)) handler;

    event Harvest(address indexed asset, address indexed strategy, uint256 amount);

    constructor(address _asset, address _sToken) Allowed(msg.sender) {
        asset = IERC20(_asset);
        sToken = IERC20(_sToken);
        pps = Constants.PINT;
    }

    modifier onlyKeeper {
        require(msg.sender == keeper || msg.sender == address(this), "STR: Insufficient previlages");
        _;  
    }

    modifier onlyHandler (address _user) {
        if (_user != msg.sender) {
            require(handler[_user][msg.sender], "STR: Invalid handler");
        }
        _;
    }

    function setFees(address _fees) public onlyOwner {
        require(_fees != address(0), "STR: Invalid fees address");
        fees = IFees(_fees);
    }

    function setKeeper(address _keeper) public onlyOwner {
        require(_keeper != address(0), "STR: Invalid keeper");
        keeper = _keeper;
    }

    function setRewardsToken(address _rewardsToken) public onlyOwner {
        require(_rewardsToken != address(0), "STR: Invalid rewards address");
        rToken = IERC20(_rewardsToken);
    }

    function setGLPRouters(address _claimRouter, address _glpRouter) public onlyOwner {
        require(_claimRouter != address(0) && _glpRouter != address(0), "STR: Invalid address");
        claimRouter = IClaimRouter(_claimRouter);
        glpRouter = IGLPRouter(_glpRouter);
    }

    function setVaultCore(address _vaultCore) public onlyOwner {
        require(_vaultCore != address(0), "STR: Invalid vaultCore");
        vaultCore = IVaultCore(vaultCore);
    }

    function setRewardManager(address _rewardManager) public onlyOwner {
        require(_rewardManager != address(0), "STR: Invalid reward manager");
        oliveRewards = IRewardManager(_rewardManager);
    }

    function deposit(address _user, uint256 _amount) external override whenNotPaused nonReentrant onlyAllowed onlyHandler(_user)   {
        require(_amount > 0, "STR: Zero/Negative amount");
        require(asset.balanceOf(address(this)) - assetBalance >= _amount, "STR: No token transfer");
        assetBalance += _amount;
        IMintable soToken = IMintable(address(sToken));
        soToken.mint(_user, getShares(_amount));
    }

    function getShares(uint256 _amount) internal view returns (uint256) {
        return (_amount * Constants.PINT)/pps;
    }

    function getAmount(uint256 _shares) internal view returns (uint256) {
        return (_shares * pps)/Constants.PINT;
    }

    function withdraw(address _user, uint256 _shares) external override whenNotPaused nonReentrant onlyAllowed onlyHandler(_user) returns (uint256) {
        require(_shares > 0, "STR: Zero/Negative amount");
        require(sToken.balanceOf(_user) >= _shares, "STR: Insufficient balance");
        IMintable(address(sToken)).burn(_user, _shares);
        uint256 amount = getAmount(_shares);
        assetBalance -= amount;
        asset.transfer(_user, amount);
        return amount;
    }

    function harvest() public override onlyKeeper {
        claimRouter.compound();  
        claimRouter.claimFees();
        uint256 nativeBal = rToken.balanceOf(address(this));
        if (nativeBal > 0) {
            chargeFees(nativeBal); 
            uint256 before = this.balance();
            mintGlp();
            emit Harvest(address(asset), address(this), this.balance() - before);
            lastHarvest = block.timestamp;
        }
        setPPS();
    }

    function chargeFees(uint256 yield) internal {
        uint256 pFees = (yield * fees.getPFee())/ Constants.PINT;
        uint256 mFees = vaultCore.getTokenValueforAsset(address(rToken), fees.getAccumulatedFee());
        uint256 toOliveHolders = (pFees * fees.getRewardRateForOliveHolders()) / Constants.HUNDRED_PERCENT;
        uint256 feeLimit =  ((yield * 5)/10) - pFees;
        if(feeLimit > pFees) {
            chargeManagementFee(feeLimit, mFees);
        }

        rToken.transfer(fees.getTreasury(), pFees - toOliveHolders);
        rToken.transfer(address(oliveRewards), toOliveHolders);
        oliveRewards.notifyRewardAmount(toOliveHolders);
    }

    function chargeManagementFee(uint256 _limit, uint256 _accruedFees) internal {
        uint256 managementfee = _limit > _accruedFees ? _accruedFees: _limit;
        rToken.transfer(fees.getTreasury(), managementfee);
        if ( _limit > _accruedFees) {
            fees.setFee(0, block.timestamp);
            return;
        } 
        fees.setFee(fees.getAccumulatedFee()-vaultCore.getTokenValueInAsset(address(rToken), managementfee), block.timestamp);
    }

    function setPPS() internal {
        if (sToken.totalSupply() == 0) {
            pps = Constants.PINT;
        }
        pps = (asset.balanceOf(address(this)) * Constants.PINT)/sToken.totalSupply();
    }

    // mint more GLP with the ETH earned as fees
    function mintGlp() internal {
        uint256 rewardBalance = rToken.balanceOf(address(this));
        rToken.approve(glpRouter.glpManager(), rewardBalance);
        glpRouter.mintAndStakeGlp(address(rToken), rewardBalance, 0, 0);
    }

    function balance() external view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function balanceOf(address _user) external view override returns (uint256) {
        return getAmount(sToken.balanceOf(_user));
    }

    function setHandler(address _addr, address _handler, bool _enabled) external onlyOwner {
        require(_addr != address(0) && _handler != address(0), "STR: Invalid addresses");
        handler[_addr][_handler] = _enabled;
        emit HandlerChanged(_addr, _handler, _enabled);
    } 

    // Migration to new strategy
    function migrate(address _to) external whenPaused onlyOwner {
        // transfer the tokens
        harvest();
        asset.transfer(_to, asset.balanceOf(address(this)));
    }
}