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
    const aUSDC = await Token.attach('0x34F6e69C5a2F20C2C1f2285acbBc0208901B3CEa');
    const doUSDC = await Token.attach('0x5bc7cC11bF6CCf7650cDC11948DA61A60310eA0f');
    const oGlp = await Token.attach('0xD647f808f5dc9d1890210b368766a405F7057803');
    const sGlp = await Token.attach('0xFfC3D4393A1e3130EF1bCEbd64F3d8256d7433E8');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0xcC3CF809a61466897a2081c3f115362Fa53b278b');

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.attach('0xD3B7c627BDD6c12610e6763816b4085515d7dDdF');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0x19cB35A65ded630Ff1f7Afb7a652FDFC4E63C9C3');

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await Strategy.attach('0xcFD658FD8Aedd99F92fC5Cc0af1b4E8D9cAc7f44');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.attach('0x91958BDFC2FFd1F573136128Af159DCfb636CcDa');

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0xd9f29b4F8aaA8d54FdCf3cb5e18B2eD789B2aFF2');

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.attach('0x6006b052a66d9683904Ed81293b6BE5ABB49fFE1');

    const GLPMockRouter = await ethers.getContractFactory("GLPMock");
    const glpMockRouter = await GLPMockRouter.attach('0x2eAd6C7c2A36e357D9056448E46d21D796C416A5'); 

    const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
    const phMock = await PriceHelperMock.attach('0xD8031cd30FC51cA9A198835d7E7E13404F7aBE84');
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

  // 0x55b587b0d01e5D66E85e1e8e9FD509052BB2A1D3