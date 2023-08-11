// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {Constants} from "../lib/Constants.sol";

import {IFees} from "../fees/interfaces/IFees.sol";
import {IGMXRouter}  from "./GLP/interfaces/IGMXRouter.sol";
import {IRewards} from "../rewards/interfaces/IRewards.sol";
import {Allowed} from "../utils/Allowed.sol";

contract Strategy is IStrategy, Allowed {
    //List of addresses
    IERC20 public asset;
    IERC20 public rToken;
    IERC20 public sToken;
    IGMXRouter public _gmxRouter;
    uint256 public lastHarvest;
    uint256 public pps;

    address public keeper;
    uint256 public assetBalance;
    IFees public fees;
    IRewards public rewards; // Todo have this discuss with Shailesh

    mapping (address => mapping(address => bool)) handler;

    event Harvest(address indexed asset, address indexed strategy, uint256 amount);

    constructor(address _asset, address _sToken) Allowed(msg.sender) {
        asset = IERC20(_asset);
        sToken = IERC20(_sToken);
        pps = Constants.PINT;
    }

    modifier onlyKeeper {
        require(msg.sender == keeper, "STR: Insufficient previlages");
        _;  
    }

    modifier onlyHandler (address _user) {
        if (_user != msg.sender) {
            require(handler[_user][msg.sender], "STR: Invalid handler");
        }
        _;
    }

    function setFees(address _fees) public onlyOwner {
        require(_fees != address(0), "STR: Invalid fees address");
        fees = IFees(_fees);
    }

    function setRewards(address _rewards) public onlyOwner {
        require(_rewards != address(0), "STR: Invalid rewards address");
        rewards = IRewards(_rewards);
    }

    function setKeeper(address _keeper) public onlyOwner {
        require(_keeper != address(0), "STR: Invalid keeper");
        keeper = _keeper;
    }

    function setRewardsToken(address _rewardsToken) public onlyOwner {
        require(_rewardsToken != address(0), "STR: Invalid rewards address");
        rToken = IERC20(_rewardsToken);
    }

    function setGMXRouter(address gmxRouter) public onlyOwner {
        require(gmxRouter != address(0) || gmxRouter != address(this), "STR: Invalid address");
        _gmxRouter = IGMXRouter(gmxRouter);
    }

    function deposit(address _user, uint256 _amount) external override whenNotPaused nonReentrant onlyHandler(_user)  {
        require(_amount > 0, "STR: Zero/Negative amount");
        require(asset.balanceOf(address(this)) - assetBalance >= _amount, "STR: No token transfer");
        assetBalance += _amount;
        IMintable soToken = IMintable(address(sToken));
        soToken.mint(_user, getShares(_amount));
    }

    function getShares(uint256 _amount) internal view returns (uint256) {
        return (_amount * Constants.PINT)/pps;
    }

    function getAmount(uint256 _shares) internal view returns (uint256) {
        return (_shares * pps)/Constants.PINT;
    }

    function withdraw(address _user, uint256 _shares) external override whenNotPaused nonReentrant onlyHandler(_user) returns (uint256) {
        require(_shares > 0, "STR: Zero/Negative amount");
        require(sToken.balanceOf(_user) >= _shares, "STR: Insufficient balance");
        IMintable(address(sToken)).burn(_user, _shares);
        uint amount = getAmount(_shares);
        assetBalance -= amount;
        asset.transfer(_user, amount);
        return amount;
    }

    function harvest() external override whenNotPaused onlyKeeper {
        _gmxRouter.compound();  // Claim and restake esGMX and multiplier points
        _gmxRouter.claimFees();
        uint256 nativeBal = rToken.balanceOf(address(this));
        if (nativeBal > 0) {
            uint256 pFees = (nativeBal * (Constants.HUNDRED_PERCENT - fees.getPFee()))/ Constants.PINT;
            chargeFees(pFees); 
            uint256 before = this.balance();
            mintGlp();
            emit Harvest(address(asset), address(this), this.balance() - before);
            lastHarvest = block.timestamp;
        }
    }

    function chargeFees(uint256 _amount) internal {
        rToken.transfer(fees.getTreasury(), _amount);
    }

    function setPPS() internal {
        pps = (asset.balanceOf(address(this)) * Constants.PINT)/sToken.totalSupply();
    }

    // mint more GLP with the ETH earned as fees
    function mintGlp() internal {
        uint256 nativeBal = rToken.balanceOf(address(this));
        _gmxRouter.mintAndStakeGlp(address(rToken), nativeBal, 0, 0);
    }

    function balance() external view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function balanceOf(address _user) external view override returns (uint256) {
        return getAmount(sToken.balanceOf(_user));
    }

    function setHandler(address _user, address _handler, bool _enabled) external onlyOwner {
        require(_user != address(0) && _handler != address(0), "STR: Invalid addresses");
        handler[_user][_handler] = _enabled;
        emit HandlerChanged(_user, _handler, _enabled);
    } 
}