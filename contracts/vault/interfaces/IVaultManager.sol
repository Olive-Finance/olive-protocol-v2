// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IVaultManager {
    
    // Contract payable functions

    /**
     * Deposit function to store assets in Olive.
     * @param _amount - Amount in token balance
     * @param _leverage - Leverage is an integer between 1 - X, where X is the max leverage controlled by the contract
     */
    function deposit(uint256 _amount, uint256 _leverage, uint256 _expectedShares, uint256 _slippage) external returns (bool);

    /**
     * Function to leverage asset tokens, this function assumes user has already deposited assets in Olive
     * @param _leverage - Number of shares to leverage
     * max leverage controlled by the contract
     */
    function leverage(uint256 _leverage, uint256 _expectedShares, uint256 _slippage) external returns (bool);

    /**
     * Function to deleverage the number of debt shares. 
     * This function works the same as repay but deals with debt shares
     * @param _toLeverage - Number of shares to leverage
     */
    function deleverage(uint256 _toLeverage, uint256 _repayAmount, uint256 _slippage) external returns (bool);

    /**
     * Shares to withdraw, the withdraw is only allowed, whe HF > 1. Otherwise the transaction will be reverted.
     * @param _shares - Amount of shares (AOTokens) to withdraw
     */
    function withdraw(uint256 _shares, uint256 _expTokens, uint256 slip) external returns (bool);

    /**
     * A view function to get the list of withdrawable shares
     */
    function getBurnableShares(address _user) external view returns (uint256);

    /**
     * Function to get current leverage position
     */
    function getLeverage(address _user) external view returns (uint256);

    /**
     * Function to get the balance of the assets deployed to strategy by vault
     */
    function balance() external view returns (uint256);

    /**
     * Function to get the total supply of lendger token
     */
    function totalSupply() external view returns (uint256);

    /** Events */
    event Deposit(address indexed _vault, address indexed _user, uint256 _amount);
    event Withdraw(address indexed _vault, address indexed _user, uint256 _amount);
    event Leverage(address indexed _vault, address indexed _user, uint256 fromLeverage, uint256 toLeverage);
    event Mint(address indexed _vault, address indexed _user, uint256 _shares, uint256 _assetAmount);
    event Burn(address indexed _vault, address indexed _user, uint256 _shares, uint256 _assetAmount);
}
