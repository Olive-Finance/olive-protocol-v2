// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IMintable} from "../interfaces/IMintable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Constants} from "../lib/Constants.sol";
import {IGLPRouter, IGLPManager, IClaimRouter} from "../strategies/GLP/interfaces/IGMXRouter.sol";

interface GLPInterface {
    function mint(address _token, address _user, uint256 _amount) external returns (uint256);
    function burn(address _token, address _user, uint256 _amount) external returns (uint256);
}

contract GLPMock is IGLPRouter, IClaimRouter {
    
    uint256 public priceOfGLP;
    address public glpMgrAddress;
    address public rewardsToken;
    uint256 public fees;

    constructor(address _glpManager) {
        glpMgrAddress = _glpManager;
    }

    function mintAndStakeGlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external override returns (uint256) {
        return GLPInterface(glpMgrAddress).mint(_token, msg.sender, _amount);
    }

    function unstakeAndRedeemGlp(
        address _tokenOut,
        uint256 _glpAmount,
        uint256 _minOut,
        address _receiver
    ) external override returns (uint256) {
        return GLPInterface(glpMgrAddress).burn(_tokenOut, msg.sender, _glpAmount);
    }

    function setRewardsToken(address _rewardsToken) external {
        rewardsToken = _rewardsToken;
    }

    function compound() external override {
        return;
    }

    function setFeesToClaim(uint256 _fees) external {
        fees = _fees;
    }

    function claimFees() external override {
        IMintable token = IMintable(rewardsToken);
        token.mint(msg.sender, fees);
    }

    function glpManager() external view override returns (address) {
        return glpMgrAddress;
    }
}

contract GLPMockManager is IGLPManager, GLPInterface {
    IERC20 public glp;
    uint256 public fee;

    uint256 public priceOfGLP = 1e30;

    constructor(address _glp) {
        glp = IERC20(_glp);
        fee = 0;
    }

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    function setPriceOfGLP(uint256 _price) external {
        priceOfGLP = _price;
    }

    function getPrice(bool) external view override returns (uint256) {
        return priceOfGLP;
    }

    function mint(address _token, address _user, uint256 _amount) external override returns (uint256) {
        IERC20 token = IERC20(_token);
        token.transferFrom(_user, address(this), _amount);
        uint256 toMint = (_amount * (Constants.HUNDRED_PERCENT - fee) * 10**IERC20Metadata(address(glp)).decimals()) 
        / (Constants.HUNDRED_PERCENT * 10**IERC20Metadata(_token).decimals());
        IMintable(address(glp)).mint(_user, toMint);
        return toMint;
    }

    function burn(address _tokenOut, address _user, uint256 _amount) external override returns (uint256) {
        IERC20 token = IERC20(_tokenOut);
        IMintable(address(glp)).burn(_user, _amount);
        uint256 toTransfer = (_amount * (Constants.HUNDRED_PERCENT - fee) * 10**IERC20Metadata(address(_tokenOut)).decimals()) 
        / (Constants.HUNDRED_PERCENT * 10**IERC20Metadata(address(glp)).decimals());
        token.transfer(_user, toTransfer);
        return toTransfer;
    }
}