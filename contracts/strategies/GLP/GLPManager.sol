// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';

import {IAssetManager} from '../../interfaces/IAssetManager.sol';
import {IMintable} from '../../interfaces/IMintable.sol';

contract GLPManager is IAssetManager {
    using SafeMath for uint256;

    address private _glpToken;
    mapping (address => uint256) private _priceFeed;

    uint16 private MAX_BPS = 1e4;

    constructor(address glpToken) {
        _glpToken = glpToken;
    } 

    function getPrice(
        address _asset,
        uint256 _value
    ) external override view returns (uint256) {
        uint256 pricePerUnit = _priceFeed[_asset];
        require(pricePerUnit > 0, 'GLP: Missing price feed');

        return _value.mul(pricePerUnit).div(MAX_BPS);
    }

    function getBurnPrice(
        address _asset,
        uint256 _value
    ) external override view returns (uint256) {
        uint256 pricePerUnit = _priceFeed[_asset];
        require(pricePerUnit > 0, 'GLP: Missing price feed');

        return _value.mul(MAX_BPS).div(pricePerUnit);
    }

    function addLiquidityForAccount(
        address _user,
        address _asset,
        uint256 _value
    ) external override returns (uint256) {
        require(_user != address(0), "GLP: Null address");
        require(_asset != address(0), "GLP: Invalid asset");
        require(_value > 0, "GLP: Invalid value");

        uint256 glpToMint = this.getPrice(_asset, _value);

        IERC20 asset = IERC20(_asset);
        uint256 balanceBefore = asset.balanceOf(address(this));
        asset.transferFrom(_user, address(this), _value);
        uint256 balanceAfter = asset.balanceOf(address(this));

        require((balanceAfter - balanceBefore) == _value, 'GLP: Invalid transfer');

        IMintable glpToken = IMintable(_glpToken);
        glpToken.mint(_user, glpToMint);

        return glpToMint;
    }

    function removeLiquidityForAccount(
        address _user,
        address _asset,
        uint256 _value
    ) external override returns (uint256) {
        require(_user != address(0), "GLP: Null address");
        require(_asset != address(0), "GLP: Invalid asset");
        require(_value > 0, "GLP: Invalid value");

        uint256 _assetValue = this.getBurnPrice(_asset, _value);

        IERC20 asset = IERC20(_asset);
        uint256 balanceBefore = asset.balanceOf(address(this));
        asset.transfer(_user, _assetValue);
        uint256 balanceAfter = asset.balanceOf(address(this));
        require((balanceBefore - balanceAfter) == _assetValue, 'GLP: Invalid transfer');

        IMintable glpToken = IMintable(_glpToken);
        glpToken.burn(_user, _value);

        return _assetValue;
    }

    function setPrice(address _asset, uint _value) public returns (bool) {
        _priceFeed[_asset] = _value;
        return true;
    }
}