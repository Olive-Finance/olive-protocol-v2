// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';

import {IStrategy} from './interfaces/IStrategy.sol';
import {IMintable} from '../interfaces/IMintable.sol';

import {IGMXRouter}  from './GLP/interfaces/IGMXRouter.sol';

contract Strategy is IStrategy {
    //List of addresses
    IERC20 public _asset;
    IERC20 public _native;

    address public _sToken;

    address public _treasury;

    IGMXRouter public _gmxRouter;

    uint256 public lastHarvest;

    using SafeMath for uint256;

    constructor(
        address asset,
        address sToken,
        address treasury
    ) {
        _asset = IERC20(asset);
        _sToken = sToken;
        _treasury = treasury;
    }

    function deposit(address _user, uint256 _amount) external override {
        require(_user != address(0), "Strat: Null address");
        require(_amount > 0, "STR: Zero/Negative amount");

        IMintable lpToken = IMintable(_sToken);
        lpToken.mint(_user, _amount);
    }

    function withdraw(
        address _user,
        uint256 _amount
    ) external override returns (uint256) {
        require(_amount > 0, "STR: Zero/Negative amount");

        IERC20 sToken = IERC20(_sToken); // strategy shares
        uint256 tokenBalance = sToken.balanceOf(_user);

        require(tokenBalance >= _amount, "STR: Insufficient balance");

        IMintable sBurnToken = IMintable(_sToken);
        sBurnToken.burn(_user, _amount);

        IERC20 asset = IERC20(_asset); // Transfer the amount
        asset.transfer(_user, _amount);

        return _amount;
    }

    function harvest() external override {
        _gmxRouter.compound();   // Claim and restake esGMX and multiplier points
        _gmxRouter.claimFees();
        uint256 nativeBal = _native.balanceOf(address(this));
        if (nativeBal > 0) {
            //chargeFees(callFeeRecipient);
            uint256 before = this.balance();
            mintGlp();
            uint256 wantHarvested = this.balance().sub(before);
            
            // todo emit and event with harvested amount and collect the fees
            lastHarvest = block.timestamp;
        }

    }

    // mint more GLP with the ETH earned as fees
    function mintGlp() internal {
        uint256 nativeBal = _native.balanceOf(address(this));
        _gmxRouter.mintAndStakeGlp(address(_native), nativeBal, 0, 0);
    }

    function balance() external view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }
}