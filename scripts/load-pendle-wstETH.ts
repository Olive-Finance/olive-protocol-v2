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
    const glp = await Token.attach('0x6fF2fF8d6De00388647a6bAB3630cCD55dbaA07A');
    const usdc = await Token.attach('0xeb10C2DB1A44b5E25Ed49dFBaf3c9C58eA865bd4');

    // Olive vault and strategy tokens
    const aUSDC = await Token.attach('0x442Edda629b2E88C170315EA3BceB3A1fb9ad8ce');
    const doUSDC = await Token.attach('0x63B90C0f88F3Aea8B42031CA619b86ae0836BB75');
    const oGlp = await Token.attach('0xfe26Ff994aAf2746637565dc90bdCA50553A1F50');
    const sGlp = await Token.attach('0xC60c995D6C5a6491Feae2B13666bD53704d48c5A');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0x3C54131c02999315eba4A8760F6Dd9f0b1b119B1');

    // Fees
    const Fees = await ethers.getContractFactory("Fees");
    const fees = await Fees.attach('0x6C21baA08b6e3CEFBf0b2ad362544f4951AB2cBe');

    const Limit = await ethers.getContractFactory("Limit");
    const limit = await Limit.attach('0x69692fe856773D458D369FCB3729c1D5631EE7e9');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("LendingPool");
    const pool = await LPUSDC.attach('0xa4CAbd5Ba92BbF41A703386865768b24D75ffc03');

    const Strategy = await ethers.getContractFactory('GLPStrategy');
    const stgy = await Strategy.attach('0x5C220a74b6ac404e6274e2D1EBD8BA788fBD11c2');

    const GLPVault = await ethers.getContractFactory("GLPVault");
    const glpVault = await GLPVault.attach('0x62F94224a86A55A70815340956f95eE9FBeC4A74');

    const VaultManager = await ethers.getContractFactory("VaultManager");
    const vaultManager = await VaultManager.attach('0x3ac34C4F159EE0A503D9b4c8fc0c1b92E942dA22');

    const VaultKeeper = await ethers.getContractFactory("VaultKeeper");
    const vaultKeeper = await VaultKeeper.attach('0x4D8DE8D70A1C10B42C4Bc35Cb57bc06c52ABA38E');

    const GLPMockRouter = await ethers.getContractFactory("GLPMock");
    const glpMockRouter = await GLPMockRouter.attach('0x2d6a655e8A31Ce04b1A8DBbD72E49965BbBDD34C'); 

    const PriceHelperMock = await ethers.getContractFactory("PriceHelperMock");
    const phMock = await PriceHelperMock.attach('0x0dACc43b97541A600147C0Cf4C7B0034Ea31AC11');

    const Faucet = await ethers.getContractFactory('Faucet');
    const faucet = await Faucet.attach('0x9d38E68418D8DB37067c35Cf1BEEBCbb118aDed4');

    // New faucet address : 0x1c2C1DfFD3de51Ea93d0cBA9308a32cFD142Ff0c
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

  // 0x55b587b0d01e5D66E85e1e8e9FD509052BB2A1D3

  const accounts = await ethers.getSigners();

    // Get the first wallet address
    const owner = accounts[0];
    const u1 = '0xebb83B26f452a328bc6C4e3aa458AE3F2DF844C4';

  const Token = await ethers.getContractFactory("Token");
  const Faucet = await ethers.getContractFactory('Faucet');
  const faucet = await Faucet.attach('0x1c2C1DfFD3de51Ea93d0cBA9308a32cFD142Ff0c');
  const wstETH = await Token.attach('0x6fF2fF8d6De00388647a6bAB3630cCD55dbaA07A');
  const rETH = await Token.attach('0x1F3553b5297097Dbe5067bc809E7083Ecc9ff559'); 
  const wEth = await Token.attach('0xeb10C2DB1A44b5E25Ed49dFBaf3c9C58eA865bd4');
  const gm = await Token.attach('0x92646e75EdCefb9d20537bcab3D01D4c92212B20');
  const usdc = await Token.attach('0x761EA2A43E38e4402a57Ba452D69dB3577139aC3');
  const glp = await Token.attach('0x0Fc112174e17D5F21c127e893E7Ac1CF6B0e86D0');

  await wstETH.burn(u1, await wstETH.balanceOf(u1));
  await rETH.burn(u1, await rETH.balanceOf(u1));
  await wEth.burn(u1, await wEth.balanceOf(u1));
  await gm.burn(u1, await gm.balanceOf(u1));
  await usdc.burn(u1, await usdc.balanceOf(u1));
  await glp.burn(u1, await glp.balanceOf(u1));



  await wstETH.grantRole(faucet.address);
  await rETH.grantRole(faucet.address);
  await wEth.grantRole(faucet.address);
  await gm.grantRole(faucet.address);
  await usdc.grantRole(faucet.address);
  await glp.grantRole(faucet.address);

  