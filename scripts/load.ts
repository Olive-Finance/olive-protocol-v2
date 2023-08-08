import { ethers } from "hardhat";

async function main() {
    // Get generated signer wallets
    const accounts = await ethers.getSigners();

    // Get the first wallet address
    const owner = accounts[0];
    const u1 = accounts[1];

    //Commands to interact with contract
    const GLP = await ethers.getContractFactory("Token");
    const glp = await GLP.attach('0x5FbDB2315678afecb367f032d93F642f64180aa3');

    // Lending pools
    const USDC = await ethers.getContractFactory("Token");
    const usdc = await USDC.attach('0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512');

    // Olive vault and strategy tokens
    const AToken = await ethers.getContractFactory("AToken");
    const aUSDC = await AToken.attach('0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9');
    const soGLP = await AToken.attach('0xa513E6E4b8f2a923D98304ec87F64353C4D5C853');
    const oGLP = await AToken.attach('0x0165878A594ca255338adfa4d48449f69242Eb8F');

    // doTokens for pools
    const DOUSDC = await ethers.getContractFactory("DToken");
    const doUSDC = await DOUSDC.attach('0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const lpUSDC = await LPUSDC.attach('0x5FC8d32690cc91D4c39d9d3abcBD16989F875707');
    await aUSDC.grantRole(lpUSDC.address);
    await doUSDC.grantRole(lpUSDC.address);

    const Strategy = await ethers.getContractFactory('Strategy');
    const strategy = await Strategy.attach('0x610178dA211FEF7D417bC0e6FeD39F05609AD788');
    await soGLP.grantRole(strategy.address);

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpCore = await GLPVault.attach('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6');
    await glp.grantRole(glpCore.address);

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0x8A791620dd6260079BF849Dc5567aDC3F2FdC318');
    
    // Call the deposit with leverage
    await vaultManager.connect(u1).deposit(ethers.utils.parseUnits('100', 18), ethers.utils.parseUnits('2', 18), 0, 0);
    await vaultManager.hf(u1.address);
    await vaultManager.connect(u1).leverage(ethers.utils.parseUnits('5', 18), 0, 0);
    await vaultManager.connect(owner).closePosition(u1.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });