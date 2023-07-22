// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

contract Governable {
    address public gov;

    event GovernanceAuthorityTransfer(address indexed newGov);

    constructor(address owner) {
        gov = owner;
    }

    modifier onlyGov() {
        isGov();
        _;
    }

    function isGov() internal view {
        require(msg.sender == gov, "Governable: forbidden");
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
        emit GovernanceAuthorityTransfer(_gov);
    }
}
