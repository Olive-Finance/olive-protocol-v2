// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;


interface ILimit {
    function setLimit(address _to, uint256 _limit) external;
    function setBlackList(address _to, bool _isBlackListed) external;

    function consumeLimit(address _to, uint256 _amount) external;
    function enhaceLimit(address _to, uint256 _amount) external;

    function getLimit(address _to) external view returns (uint256);
    function isBlackList(address _to) external view returns (bool);
    
    event SetLimit(address indexed _caller, address indexed _to, uint256 _limit);
    event SetBlackList(address indexed _caller, address indexed _to, bool _isBlackListed);
}