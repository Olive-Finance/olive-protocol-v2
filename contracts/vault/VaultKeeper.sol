// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Allowed} from "../utils/Allowed.sol";
import {Constants} from "../lib/Constants.sol";
import {Governable} from "../utils/Governable.sol";

import {IStrategy} from "../strategies/interfaces/IStrategy.sol";
import {IVaultCore} from "./interfaces/IVaultCore.sol";
import {IVaultManager} from "./interfaces/IVaultManager.sol";
import {ILendingPool} from "../pools/interfaces/ILendingPool.sol";
import {IFees} from "../fees/interfaces/IFees.sol";
import {IVaultKeeper} from "../vault/interfaces/IVaultKeeper.sol";

contract VaultKeeper is IVaultKeeper, Allowed, Governable {
    IVaultCore public vaultCore;
    IVaultManager public vaultManager;
    uint256 public keeperRate;
    IFees public fees;

    // Allowed keepers
    mapping(address => bool) public keepers;

    // Empty constructor
    constructor() Allowed(msg.sender) Governable(msg.sender) {
        keeperRate = Constants.MAX_KEEPER_RATE;
    }

    modifier onlyKeeper() {
        require(keepers[msg.sender], "VK: Not authorised");
        _;
    }

    function setVaultCore(address _vaultCore) external {
        require(
            _vaultCore != address(0) && _vaultCore != address(this),
            "VK: Invalid core"
        );
        vaultCore = IVaultCore(_vaultCore);
    }

    function setVaultManager(address _vaultManager) external {
        require(
            _vaultManager != address(0) && _vaultManager != address(this),
            "VK: Invalid core"
        );
        vaultManager = IVaultManager(_vaultManager);
    }

    function setKeeperFee(uint256 _keeperRate) external {
        require(Constants.MAX_KEEPER_RATE > _keeperRate, "VK: Invalid keeper rate");
        keeperRate = _keeperRate;
    }

    function setKeeper(address _keeper, bool toActivate) external onlyGov {
        require(_keeper != address(0), "VK: Invalid keeper");
        keepers[msg.sender] = toActivate;
    }

    function harvest() external override {
        IStrategy strategy = IStrategy(vaultCore.getStrategy());
        strategy.harvest();
        setPricePerShare();
    }

    // Call post harvest and compound
    function setPricePerShare() internal {
        uint256 pps = Constants.PINT;
        if (vaultManager.totalSupply() != 0) {
            pps = (vaultManager.balanceOf() * Constants.PINT) / vaultManager.totalSupply();
        }
        vaultCore.setPPS(pps);
    }

    function _sellNRepay(address _user, uint256 _debt) internal returns (uint256) {
        uint256 _shares = _debt / vaultCore.getPPS();
        vaultCore.burnShares(_user, _shares);
        uint256 withdrawn = IStrategy(vaultCore.getStrategy()).withdraw(address(vaultCore), _shares);
        uint256 sold = vaultCore.sell(ILendingPool(vaultCore.getLendingPool()).wantToken(), withdrawn);
        ILendingPool(vaultCore.getLendingPool()).repay(address(vaultCore), _user, sold);
        return sold;
    }

    function liquidation(address _user) external override onlyKeeper {
        require(!vaultCore.isHealthy(_user), "VK: Position is healthy");
        // find and close the debt
        // of the remaining balance transfer 8% to caller and 2% to treasury, 90% back to treasury
        uint256 debt = vaultCore.getDebt(_user);
        uint256 position = vaultCore.getPosition(_user);

        uint256 toRepay = position > debt ? debt : position;
        _sellNRepay(_user, toRepay);
        if (position <= debt) return; //bad case

        uint256 totalFees = (position * (fees.getKeeperFee()+fees.getLiquidationFee()))/Constants.HUNDRED_PERCENT;
        vaultCore.burnShares(_user, totalFees);
        if(msg.sender == fees.getTreasury()) {
            vaultCore.mintShares(fees.getTreasury(), totalFees);
        } else {
            vaultCore.mintShares(fees.getTreasury(), (position * fees.getLiquidationFee())/Constants.HUNDRED_PERCENT);
            vaultCore.mintShares(msg.sender, (position * fees.getKeeperFee())/Constants.HUNDRED_PERCENT);
        }
    }
}