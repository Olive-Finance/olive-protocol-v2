import { ethers } from "hardhat";

async function main() {

  //ASSET - GLP
  const GLP = await ethers.getContractFactory("Token");
  const glp = await GLP.deploy('USDC Token', 'USDC', 8);
  await glp.deployed();
  console.log("GLP: ", glp.address);


  // Following are the asset tokens which each of the pools use
  // USDC
  const USDC = await ethers.getContractFactory("Token");
  const usdc = await USDC.deploy('USDC Token', 'USDC', 8);
  await usdc.deployed();
  console.log("USDC: ", usdc.address);

  // DAI
  const DAI = await ethers.getContractFactory("Token");
  const dai = await DAI.deploy('DAI Token', 'DAI', 8);
  await dai.deployed();
  console.log("DAI: ", dai.address);

  // USDT
  const USDT = await ethers.getContractFactory("Token");
  const usdt = await DAI.deploy('USDT Token', 'DAI', 8);
  await usdt.deployed();
  console.log("USDT: ", usdt.address);


  // Debt Ledger tokens
  //Debt Token for USDC
  const DOUSDC = await ethers.getContractFactory("Token");
  const doUSDC = await DOUSDC.deploy('DOUSDC Token', 'doUSDC.', 8);
  await doUSDC.deployed();
  console.log("doUSDC: ", doUSDC.address);

  //Debt Token for DAI
  const DODAI = await ethers.getContractFactory("Token");
  const doDAI = await DODAI.deploy('DODAI Token', 'doDAI', 8);
  await doDAI.deployed();
  console.log("doDai: ", doDAI.address);

  //Debt Token for USDT
  const DOUSDT = await ethers.getContractFactory("Token");
  const doUSDT = await DODAI.deploy('DOUSDT Token', 'doUSDT', 8);
  await doUSDT.deployed();
  console.log("doUSDT: ", doUSDT.address);

  // Fund Ledger tokens
  //Fund Token for USDC
  const AUSDC = await ethers.getContractFactory("Token");
  const aUSDC = await AUSDC.deploy('AUSDC Token', 'aUSDC.', 8);
  await aUSDC.deployed();
  console.log("aUSDC: ", aUSDC.address);

  //Fund Token for DAI
  const ADAI = await ethers.getContractFactory("Token");
  const aDAI = await ADAI.deploy('ADAI Token', 'aDAI.', 8);
  await aDAI.deployed();
  console.log("aDAI: ", aDAI.address);

  //Fund Token for USDT
  const AUSDT = await ethers.getContractFactory("Token");
  const aUSDT = await AUSDT.deploy('AUSDT Token', 'aUSDT.', 8);
  await aUSDT.deployed();
  console.log("aUSDT: ", aUSDT.address);
  
  // Olive tokens for tokonomics 

  //Strategy receipt token stored at Olive
  const SOToken = await ethers.getContractFactory("Token");
  const soToken = await SOToken.deploy('SO Token', 'soGLP', 8);
  await soToken.deployed();
  console.log("SOToken: ", soToken.address);

  // User Olive receipt token - stored at valut as collateral
  const OToken = await ethers.getContractFactory("Token");
  const oToken = await OToken.deploy('O Token', 'oGLP', 8);
  await oToken.deployed();
  console.log("oToken: ", oToken.address);

  // Collateral Receipt token - User holds the collateral token, while pool holds corresponding oTokens
  const COToken = await ethers.getContractFactory("Token");
  const coToken = await OToken.deploy('CO Token', 'coGLP', 8);
  await coToken.deployed();
  console.log("coToken: ", coToken.address);


  // Lending pool definitions
  // USDC Lending pool
  const LPUSDC = await ethers.getContractFactory("Pool");
  const lpUSDC = await LPUSDC.deploy(
    usdc.address,
    aUSDC.address,
    doUSDC.address
     );
  await lpUSDC.deployed();
  console.log("lpUSDC: ", lpUSDC.address);

  // DAI Lending pool
  const LPDAI = await ethers.getContractFactory("Pool");
  const lpDAI = await LPDAI.deploy(
    dai.address,
    aDAI.address,
    doDAI.address
     );
  await lpUSDC.deployed();
  console.log("lpDAI: ", lpDAI.address);

   // USDT Lending pool
  const LPUSDT = await ethers.getContractFactory("Pool");
  const lpUSDT = await LPUSDT.deploy(
    usdt.address,
    aUSDT.address,
    doUSDT.address
     );
  await lpUSDC.deployed();
  console.log("lpUSDT: ", lpUSDT.address);

  // Strategy initialization
  const Strategy = await ethers.getContractFactory("Strategy");
  const strategy = await Strategy.deploy(
    glp.address,
    soToken.address,
    '0x3528942Bf01874cB51A79ac32E3FC839Ae2a1367',
  );
  await strategy.deployed();
  console.log("strategy: ", strategy.address);

  // GLP Manager
  const GLPManager = await ethers.getContractFactory("GLPManager");
  const glpManager = await GLPManager.deploy(glp.address)
  await glpManager.deployed();
  console.log("glpManager: ", glpManager.address);

  // Olive initialization
  const Olive = await ethers.getContractFactory("OliveV2");
  const olive = await Olive.deploy(
    glp.address,
    oToken.address,
    strategy.address,
    glpManager.address
  );
  await olive.deployed()
  console.log("olive: ", olive.address);

  // Setup the lending pools in Olive
  await olive.setLendingPool(lpUSDC.address);
  await olive.setLendingPool(lpDAI.address);
  await olive.setLendingPool(lpUSDT.address);


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

  }

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
