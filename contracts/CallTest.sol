// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;


contract Caller {

    function call(address target, bytes memory data) public returns (bytes memory) {
        (bool success, bytes memory result) = target.call(data);
        require(success, "Call failed");
        return result;
    }


    function callWithEther(address target, bytes memory data) public payable returns (bytes memory) {
        (bool success, bytes memory result) = target.call{value: msg.value}(data);
        require(success, "Call failed");
        return result;
    }

    function delegateCall(address target, bytes memory data) public returns (bytes memory) {
        (bool success, bytes memory result) = target.delegatecall(data);
        require(success, "Call failed");
        return result;
    }

    function staticCall(address target, bytes memory data) public view returns (bytes memory) {
        (bool success, bytes memory result) = target.staticcall(data);
        require(success, "Call failed");
        return result;
    }
}

contract Callee {
    uint256 public x;

    function setX(uint256 _x) public {
        x = _x;
    }

    function sum(uint256 _x, uint256 _y) public pure returns (uint256) {
        return _x + _y;
    }
}