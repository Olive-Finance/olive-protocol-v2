import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-web3";
const fs = require("fs");

task('accounts', "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  console.log("An universal lover");
  for (const account of accounts) {
    console.log(account.address);
  }
});

task ('dc', 'Deploying custome contracts', async(taskArgs, hre)=>{
  //ASSET - GLP
  const Receive = await hre.ethers.getContractFactory("Receiver");
  const rec = await Receive.deploy('0x3528942Bf01874cB51A79ac32E3FC839Ae2a1367');
  await rec.deployed();
  console.log("Receiver: ", rec.address);
});

task('w3', "Executes native code", async (taskArgs, Web3) => {
  const accounts = await Web3.web3.eth.getAccounts();
  const w3 = Web3.web3.eth;
  const blockNumber = await w3.getBlockNumber();
  console.log("Block numer: ", blockNumber);

  const contractAddr = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

  const response = await w3.sendTransaction({
    from: '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199',
    to: contractAddr,
    value: Web3.web3.utils.toWei('10', 'ether')
    
  })
  .on('transactionHash', function(hash){
    console.log('Transaction hash:', hash);
  })
  .on('receipt', function(receipt){
    console.log('Receipt:', receipt);
  })
  .on('error', function(error){
    console.error('Error:', error);
  });

  console.log("response: ", response);

  let balance = await w3.getBalance('0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199');
  console.log(balance);

});

task("deploy", "Deploys contract, get wallets, and outputs files", async (taskArgs, hre) => {
  //ASSET - GLP
  const GLP = await hre.ethers.getContractFactory("Token");
  const glp = await GLP.deploy('USDC Token', 'USDC', 8);
  await glp.deployed();
  console.log("GLP: ", glp.address);


  // Following are the asset tokens which each of the pools use
  // USDC
  const USDC = await hre.ethers.getContractFactory("Token");
  const usdc = await USDC.deploy('USDC Token', 'USDC', 8);
  await usdc.deployed();
  console.log("USDC: ", usdc.address);

  // Debt Ledger tokens
  //Debt Token for USDC
  const DOUSDC = await hre.ethers.getContractFactory("Token");
  const doUSDC = await DOUSDC.deploy('DOUSDC Token', 'doUSDC.', 8);
  await doUSDC.deployed();
  console.log("doUSDC: ", doUSDC.address);

  // Fund Ledger tokens
  //Fund Token for USDC
  const AUSDC = await hre.ethers.getContractFactory("Token");
  const aUSDC = await AUSDC.deploy('AUSDC Token', 'aUSDC.', 8);
  await aUSDC.deployed();
  console.log("aUSDC: ", aUSDC.address);

  
  // Olive tokens for tokonomics 

  //Strategy receipt token stored at Olive
  const SOToken = await hre.ethers.getContractFactory("Token");
  const soToken = await SOToken.deploy('SO Token', 'soGLP', 8);
  await soToken.deployed();
  console.log("SOToken: ", soToken.address);

  // User Olive receipt token - stored at valut as collateral
  const OToken = await hre.ethers.getContractFactory("Token");
  const oToken = await OToken.deploy('O Token', 'oGLP', 8);
  await oToken.deployed();
  console.log("oToken: ", oToken.address);

  // Rate Calculator 
  const RCL = await hre.ethers.getContractFactory("RateCalculator");
  const rcl = await RCL.deploy(0.03e12, 0.03e12, 0.03e12, 0.8e12);
  await rcl.deployed();
  console.log("rcl: ", rcl.address);
    
  // Lending pool definitions
  // USDC Lending pool
  const LPUSDC = await hre.ethers.getContractFactory("Pool");
  const lpUSDC = await LPUSDC.deploy(
    aUSDC.address,
    doUSDC.address,
    usdc.address,
    rcl.address
     );
  await lpUSDC.deployed();
  console.log("lpUSDC: ", lpUSDC.address);

  // Strategy initialization
  const Strategy = await hre.ethers.getContractFactory("Strategy");
  const strategy = await Strategy.deploy(
    glp.address,
    soToken.address,
    '0x3528942Bf01874cB51A79ac32E3FC839Ae2a1367',
  );
  await strategy.deployed();
  console.log("strategy: ", strategy.address);

  // GLP Manager
  const GLPManager = await hre.ethers.getContractFactory("GLPManager");
  const glpManager = await GLPManager.deploy(glp.address)
  await glpManager.deployed();
  console.log("glpManager: ", glpManager.address);

  // Olive initialization
  const Olive = await hre.ethers.getContractFactory("OliveV2");
  const olive = await Olive.deploy(
    glp.address,
    oToken.address,
    strategy.address,
    glpManager.address,
    lpUSDC.address,
    1e2,
    5e2
  );
  await olive.deployed();
  console.log("olive: ", olive.address);

 

  // Get generated signer wallets
  const accounts = await hre.ethers.getSigners();

  // Get the first wallet address
  const walletAddress = accounts[0].address;

  // Write file
  fs.writeFileSync('./.wallet', walletAddress);
});

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    hardhat: {
      chainId: 1337
    },
  }
};

export default config;
