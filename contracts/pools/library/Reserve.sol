// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Reserve {

    struct ReserveData {
        // Is there a need to store this information
        uint256 utilization;

        // supply index for scaled balance of supply tokens
        uint256 supplyIndex;

        // borrow index for scaling the debt tokens
        uint256 borrowIndex;

        // supply rate for lenders
        uint256 currentSupplyRate;

        // borrow rate for borrowers
        uint256 currentBorrowRate;

        // last updated timestamp 
        uint40 lastUpdatedTimestamp;

        // Address for aToken
        address aToken;

        // Address for debtToken
        address debtToken;    

        // Want address
        address want;

        // Interest address strategy
        address IRateAddress;
    }

    /**
     * Update the state which is the supply and borrow indices
     * 
     * @param reserve Reserve data
     * @param liqAdded  added for the cases of user depositing / repaying
     * @param liqRemoved added for 
     */
    function updateState(ReserveData storage reserve, 
        uint256 totalLiquidity,
        uint256 liqAdded,
        uint256 liqRemoved
    ) internal {
        
    }

    function updateRates(ReserveData storage reserve) internal {

    }
    
}