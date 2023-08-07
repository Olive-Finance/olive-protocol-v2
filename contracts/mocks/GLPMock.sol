// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IMintable} from "../interfaces/IMintable.sol";

interface RewardsRouter {
    function mintAndStakeGlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp) external returns (uint256); 
    function unstakeAndRedeemGlp(address _tokenOut, uint256 _glpAmount, uint256 _minOut, address _receiver) external returns (uint256);
}

interface GLPManager {
    function getPrice(bool) external view returns (uint256);   
}

contract GLPMock is GLPManager, RewardsRouter {
    IERC20 public glp;
    uint256 public priceOfGLP;
    
    function getPrice(bool) external view override returns (uint256) {
        return priceOfGLP;
    }

    function setGLPPrice(uint256 _price) external {
        priceOfGLP = _price;
    }

    function mintAndStakeGlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external override returns (uint256) {
        IERC20 token = IERC20(_token);
        token.transferFrom(msg.sender, address(this), _amount);
        IMintable(address(glp)).mint(msg.sender, (_amount*995)/1000);
    }

    function unstakeAndRedeemGlp(
        address _tokenOut,
        uint256 _glpAmount,
        uint256 _minOut,
        address _receiver
    ) external override returns (uint256) {
        IERC20 token = IERC20(_tokenOut);
        glp.transferFrom(msg.sender, address(this), _glpAmount);
        IMintable(address(glp)).burn(msg.sender, _glpAmount);
        token.transfer(msg.sender, (_glpAmount*995)/1000);
    }
}