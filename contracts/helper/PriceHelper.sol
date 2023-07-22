// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IPriceHelper} from './interfaces/IPriceHelper.sol';
import {IRewards} from '../rewards/interfaces/IRewards.sol';
import {Governable} from '../utils/Governable.sol';

import {Constants} from '../lib/Constants.sol';

interface IFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

contract PriceHelper is IPriceHelper, Governable {
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    //todo to check if this is valid for all feeds otherwise abstract this
    uint256 public constant PRICE_FEED_PRECISION = 10 ** 8; // Price feed precision 

    // All ERC20 Tokens would be read from here
    mapping(address => address) public feeds;
    IFeed public sequencer;
    address public oRewards;

    // Empty constructor
    constructor() Governable(msg.sender) {}

    // Setter functions
    function setSequencer(address _sequencer) public onlyGov {
        require(_sequencer != address(0) && _sequencer != address(this), "PHLP: Invalid sequencer");
        sequencer = IFeed(_sequencer);
    }

    function setPriceFeed(address _token, address _feed) public onlyGov {
        require(_token != address(0) && _feed != address(0), "PHLP: Zero addresses");
        require(_token != address(this) && _token != address(this), "PHLP: Invalid address");
        feeds[_token] = _feed;
    }

    function isSequencerActive() public view returns (bool) {
        (, int256 answer, uint256 startedAt,,) = sequencer.latestRoundData();
        if (block.timestamp - startedAt <= GRACE_PERIOD_TIME || answer == 1)
            return false;
        return true;
    }

    function getPriceOf(address _token) external view override returns (uint256) {
        require(_token != address(0), "PHLP: Token not whitelisted");
        require(feeds[_token] != address(0), "PHLP: Token not whitelisted");
        require(isSequencerActive(), "PHLP: Sequencer inactive");
        return _getPriceOf(feeds[_token]);
    }

    function _getPriceOf(address _feed) internal view returns (uint256) {
        (uint80 roundId, int256 price, 
        ,uint256 updateTime, 
        uint80 answeredInRound) = IFeed(_feed).latestRoundData();
        require(price > 0, "PHLP: Invalid chainlink price");
        require(updateTime > 0, "PHLP: Incomplete round");
        require(answeredInRound >= roundId, "PHLP: Stale price");
        return (uint256(price) * Constants.PINT) / PRICE_FEED_PRECISION;
    }

    function getPriceOfRewardToken() external view override returns (uint256) {
        return IRewards(oRewards).getPrice();
    }
}