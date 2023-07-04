// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';

import {IStrategy} from './interfaces/IStrategy.sol';
import {IMintable} from '../interfaces/IMintable.sol';

import {IGMXRouter}  from './GLP/interfaces/IGMXRouter.sol';
import {Allowed} from '../interfaces/Allowed.sol';

contract Strategy is IStrategy, Allowed {
    //List of addresses
    IERC20 public asset;
    IERC20 public rToken;

    IERC20 public sToken;

    address public treasury;

    IGMXRouter public _gmxRouter;

    uint256 public lastHarvest;

    constructor(
        address _asset,
        address _sToken,
        address _treasury
    ) Allowed(msg.sender) {
        asset = IERC20(_asset);
        sToken = IERC20(_sToken);
        treasury = _treasury;
    }

    function setRewardsToken(address _rewardsToken) public onlyOwner {
        require(_rewardsToken != address(0), "STR: Invalid rewards address");
        rToken = IERC20(_rewardsToken);
    }

    function setGMXRouter(address gmxRouter) public onlyOwner {
        require(gmxRouter != address(0) || gmxRouter != address(this), "STR: Invalid address");
        _gmxRouter = IGMXRouter(gmxRouter);
    }

    function setTreasury(address _treasury) public onlyOwner {
        require(_treasury != address(0) || _treasury != address(this), "STR: Invalid address");
        treasury = _treasury;
    }

    function deposit(address _user, uint256 _amount) external override {
        require(_user != address(0), "Strat: Null address");
        require(_amount > 0, "STR: Zero/Negative amount");

        IMintable lpToken = IMintable(address(sToken));
        lpToken.mint(_user, _amount);
    }

    function withdraw(
        address _user,
        uint256 _amount
    ) external override returns (uint256) {
        require(_amount > 0, "STR: Zero/Negative amount");
        uint256 tokenBalance = sToken.balanceOf(_user);
        require(tokenBalance >= _amount, "STR: Insufficient balance");

        IMintable sBurnToken = IMintable(address(sToken));
        sBurnToken.burn(_user, _amount);
        asset.transfer(_user, _amount);
        return _amount;
    }

    function harvest() external override {
        _gmxRouter.compound();   // Claim and restake esGMX and multiplier points
        _gmxRouter.claimFees();
        uint256 nativeBal = rToken.balanceOf(address(this));
        if (nativeBal > 0) {
            //chargeFees(callFeeRecipient);
            uint256 before = this.balance();
            mintGlp();
            uint256 wantHarvested = this.balance() - (before);
            
            // todo emit and event with harvested amount and collect the fees
            lastHarvest = block.timestamp;
        }

    }

    // mint more GLP with the ETH earned as fees
    function mintGlp() internal {
        uint256 nativeBal = rToken.balanceOf(address(this));
        _gmxRouter.mintAndStakeGlp(address(rToken), nativeBal, 0, 0);
    }

    function balance() external view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function balanceOf(address _user) external view override returns (uint256) {
        return sToken.balanceOf(_user);
    }
}