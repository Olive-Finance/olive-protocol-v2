// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IPriceHelper} from "../helper/interfaces/IPriceHelper.sol";

contract PriceHelperMock is IPriceHelper {
    function getPriceOf(
        address _token
    ) external view override returns (uint256) {
        return 1e18;
    }

    function getPriceOfRewardToken() external view override returns (uint256) {
        return 1e18;
    }
}