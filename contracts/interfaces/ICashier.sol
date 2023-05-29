// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ICashier {

    /**
     * Function to deleverage the number of debt shares. 
     * This function works the same as repay but deals with debt shares
     * @param _toLeverage - Number of shares to leverage
     */
    function deleverage(uint8 _toLeverage) external returns (bool);

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
    
}