pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract Receiver {
    event Received(address indexed sender, uint256 amount);

    uint256 public bal;
    address payable public _treasury;

    constructor(address treasury) {
        _treasury = convertToPayable(treasury);
    }   

    function defcon(uint256 value) public returns (bool) {
        bal += value;
        return true;
    }

    function convertToPayable(address recipient) internal pure returns (address payable) {
        return payable(recipient); 
    }

    function transferEther(address payable recipient) public payable returns(bool) {
        uint256 amount = msg.value;
        recipient.transfer(amount);
        return true;
    }

    function sendEther(address payable recipient) external payable returns(bool) {
        console.log("Sender: ", msg.sender);
        console.log("Value: ", msg.value);
        uint256 amount = msg.value;
        recipient.send(amount);
        console.log("Ether balance: ", recipient.balance);
        return true;
    }

    function sendEth(address payable recipient, uint256 amount) public returns (bool) {
        this.sendEther{value: amount}(recipient); // this should send the money from the contract - Yes it did!
        return true;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
        defcon(msg.value);
        sendEth(_treasury, msg.value);
        console.log('In receive function: ', msg.sender);
    }

    fallback() external payable {
        emit Received(msg.sender, msg.value);
        defcon(msg.value);
        sendEth(_treasury, msg.value);
        console.log('In fallback function: ', msg.sender);
    }
}
