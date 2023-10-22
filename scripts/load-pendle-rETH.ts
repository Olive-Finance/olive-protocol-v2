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
    const wETH = await Token.attach('0x2462259A0E1a921aDD5F7EE5D8C4Eb8208a83E2b');
    const glp = await Token.attach('0x1F3553b5297097Dbe5067bc809E7083Ecc9ff559');
    const usdc = await Token.attach('0xeb10C2DB1A44b5E25Ed49dFBaf3c9C58eA865bd4');

    // Olive vault and strategy tokens
    const aUSDC = await Token.attach('0x442Edda629b2E88C170315EA3BceB3A1fb9ad8ce');
    const doUSDC = await Token.attach('0x63B90C0f88F3Aea8B42031CA619b86ae0836BB75');
    const oGlp = await Token.attach('0x31E76e8CEcD5c9a7aB8331731e9575dDcc438725');
    const sGlp = await Token.attach('0xeb61ef8331a6c0F273826055A408E06C263Dc9dc');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0x3C54131c02999315eba4A8760F6Dd9f0b1b119B1');

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.attach('0xC6132aCFc03Eea0AabF7af0899BD180E41b7d67C');

    const Limit = await ethers.getContractFactory("Limit");
    const limit = await Limit.attach('0x69692fe856773D458D369FCB3729c1D5631EE7e9');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0xa4CAbd5Ba92BbF41A703386865768b24D75ffc03');

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await Strategy.attach('0xfA0E7CC37220897e23480091EacfA53D20BFFb8f');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.attach('0x737Fe3C755dE88AD00552218a1814Ba3727E1D72');

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0x8730da9841D16aDc43AFD433c5B441519e350d33');

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.attach('0xb94258559Bffbb043A2b03A3a8c959F1C7275ab2');

    const GLPMockRouter = await ethers.getContractFactory("GLPMock");
    const glpMockRouter = await GLPMockRouter.attach('0xb667144Bb16168140Ea9832358Ff266E3a0be239'); 

    const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
    const phMock = await PriceHelperMock.attach('0xf18333B2D50b86Ad0984668D7b05229bea65FD0F');

    const Faucet = await ethers.getContractFactory('Faucet');
    const faucet = await Faucet.attach('0x9d38E68418D8DB37067c35Cf1BEEBCbb118aDed4');
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

  // 0x55b587b0d01e5D66E85e1e8e9FD509052BB2A1D3