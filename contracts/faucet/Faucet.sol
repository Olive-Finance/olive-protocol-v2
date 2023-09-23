// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {Allowed} from '../utils/Allowed.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Faucet is Allowed {
    address public usdc;
    address public glp;

    uint256 constant public USDC_TO_MINT = 1000e6;
    uint256 constant public GLP_TO_MINT = 1000e18;
    uint256 constant public ETHER_TO_TRASNFER = 0.01 ether;

    uint256 constant public MIN_ETHER_BALANCE_TO_TRASNFER = 0.001 ether;
    uint256 constant public MIN_USDC_BALANCE_TO_MINT = 1e6;
    uint256 constant public MIN_GLP_BALANCE_TO_MINT = 1e18;
 
    // empty contractor
    constructor(address _usdc, address _glp) Allowed(msg.sender) {
        usdc = _usdc;
        glp = _glp;
    }

    function setUSDC(address _usdc) external onlyOwner {
        require(_usdc != address(0), "Faucet: Invalid address");
        usdc = _usdc;
    }

    function setGLP(address _glp) external onlyOwner {
        require(_glp != address(0), "Faucet: Invalid address");
        glp = _glp;
    }

    function mint() external {
        address sender = msg.sender;
        uint256 etherAmount = payable(sender).balance;
        uint256 usdcAmount = IERC20(usdc).balanceOf(sender);
        uint256 glpAmount = IERC20(glp).balanceOf(sender);

        if (etherAmount < MIN_ETHER_BALANCE_TO_TRASNFER && address(this).balance >= ETHER_TO_TRASNFER) {
            transferEther(sender);
        }

        if (usdcAmount < MIN_USDC_BALANCE_TO_MINT) {
            mintUSDC(sender);
        }

        if (glpAmount < MIN_GLP_BALANCE_TO_MINT) {
            mintGLP(sender);
        }
    }

    function mintUSDC(address _to) internal {
        require(usdc != address(0), "Faucet: USDC not set");
        IMintable(usdc).mint(_to, USDC_TO_MINT);
    }

    function mintGLP(address _to) internal {
        require(glp != address(0), "Faucet: GLP not set");
        IMintable(glp).mint(_to, GLP_TO_MINT);
    }

    function transferEther(address _to) internal {
        require(address(this).balance >= ETHER_TO_TRASNFER, "Faucet: Insufficient balance");
        payable(_to).transfer(ETHER_TO_TRASNFER);
    }

    receive() external payable {}
}