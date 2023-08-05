// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IMintable} from '../interfaces/IMintable.sol';
import {IStrategy} from '../strategies/interfaces/IStrategy.sol';

import {Allowed} from '../utils/Allowed.sol';
import {Constants} from '../lib/Constants.sol';

contract VaultCore is Allowed {
    //Token addresses
    IERC20 public asset; 
    IERC20 public oToken;
    IERC20 public sToken;

    //Address for strategy
    IStrategy public strategy;

    //Olive treasury address
    address public treasury;

    // Pool for borrowing
    address public lendingPool;    
  
    // Struct to store the txn block number
    mapping(address => uint256) public userTxnBlockStore;

    // Allowed address for same block transactions
    mapping(address => bool) public allowedTxtor;

    //Price per share
    uint256 public pps = Constants.PINT; 

    // Contract for doing vault actions - deposit, withdraw, leverage, deleverage
    address public vaultManager;

    // Contract for doing vault liquidation & super liquidation
    address public vaultKeeper;

    // Vault parameters
    uint256 public MAX_LEVERAGE;
    uint256 public MIN_LEVERAGE;
    uint256 public SLIPPAGE_TOLERANCE;
    uint256 public LIQUIDATION_THRESHOLD;

    uint256 public HF_THRESHOLD = Constants.PINT;

    // Empty constructor - all the values will be set by setter functions
    constructor () Allowed(msg.sender){}

    // Vault setter functions
    function setVaultManager(address _vaultManager) external onlyOwner {
        require(_vaultManager != address(0), "OLV: Invalid vault manager");
        vaultManager = _vaultManager;
    }

    function setVaultKeeper(address _vaultKeeper) external onlyOwner {
        require(_vaultKeeper != address(0), "OLV: Invalid vault keeper");
        vaultKeeper = _vaultKeeper;
    }

    function setLendingPool(address _lendingPool) external onlyOwner {
        require(_lendingPool != address(0), "OLV: Invalid lending pool");
        lendingPool = _lendingPool;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0) && _treasury != address(this), "OLV: Invalid treasury address");
        treasury = _treasury;
    }

    function setTokens(address _asset, address _oToken, address _sToken) external onlyOwner {
        require (_asset != address(0) && _oToken != address(0) && _sToken != address(0), "OLV: Invalid tokens");
        asset = IERC20(_asset);
        oToken = IERC20(_oToken);
        sToken = IERC20(_sToken);
    }


    // Vault view functions

    
}