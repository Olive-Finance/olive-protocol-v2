import { ethers } from "hardhat";

async function main() {
    // Get generated signer wallets
    const accounts = await ethers.getSigners();

    // Get the first wallet address
    const owner = accounts[0];
    const u1 = accounts[1];

    //Commands to interact with contract
    const GLP = await ethers.getContractFactory("Token");
    const glp = await GLP.attach('0x0165878A594ca255338adfa4d48449f69242Eb8F');

    // Lending pools
    const USDC = await ethers.getContractFactory("Token");
    const usdc = await USDC.attach('0xa513E6E4b8f2a923D98304ec87F64353C4D5C853');

    // ATokens for pools
    const AUSDC = await ethers.getContractFactory("Token");
    const aUSDC = await AUSDC.attach('0x8A791620dd6260079BF849Dc5567aDC3F2FdC318');
    
    // doTokens for pools
    const DOUSDC = await ethers.getContractFactory("Token");
    const doUSDC = await DOUSDC.attach('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0x610178dA211FEF7D417bC0e6FeD39F05609AD788');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("Pool");
    const lpUSDC = await LPUSDC.attach('0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e');
    await aUSDC.grantRole(lpUSDC.address);
    await doUSDC.grantRole(lpUSDC.address);

    // Olive vault and strategy tokens
    const SOToken = await ethers.getContractFactory("Token");
    const soToken = await SOToken.attach('0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9');
    
    const OToken = await ethers.getContractFactory("Token");
    const oToken = await OToken.attach('0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0');


    const Strategy = await ethers.getContractFactory('Strategy');
    const strategy = await Strategy.attach('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6');
    await soToken.grantRole(strategy.address);

    const GLPManager = await ethers.getContractFactory("GLPVault");
    const glpManager = await GLPManager.attach('0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82');
    await glp.grantRole(glpManager.address);

    const Olive = await ethers.getContractFactory("VaultManager");
    const olive = await Olive.attach('0x9A676e781A523b5d0C0e43731313A708CB607508');
    await oToken.grantRole(olive.address);
    // await coToken.grantRole(olive.address);
    
    // Call the deposit with leverage
    await olive.connect(u1).deposit(ethers.utils.parseUnits('100', 18), ethers.utils.parseUnits('1', 8), 0, 0);
    await olive.hf(u1.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });