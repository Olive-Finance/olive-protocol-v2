// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IOliveV2 {
    
    // Contract payable functions

    /**
     * Deposit function to store assets in Olive.
     * @param _amount - Amount in token balance
     * @param _leverage - Leverage is an integer between 1 - X, where X is the max leverage controlled by the contract
     */
    function deposit(uint256 _amount, uint8 _leverage) external returns (bool);

    /**
     * Function to leverage asset tokens, this function assumes user has already deposited assets in Olive
     * @param _leverage - Number of shares to leverage
     * max leverage controlled by the contract
     */
    function leverage(uint256 _leverage) external returns (bool);

    /**
     * Function to deleverage the number of debt shares. 
     * This function works the same as repay but deals with debt shares
     * @param _shares - Amount of debt shares to be burned
     */
    function deleverage(uint256 _shares) external returns (bool);

    /**
     * Function to repay asset tokens 
     * @param _debtToken - debt Token on which user has taken debt
     * @param _amount - Amount of asset tokens that are to be repaid to pool
     */
    function repay(address _debtToken, uint256 _amount) external returns (bool);

    /**
     * Shares to withdraw, the withdraw is only allowed, whe HF > 1. Otherwise the transaction will be reverted.
     * @param _shares - Amount of shares (AOTokens) to withdraw
     */
    function withdraw(uint256 _shares) external returns (bool);

    /**
     * Function to close the position 
     * All assets will be transferred back to user
     * All open debt / leverage positions will be closed
     */
    function closePosition() external returns (bool);


    // View Functions
    /**
     * A view function to get the share price for given 
     * @param shareType - Type of share for which asset value is pulled
     */
    function getPricePerShare(uint256 shareType) external view returns (uint256);

    /**
     * A view function to get the list of withdrawable shares
     */
    function getTotalWithdrawableShares(address _user) external view returns (uint256);

    /**
     * Function to get current leverage position
     */
    function getCurrentLeverage(address _user) external view returns (uint256);

    /**
     * Health factor
     */
    function hf(address _user) external view returns (uint256);
}
