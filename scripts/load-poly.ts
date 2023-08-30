import { ethers } from "hardhat";

async function main() {
    // Get generated signer wallets
    const accounts = await ethers.getSigners();

    // Get the first wallet address
    const owner = accounts[0];
    const u1 = accounts[1];

    //Commands to interact with contract
    const Token = await ethers.getContractFactory("Token");
    const wETH = await Token.attach('0x104C5e85E9a58b490bB0Ce447b24b5467e33F4EC');
    const glp = await Token.attach('0x35E5630d8e7dC4e6C21c892d937458414a75333c');
    const usdc = await Token.attach('0xb5Ac3e84F7f085690fE18E10D71621F722AFDB80');

    // Olive vault and strategy tokens
    const aUSDC = await Token.attach('0xD24CdBEC3F4108D67609A636eaD622e21AF4e23f');
    const doUSDC = await Token.attach('0x8c0E6fdb21D724eD527F5b1841200Ac341582B93');
    const oGlp = await Token.attach('0xB06eEc3870255679aa5B7FE1f3b98fDE0a577197');
    const sGlp = await Token.attach('0x86780DA19E5E4E5c220066D047ae2FC4872B7EBF');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0xd9A27Ff9Eb9c95718A346EA59497BD082d90b482');

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.attach('0x960AE5779E3385F1bB86e90cff93BCF7FBA728cc');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0x492887E01e7be36F9293a6B9ed72b5df9f9781ee');

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await Strategy.attach('0x053b4b88aC3e6e1C35834706A9BBcBeFf4Af4a95');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.attach('0x3Bf2b774a06C84fe83c21188D97fd6BaE84bdF80');

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0xAd312c51e84d2FEe10a81Cdfab11618A23A86DfC');

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.attach('0x48C1dD9Fc4211A8F47E7bC92ea89bB944027175c');

    const GLPMockRouter = await ethers.getContractFactory("GLPMock");
    const glpMockRouter = await GLPMockRouter.attach('0x09A9E9F2204c67628c975840408004CE0E41765a'); 

    const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
    const phMock = await PriceHelperMock.attach('0x97577CAa0672e5B5838D8B1ED71ae0eCAd46d88a');
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

  // 0x55b587b0d01e5D66E85e1e8e9FD509052BB2A1D3