// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {IAssetManager} from '../interfaces/IAssetManager.sol';
import {IMintable} from '../../interfaces/IMintable.sol';

import {Constants} from '../../lib/Constants.sol';

contract GLPManager is IAssetManager {
    using SafeMath for uint256;

    address private _glpToken;
    mapping(address => uint256) private _priceFeed;

    uint16 private MAX_BPS = 1e4;

    constructor(address glpToken) {
        _glpToken = glpToken;
    }

    function buy(
        address _user,
        address _asset,
        uint256 _value
    ) external override returns (uint256) {
        require(_user != address(0), "GLP: Null address");
        require(_asset != address(0), "GLP: Invalid asset");
        require(_value > 0, "GLP: Invalid value");

        uint256 glpToMint = this.exchangeValue(_asset, _glpToken, _value);

        IERC20 asset = IERC20(_asset);
        uint256 balanceBefore = asset.balanceOf(address(this));
        asset.transferFrom(_user, address(this), _value);
        uint256 balanceAfter = asset.balanceOf(address(this));

        require(
            (balanceAfter - balanceBefore) == _value,
            "GLP: Invalid transfer"
        );

        IMintable glpToken = IMintable(_glpToken);
        glpToken.mint(_user, glpToMint);

        return glpToMint;
    }

    function sell(
        address _user,
        address _asset,
        uint256 _value
    ) external override returns (uint256) {
        require(_user != address(0), "GLP: Null address");
        require(_asset != address(0), "GLP: Invalid asset");
        require(_value > 0, "GLP: Invalid value");

        uint256 _assetValue = this.exchangeValue(_glpToken, _asset, _value);

        IERC20 asset = IERC20(_asset);
        uint256 balanceBefore = asset.balanceOf(address(this));
        asset.transfer(_user, _assetValue);
        uint256 balanceAfter = asset.balanceOf(address(this));
        require(
            (balanceBefore - balanceAfter) == _assetValue,
            "GLP: Invalid transfer"
        );

        IMintable glpToken = IMintable(_glpToken);
        glpToken.burn(_user, _value);

        return _assetValue;
    }

    function setPrice(address _asset, uint _value) public returns (bool) {
        _priceFeed[_asset] = _value;
        return true;
    }

    function exchangeValue(
        address _from,
        address _to,
        uint256 _amount
    ) external override view returns (uint256) {
        // Example Pricefeed ->  [USDC, DAI, ETH], [0.96GLP, 1GLP, 1000GLP ]
        bool invert = _from == _glpToken;

        IERC20Metadata fromMeta = IERC20Metadata(_from);
        IERC20Metadata toMeta = IERC20Metadata(_to);

        uint256 value = invert ? _priceFeed[_to] : _priceFeed[_from] ;
        uint256 amount; 

        if (invert) {
           amount = _amount.mul(Constants.PINT).div(value);
        } else {
            amount = _amount.mul(value).div(Constants.PINT);
        }

        // decimal conversion
        uint256 toDecimals = 10**toMeta.decimals();
        uint256 fromDecimals = 10**fromMeta.decimals();
        amount = amount.mul(toDecimals).div(fromDecimals);
        return amount;
    }
}