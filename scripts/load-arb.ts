import { getContractFactory } from "@nomiclabs/hardhat-ethers/types";
import { ethers } from "hardhat";

async function main() {
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

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0xebE59359EB6249D40F76586BBFca78C26238F99C');

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await Strategy.attach('0xd1313F90f5E05EafBAdc312807a5e6f2cE19a228');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.attach('0x588234822d199F426A900187B53FAD544E0Cc788');

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0x32e4D856ef5AbB27C6F3da3E0511d0E3D6BbDE38');
    // 0x32e4D856ef5AbB27C6F3da3E0511d0E3D6BbDE38 -- new address
    // 0xeaFAB0Fe3234c90F346F287F75080297D3eAb712 -- old address

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.attach('0x4fD9199515130930FF71c3400fFA335Aa1125EF7');

    const GLPMockRouter = await ethers.getContractFactory("GLPMock");
    const glpMockRouter = await GLPMockRouter.attach('0x2eAd6C7c2A36e357D9056448E46d21D796C416A5'); 

    const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
    const phMock = await PriceHelperMock.attach('0xD8031cd30FC51cA9A198835d7E7E13404F7aBE84');

    const Faucet = await ethers.getContractFactory('Faucet');
    const faucet = await Faucet.attach('0x9814C9139A0B897d2F22B7610B1662C1104485A8');
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

  // 0x55b587b0d01e5D66E85e1e8e9FD509052BB2A1D3