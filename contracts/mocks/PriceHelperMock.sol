// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IPriceHelper} from "../helper/interfaces/IPriceHelper.sol";

contract PriceHelperMock is IPriceHelper {
    mapping(address => uint256) public prices;

    function getPriceOf(address _token) external view override returns (uint256) {
        return prices[_token];
    }

    function setPriceOf(address _token, uint256 _price) external {
        prices[_token] = _price;
    }

}