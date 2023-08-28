// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

pragma abicoder v2;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IMintable} from "../interfaces/IMintable.sol";
import {NonblockingLzApp} from "../lzApp/NonBlockingLzApp.sol";

contract Portal is NonblockingLzApp, Pausable {

    IMintable public olive;
    constructor(address _endpoint) NonblockingLzApp(_endpoint) {}

    event MintInstruction(address indexed _from, address indexed _to, uint256 _amount);
    event MintedFromInstruction(address indexed _from, address indexed _to, uint256 _srcChainId, uint256 _nounce, uint256 _amount);

    function setOlive(address _olive) external onlyOwner {
        require(_olive != address(0) && _olive != address(this), "Portal: Invalid address");
        olive = IMintable(_olive);
    }

    function enable(bool en) external {
        if (en) {
            _pause();
        } else {
            _unpause();
        }
    }

    function sendMintInstruction(
        uint16 _dstChainId, 
        address _user, 
        uint256 _amount
    ) public payable whenNotPaused {
        require(_user != address(0), "Portal: Invalid user address");
        require(_amount > 0, "Portal: Invalid amount");
        require(IERC20(address(olive)).balanceOf(address(this)) >= _amount, "Portal: Insufficient olive balance");
        require(address(this).balance > 0, "the balance of this contract is 0. pls send gas for message fees");

        // encode the payload with user and amount -- desination is always gonna be ethereum
        bytes memory payload = abi.encode(_user, _amount);
        olive.burn(_user, _amount);

        // use adapterParams v1 to specify more gas for the destination
        uint16 version = 1;
        uint gasForDestinationLzReceive = 350000;
        bytes memory adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);

        // send LayerZero message
        _lzSend( // {value: messageFee} will be paid out of this contract!
            _dstChainId, // destination chainId
            payload, // abi.encode()'ed bytes
            payable(msg.sender), // (msg.sender will be this contract) refund address (LayerZero will refund any extra gas back to caller of send()
            address(0x0), // future param, unused for this example
            adapterParams, // v1 adapterParams, specify custom destination gas qty
            msg.value
        );

        emit MintInstruction(address(this), _user, _amount);
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 nounce, /*_nonce*/
        bytes memory _payload
    ) internal override { // todo 
        // use assembly to extract the address from the bytes memory parameter
        address sendBackToAddress;
        assembly {
            sendBackToAddress := mload(add(_srcAddress, 20))
        }

        // decode message and mint the tokens
        // todo as re-entrancy is not handled by layerzero, need to handle it here with nounce. 
        (address _user,  uint256 _amount) = abi.decode(_payload, (address, uint256)); 
        olive.mint(_user, _amount); 
        emit MintedFromInstruction(address(this), _user, _srcChainId, nounce, _amount);
    }

    receive() external payable {}
}