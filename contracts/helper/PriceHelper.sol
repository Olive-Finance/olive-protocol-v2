// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IPriceHelper} from './interfaces/IPriceHelper.sol';
import {Governable} from '../utils/Governable.sol';

import {Constants} from '../lib/Constants.sol';

interface IFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function decimals() external view returns (uint8);
}

contract PriceHelper is IPriceHelper, Governable {
    uint256 public  SEQUENCER_GRACE_PERIOD = 1 hours;

    // All ERC20 Tokens would be read from here
    mapping(address => address) public feeds;
    mapping(address => uint256) public gracePeriods;

    IFeed public sequencer;

    // Empty constructor
    constructor() Governable(msg.sender) {}

    // Setter functions
    function setSequencer(address _sequencer) public onlyGov {
        require(_sequencer != address(0) && _sequencer != address(this), "PHLP: Invalid sequencer");
        sequencer = IFeed(_sequencer);
    }

    function setSeqGracePeriod(uint256 _period) public onlyGov {
        require(_period > 0, "PHLP: Invalid grace period");
        SEQUENCER_GRACE_PERIOD = _period;
    }

    function setPriceFeed(address _token, address _feed, uint256 _gracePeriod) public onlyGov {
        require(_token != address(0) && _feed != address(0), "PHLP: Zero addresses");
        require(_token != address(this) && _feed != address(this), "PHLP: Invalid address");
        require(_gracePeriod >= 1 hours && _gracePeriod <= 24 hours, "PHLP: Invalid grace period");
        feeds[_token] = _feed;
        gracePeriods[_token] = _gracePeriod;
    }

    function isSequencerActive() public view returns (bool) {
        (, int256 answer, uint256 startedAt,,) = sequencer.latestRoundData();
        if (block.timestamp - startedAt <= SEQUENCER_GRACE_PERIOD || answer == 1)
            return false;
        return true;
    }

    function getPriceOf(address _token) external view override returns (uint256) {
        require(_token != address(0), "PHLP: Invalid token");
        require(feeds[_token] != address(0), "PHLP: Token not whitelisted");
        require(isSequencerActive(), "PHLP: Sequencer inactive");
        return _getPriceOf(feeds[_token], gracePeriods[_token]);
    }

    function _getPriceOf(address _feed, uint256 _gracePeriod) internal view returns (uint256) {
        (uint80 roundId, int256 price, 
        ,uint256 updateTime, 
        uint80 answeredInRound) = IFeed(_feed).latestRoundData();
        require(price > 0, "PHLP: Invalid chainlink price");
        require(updateTime > 0, "PHLP: Incomplete round");
        require(answeredInRound >= roundId, "PHLP: Stale price");
        require(block.timestamp - updateTime <= _gracePeriod, "PHLP: Price outdated");
        return (uint256(price) * Constants.PINT) / (10 ** IFeed(_feed).decimals());
    }
}