// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {ArbSys} from "../interfaces/IArbSys.sol";

contract ArbSysMock is ArbSys {
    function arbBlockNumber() external view override returns (uint256) {
        return block.number;
    }
}