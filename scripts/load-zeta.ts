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
    const wETH = await Token.attach('0x7Cb9def4c74157704822bC8CA4e28c64C59c6154');
    const glp = await Token.attach('0xE221496617A3f8851C860ba16dFBaD3dd3942C6F');
    const usdc = await Token.attach('0xbc04c227D547eC5A5CF90cAD8E0CE32BA82c267c');

    // Olive vault and strategy tokens
    const aUSDC = await Token.attach('0x1E9176C4b6001567093193889f3422EBA26cEA25');
    const doUSDC = await Token.attach('0x3eDde2731ace3cf1ed33Da15Dd6F79a53a69039f');
    const oGlp = await Token.attach('0x7Cc1817B372169A6a8b66D8501ba71eF8C70fd75');
    const sGlp = await Token.attach('0x466F3374fCF69A9b5d85C94864C7aEb4921743A6');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0x175941a1Cec4D642AA924Dd8324717Ff3E508cB8');

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.attach('0xfe7263bB45E8B4EB11818E8feCfe19D2Fb98875C');

    const Limit = await ethers.getContractFactory("Limit");
    const limit = await Limit.attach('0x26AAcEb979D42E63fA4Ed714309c793617571732');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0x2462259A0E1a921aDD5F7EE5D8C4Eb8208a83E2b');

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await Strategy.attach('0xfCbf74C116beC2a6aE8C7bbAFA43dA959A327690');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.attach('0xD748C1Cf693f2BaA23659C2dBfA27B8d2879B0E3');

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0x928AE378D8407D53b5f79f0f7Fbd520d0DD31D43');

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.attach('0xF57243570616293d4Afdfc163d16E746D9619F14');

    const GLPMockRouter = await ethers.getContractFactory("GLPMock");
    const glpMockRouter = await GLPMockRouter.attach('0xbde66954AD9858D079e203462CF39a1564973bce'); 

    const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
    const phMock = await PriceHelperMock.attach('0x61947580d3E30E94404190f3A7CDbd8cA73d2860');

    const Faucet = await ethers.getContractFactory('Faucet');
    const faucet = await Faucet.attach('0x9d38E68418D8DB37067c35Cf1BEEBCbb118aDed4');
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

  // 0x55b587b0d01e5D66E85e1e8e9FD509052BB2A1D3