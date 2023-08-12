// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IClaimRouter {
    function compound() external;

    function claimFees() external;
}

interface IGLPRouter {
     function mintAndStakeGlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp
    ) external returns (uint256);

    function unstakeAndRedeemGlp(address _tokenOut, uint256 _glpAmount, uint256 _minOut, address _receiver
    ) external returns (uint256);

    function glpManager() external view returns (address);
}

interface IGLPManager {
    function getPrice(bool) external view returns (uint256);   
}