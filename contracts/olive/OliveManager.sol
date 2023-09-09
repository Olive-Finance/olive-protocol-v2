// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Allowed} from "../utils/Allowed.sol";
import {IFees} from "../fees/interfaces/IFees.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {IRewardManager} from "../interfaces/IRewardManager.sol";

import {Constants} from "../lib/Constants.sol";

contract OliveManager is IRewardManager, Allowed { 
    IMintable public esOlive;
    IMintable public olive;
    IERC20 public rewardToken;
    IFees public fees;
    
    uint public rewardPerTokenStored;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;
    mapping(address => uint) public time2fullRedemption;
    mapping(address => uint) public unstakeRate;
    mapping(address => uint) public lastWithdrawTime;
    mapping(address => uint8) public lastSlashRate;

    uint256 public maxVestingPeriod;
    uint256 public minVestingPeriod;

    uint256 public unclaimedRewards;

    // Constructor
    constructor() Allowed(msg.sender) {
        minVestingPeriod = Constants.TEN_DAYS;
        maxVestingPeriod = Constants.SIXTY_DAYS;
    }

    function setMinVestingPeriod(uint256 _minVestingPeriod) external onlyOwner {
         require(_minVestingPeriod >= Constants.ONE_DAY, "Fund: Invalid min vesting period");
         minVestingPeriod = _minVestingPeriod;
    }

    function setMaxVestingPeriod(uint256 _maxVestingPeriod) external onlyOwner {
         require(_maxVestingPeriod >= minVestingPeriod, "Fund: Invalid max vesting period");
         maxVestingPeriod = _maxVestingPeriod;
    }

    function setFees(address _fees) external onlyOwner {
        require(_fees != address(0), "Fund: Invalid address");
        fees = IFees(_fees);
    } 

    function setRewardToken(address _rewardToken) external onlyOwner {
        require(_rewardToken != address(0) && _rewardToken != address(this), "Fund: Invalid address");
        rewardToken = IERC20(_rewardToken);
    }


    function setTokens(address _olive, address _esOlive) external onlyOwner {
        require(_olive != address(0), "Fund: Invalid address");
        require(_esOlive != address(0), "Fund: Invalid address");
        olive = IMintable(_olive);
        esOlive = IMintable(_esOlive);
    }

    function totalStaked() public view returns (uint256) {
        return IERC20(address(esOlive)).totalSupply();
    }

    function stakedOf(address _staker) public view returns (uint256) {
        return IERC20(address(esOlive)).balanceOf(_staker);
    }

    function stake(uint256 _amount) whenNotPaused external updateReward(msg.sender) {
        address caller = msg.sender;
        olive.burn(caller, _amount);
        esOlive.mint(caller, _amount);
    }

    function unstake(uint256 _amount, uint8 _timeInDays) whenNotPaused external updateReward(msg.sender) {  
        address caller = msg.sender;
        require(_timeInDays >= minVestingPeriod/Constants.ONE_DAY && _timeInDays <= maxVestingPeriod/Constants.ONE_DAY, "Fund: Invalid vesting days");

        esOlive.burn(caller, _amount);
        _withdraw(caller);
        uint256 total = _amount;
        if (time2fullRedemption[caller] > block.timestamp) {
            uint256 scaled = ((unstakeRate[caller] * 100 ) * (time2fullRedemption[caller] - block.timestamp)) / (100 - lastSlashRate[caller]);
            scaled /= Constants.PINT;
            total += scaled ;
        }
        uint8 nonSlashRate = getNonSlashRate(_timeInDays);
        total = (total  * nonSlashRate)/100;
        uint256 timeToVest = _timeInDays * Constants.ONE_DAY;
        lastSlashRate[caller] = 100 - nonSlashRate;
        unstakeRate[caller] = (total * Constants.PINT) / timeToVest;
        time2fullRedemption[caller] = block.timestamp + timeToVest;
    }

    function getNonSlashRate(uint8 timeInDays) internal view returns (uint8) {
        uint256 minDays = minVestingPeriod / Constants.ONE_DAY;
        uint256 slope = (Constants.FIFTY_DAYS * Constants.PINT * Constants.ONE_DAY ) / (maxVestingPeriod - minVestingPeriod); // Constants
        uint256 result = Constants.FIFTY_DAYS + ((timeInDays - minDays) * slope) / Constants.PINT;
        return uint8(result) ;
    }

    function withdraw() whenNotPaused public {
        _withdraw(msg.sender);
    }

    function _withdraw(address _user) internal { 
        uint256 amount = getClaimable(_user);
        if (amount > 0) {
            olive.mint(_user, amount);
        }
        lastWithdrawTime[_user] = block.timestamp;
    }

    function reStake() external whenNotPaused updateReward(msg.sender) {
        address caller = msg.sender;
        uint256 toMint = getReservedForVesting(caller) + getClaimable(caller);
        toMint = (toMint * 100 * Constants.PINT) / (100 - lastSlashRate[caller]);
        toMint /= Constants.PINT;
        if (toMint > 0) {
            esOlive.mint(caller, toMint);
            unstakeRate[caller] = 0;
            time2fullRedemption[caller] = 0;
            lastSlashRate[caller] = 0;
        }
    }

    function getClaimable(address _user) public view returns (uint256 amount) {
        if (time2fullRedemption[_user] > lastWithdrawTime[_user]) {
            amount = block.timestamp > time2fullRedemption[_user]
                ? unstakeRate[_user] *
                    (time2fullRedemption[_user] - lastWithdrawTime[_user])
                : unstakeRate[_user] *
                    (block.timestamp - lastWithdrawTime[_user]);
            amount /= Constants.PINT;
        }
    }

    function getReservedForVesting(address _user) public view returns (uint256 amount) {
        if (time2fullRedemption[_user] > block.timestamp) {
            amount =
                unstakeRate[_user] *
                (time2fullRedemption[_user] - block.timestamp);
            amount /= Constants.PINT;
        }
    }

    function earned(address _account) public view returns (uint) {
        return
            ((stakedOf(_account) *
                (rewardPerTokenStored - userRewardPerTokenPaid[_account])) /
                Constants.PINT) + rewards[_account];
    }


    modifier updateReward(address account) {
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    // Function to refresh the rewards, not other actions to be performed
    function refreshReward(address _account) external updateReward(_account) {}

    function getReward() external updateReward(msg.sender) {
        address caller = msg.sender;
        uint reward = rewards[caller];
        if (reward > 0) {
            rewards[caller] = 0;
            rewardToken.transfer(caller, reward);
        }
    }

    function notifyRewardAmount(uint amount) external onlyAllowed {
        if (totalStaked() == 0) {
            /**
             * These rewards are unclaimable by the users
             * these tokens are forever locked in the contract
             * Happens if esOlive balance is zero 
             *  a) When dApp - launched before IDO 
             *  b) When circulation of esOlive is zero (rare-event)
             */
            unclaimedRewards += amount;
            return; 
        }
        require(amount > 0, "amount = 0");
        rewardPerTokenStored = rewardPerTokenStored + (amount * Constants.PINT) / totalStaked();
    }

    function withdrawToTreasury() external onlyOwner {
        require(unclaimedRewards > 0, "Fund: No unclaimed rewards");
        rewardToken.transfer(fees.getTreasury(), unclaimedRewards);
        unclaimedRewards = 0;
    } 
}
