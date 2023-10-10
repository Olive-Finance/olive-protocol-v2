import { getContractFactory } from "@nomiclabs/hardhat-ethers/types";
import { ethers } from "hardhat";

async function mainGLP() {
    // Get generated signer wallets
    const accounts = await ethers.getSigners();

    // Get the first wallet address
    const owner = accounts[0];
    const u1 = accounts[1];

    //Commands to interact with contract
    const Token = await ethers.getContractFactory("Token");
    const wETH = await Token.attach('0x49a138102102802785137a54a82CC47C3139a5aF');
    const glp = await Token.attach('0x0Fc112174e17D5F21c127e893E7Ac1CF6B0e86D0');
    const usdc = await Token.attach('0x761EA2A43E38e4402a57Ba452D69dB3577139aC3');

    // Olive vault and strategy tokens
    const aUSDC = await Token.attach('0x55162980938AD8cFB53bCcA4fd4C4A33f2425A52');
    const doUSDC = await Token.attach('0x2438D4EfFC667d26Dc7aa72eC9933Fd85Fc0aE5b');
    const oGlp = await Token.attach('0x0Adef0bE94529472653147e2BF3b8DF031503f3f');
    const sGlp = await Token.attach('0x46F1cd8394A3eC87C43B69c866B5dC8745321412');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0xcC3CF809a61466897a2081c3f115362Fa53b278b');

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.attach('0xD3B7c627BDD6c12610e6763816b4085515d7dDdF');

    const Limit = await ethers.getContractFactory("Limit");
    const limit = await Limit.attach('0x6d7412Ed81a7E6a500b6E61bb4ca248BE61A26E9');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0x23dDB789bAddde7Fc6dAd03D17119AAD0558f728');

    // 0xebE59359EB6249D40F76586BBFca78C26238F99C
    const pool1 = await LPUSDC.attach('0xebE59359EB6249D40F76586BBFca78C26238F99C');  // old pool

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await Strategy.attach('0xd1313F90f5E05EafBAdc312807a5e6f2cE19a228');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.attach('0x588234822d199F426A900187B53FAD544E0Cc788');

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0x68d7BA2600c327eB0F3299175Cc943191E817Bb0');

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.attach('0x4fD9199515130930FF71c3400fFA335Aa1125EF7');

    const GLPMockRouter = await ethers.getContractFactory("GLPMock");
    const glpMockRouter = await GLPMockRouter.attach('0x2eAd6C7c2A36e357D9056448E46d21D796C416A5'); 

    const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
    const phMock = await PriceHelperMock.attach('0xD8031cd30FC51cA9A198835d7E7E13404F7aBE84');

    const Faucet = await ethers.getContractFactory('Faucet');
    const faucet = await Faucet.attach('0x65f6E41a9CfECFC5F67D7d8B948E6f92C24d00A8');
}

async function mainGM() {
    // Get generated signer wallets
    const accounts = await ethers.getSigners();

    // Get the first wallet address
    const owner = accounts[0];
    const u1 = accounts[1];

    //Commands to interact with contract
    const Token = await ethers.getContractFactory("Token");
    const glp = await Token.attach('0x92646e75EdCefb9d20537bcab3D01D4c92212B20');
    const usdc = await Token.attach('0x761EA2A43E38e4402a57Ba452D69dB3577139aC3');

    // Olive vault and strategy tokens
    const aUSDC = await Token.attach('0x1a60f859d2228BcF764341CAaF1DBa0470cc192a');
    const doUSDC = await Token.attach('0xfB51216345f075288e6B62c192B78be403F74675');
    const oGlp = await Token.attach('0x234C1aE3Df5Cf2F2ECE3ce31e3C733995Ab65074');
    const sGlp = await Token.attach('0x774AfB69ee17470631Ba42b0aF4eD7eAfe01f570');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0xcC3CF809a61466897a2081c3f115362Fa53b278b');

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.attach('0xBBFDb5CEA36d7c592F48234a12C3ec2Abf57b7F3');

    const Limit = await ethers.getContractFactory("Limit");
    const limit = await Limit.attach('0x2eE18435E9a9e8F0f99a9Aa07c6F30AA902351b5');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0x38A348d8bDCa79bE045283dD5CE416ea5f482d52');

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await Strategy.attach('0xD17A1f70cf969339FCd80EbB8FF204de1a652B1E');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.attach('0xa1262a5d53e5Acd3fE09fC0608955F5D744Ffd6f');

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0x47154Cf3426b262c833BEFb735cEdF89A084b40C');

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.attach('0x888464B28Da623cCF4051F12816e9501026d7298');

    const GLPMockRouter = await ethers.getContractFactory("GLPMock");
    const glpMockRouter = await GLPMockRouter.attach('0x6281e9BD216d9Ae1DB6707A8aD94d9800491004E'); 

    const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
    const phMock = await PriceHelperMock.attach('0xF20702Cc877DF49Fb0Cd82cf65a695629Ea576E5');
}

mainGLP().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });