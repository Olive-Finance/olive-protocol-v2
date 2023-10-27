// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMintable} from "../contracts/interfaces/IMintable.sol";
import {Allowed} from "../contracts/utils/Allowed.sol";

contract Caller {
    // caller address 0xE040082C09841A3E06F76e5c6154f27462855AFE
    uint256 public x;

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

contract Callee is Allowed {

    // calle address 0xE040082C09841A3E06F76e5c6154f27462855AFE
    // where the clr is added : 0x8c815619E205dCDA3DC50c8fdd7EA0Ed25a7A8FA
    uint256 public x;
    address public clr;
    IMintable public usdc;

    constructor() Allowed(msg.sender) {}

    function setX(uint256 _x) public {
        x = _x;
    }

    function setUSDC(address _usdc) public onlyOwner {
        usdc = IMintable(_usdc);
    }

    function sum(uint256 _x, uint256 _y) public pure returns (uint256) {
        return _x + _y;
    }

    function caller() public view returns (address) {
        return msg.sender;
    }

    function updateValue(uint256 _x) public returns (address) {
        x = _x;
        clr = msg.sender;
        return msg.sender;
    }

    function mint(uint256 value) public returns (address) {
        usdc.mint(msg.sender, value);
        return msg.sender;
    }
}