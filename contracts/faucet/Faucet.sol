// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {Allowed} from '../utils/Allowed.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Faucet is Allowed {
    address public usdc;
    address public glp;
    address public gm;
    address public weth;
    address public rETH;
    address public wstETH;

    uint256 constant public USDC_TO_MINT = 1000e6;
    uint256 constant public LP_TO_MINT = 1000e18;
    uint256 constant public ETHER_TO_TRASNFER = 0.01 ether;

    uint256 constant public MIN_ETHER_BALANCE_TO_TRASNFER = 0.001 ether;
    uint256 constant public MIN_USDC_BALANCE_TO_MINT = 1e6;
    uint256 constant public MIN_LP_BALANCE_TO_MINT = 1e18;
    uint256 constant public MIN_WETH_BALANCE_TO_MINT = 1e18;
 
    // empty contractor
    constructor(address _usdc, 
        address _glp, address _gm,
        address _weth, address _rETH,
        address _wstETH
        ) Allowed(msg.sender) {
        usdc = _usdc;
        glp = _glp;
        gm = _gm;
        weth = _weth;
        rETH = _rETH;
        wstETH = _wstETH;
    }

    function setUSDC(address _usdc) external onlyOwner {
        require(_usdc != address(0), "Faucet: Invalid address");
        usdc = _usdc;
    }

    function setGLP(address _glp) external onlyOwner {
        require(_glp != address(0), "Faucet: Invalid address");
        glp = _glp;
    }

    function setGM(address _gm) external onlyOwner {
        require(_gm != address(0), "Faucet: Invalid address");
        gm = _gm;
    }

    function setWETH(address _weth) external onlyOwner {
        require(_weth != address(0), "Faucet: Invalid address");
        weth = _weth;
    }

    function setRETH(address _reth) external onlyOwner {
        require(_reth != address(0), "Faucet: Invalid address");
        rETH = _reth;
    }

    function setWSTETH(address _wstEth) external onlyOwner {
        require(_wstEth != address(0), "Faucet: Invalid address");
        wstETH = _wstEth;
    }


    function mint() external {
        address sender = msg.sender;
        uint256 etherAmount = payable(sender).balance;
        uint256 usdcAmount = IERC20(usdc).balanceOf(sender);
        uint256 glpAmount = IERC20(glp).balanceOf(sender);
        uint256 gmAmount = IERC20(gm).balanceOf(sender);
        uint256 wEthAmount = IERC20(weth).balanceOf(sender);
        uint256 rEthAmount = IERC20(rETH).balanceOf(sender);
        uint256 wstEthAmount = IERC20(weth).balanceOf(sender);

        if (etherAmount < MIN_ETHER_BALANCE_TO_TRASNFER && address(this).balance >= ETHER_TO_TRASNFER) {
            transferEther(sender);
        }

        if (usdcAmount < MIN_USDC_BALANCE_TO_MINT) {
            mintUSDC(sender);
        }

        if (glpAmount < MIN_LP_BALANCE_TO_MINT) {
            mintLP(glp, sender);
        }

        if (gmAmount < MIN_LP_BALANCE_TO_MINT) {
            mintLP(gm, sender);
        }

        if (wEthAmount < MIN_LP_BALANCE_TO_MINT) {
            mintLP(weth, sender);
        }

        if (rEthAmount < MIN_LP_BALANCE_TO_MINT) {
            mintLP(rETH, sender);
        }

        if (wstEthAmount < MIN_LP_BALANCE_TO_MINT) {
            mintLP(wstETH, sender);
        }
    }

    function mintUSDC(address _to) internal {
        require(usdc != address(0), "Faucet: USDC not set");
        IMintable(usdc).mint(_to, USDC_TO_MINT);
    }

    function mintLP(address token, address _to) internal {
        require(token != address(0), "Faucet: GLP not set");
        IMintable(token).mint(_to, LP_TO_MINT);
    }

    function transferEther(address _to) internal {
        require(address(this).balance >= ETHER_TO_TRASNFER, "Faucet: Insufficient balance");
        payable(_to).transfer(ETHER_TO_TRASNFER);
    }

    receive() external payable {}
}