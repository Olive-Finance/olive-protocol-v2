// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;


interface IRewards{
    // Functions
    function notifyReward(address _token, uint256 _amount) external;
    function convertTo(address _from, address _to) external returns (uint256);
    function exchangeTo(address _token, uint256 _rShares) external ;
    function exchange(uint256 _rShares) external;
    
    // View function
    function getPrice() external view returns (uint256);
    
    // Events
    event Reward(address indexed _notifiedBy, address indexed _token, uint256 _amount);
    event Converted(address indexed _from, address indexed _to, uint256 _amount);
    event Exchanged(address indexed _exchangedBy, address indexed _token, uint256 _amount);
}