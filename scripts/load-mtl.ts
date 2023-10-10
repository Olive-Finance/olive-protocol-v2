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
    const glp = await Token.attach('0x26AAcEb979D42E63fA4Ed714309c793617571732');
    const usdc = await Token.attach('0x162943A3dd8Fce2C2bB31e4Da2Bc0D92f6FF5322');

    // Olive vault and strategy tokens
    const aUSDC = await Token.attach('0xbc04c227D547eC5A5CF90cAD8E0CE32BA82c267c');
    const doUSDC = await Token.attach('0xE6B6744582eC5Bbb9eF2010Be6E07c9E2FebCb66');
    const oGlp = await Token.attach('0x2F274984B6afC5947f3B9De87D65a1F87662590C');
    const sGlp = await Token.attach('0xE4cf9B2A3A615B3d428086F5875fE5607A607060');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0x3eDde2731ace3cf1ed33Da15Dd6F79a53a69039f');

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.attach('0x1E9176C4b6001567093193889f3422EBA26cEA25');

    const Limit = await ethers.getContractFactory("Limit");
    const limit = await Limit.attach('0xfe7263bB45E8B4EB11818E8feCfe19D2Fb98875C');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0xd0C191732E5854f7e2Ed74cB9B19C57d6816EB0D');

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await Strategy.attach('0x992866723160657b3c582985408B379828e3318b');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.attach('0xE221496617A3f8851C860ba16dFBaD3dd3942C6F');

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0x7Cc1817B372169A6a8b66D8501ba71eF8C70fd75');

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.attach('0xD748C1Cf693f2BaA23659C2dBfA27B8d2879B0E3');

    const GLPMockRouter = await ethers.getContractFactory("GLPMock");
    const glpMockRouter = await GLPMockRouter.attach('0xfCbf74C116beC2a6aE8C7bbAFA43dA959A327690'); 

    const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
    const phMock = await PriceHelperMock.attach('0x465c17630F872337327F772AFB1fAf9E3Ae23aa7');

    const Faucet = await ethers.getContractFactory('Faucet');
    const faucet = await Faucet.attach('0x9814C9139A0B897d2F22B7610B1662C1104485A8');
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

  // 0x55b587b0d01e5D66E85e1e8e9FD509052BB2A1D3