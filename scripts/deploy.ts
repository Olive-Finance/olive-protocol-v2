import { ethers } from "hardhat";

async function main() {

  //ASSET - GLP
  const GLP = await ethers.getContractFactory("Token");
  const glp = await GLP.deploy('USDC Token', 'USDC');
  await glp.deployed();
  console.log("GLP: ", glp.address);

  // Following are the asset tokens which each of the pools use
  // USDC
  const USDC = await ethers.getContractFactory("Token");
  const usdc = await USDC.deploy('USDC Token', 'USDC');
  await usdc.deployed();
  console.log("USDC: ", usdc.address);

  // Debt Ledger tokens
  //Debt Token for USDC
  const DOUSDC = await ethers.getContractFactory("DToken");
  const doUSDC = await DOUSDC.deploy('DOUSDC Token', 'doUSDC');
  await doUSDC.deployed();
  console.log("doUSDC: ", doUSDC.address);


  // Fund Ledger tokens
  //Fund Token for USDC
  const AUSDC = await ethers.getContractFactory("AToken");
  const aUSDC = await AUSDC.deploy('AUSDC Token', 'aUSDC');
  await aUSDC.deployed();
  console.log("aUSDC: ", aUSDC.address);

  
  // Lending pool definitions
  // USDC Lending pool
  const LPUSDC = await ethers.getContractFactory("Pool");
  const pool = await LPUSDC.deploy(
    usdc.address,
    aUSDC.address,
    doUSDC.address
     );
  await pool.deployed();
  console.log("lpUSDC: ", pool.address);


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

  }

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
