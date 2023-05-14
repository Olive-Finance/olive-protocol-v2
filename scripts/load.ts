import { ethers } from "hardhat";

async function main() {
    //Commands to interact with contract
    const USDC = await ethers.getContractFactory("USDC");
    const usdc = await USDC.attach('0x5FbDB2315678afecb367f032d93F642f64180aa3')

    const LPool = await ethers.getContractFactory("Pool");
    const lpool = await LPool.attach('0x0165878A594ca255338adfa4d48449f69242Eb8F');

    const AToken = await ethers.getContractFactory("AToken");
    const aToken = await AToken.attach('0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9');

    const Olive = await ethers.getContractFactory("OliveV2");
    const olive = await Olive.attach('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6');

    const OToken = await ethers.getContractFactory("OToken");
    const oToken = await OToken.attach('0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9');

    const DOToken = await ethers.getContractFactory("DOToken");
    const doToken = await DOToken.attach('0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0');

    const AOToken = await ethers.getContractFactory('AOToken');
    const aoToken = await AOToken.attach('0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512');

    const LPToken = await ethers.getContractFactory('LPToken');
    const lpToken = await LPToken.attach('0x5FC8d32690cc91D4c39d9d3abcBD16989F875707');

    const Strategy = await ethers.getContractFactory('Strategy');
    const strategy = await Strategy.attach('0xa513E6E4b8f2a923D98304ec87F64353C4D5C853');

    // function to execute 
    await usdc.mint('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', 100000000000);
    await usdc.balanceOf('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
    await usdc.approve('0x0165878A594ca255338adfa4d48449f69242Eb8F', 10000000000000)
    await aToken.grantRole('0x0165878A594ca255338adfa4d48449f69242Eb8F')
    await usdc.approve('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6', 10000000000000)
    await lpool.fund('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', 10000000000)
    await oToken.grantRole('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6');
    await doToken.grantRole('0x0165878A594ca255338adfa4d48449f69242Eb8F');
    await lpool.grantRole('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6');
    await lpToken.grantRole('0xa513E6E4b8f2a923D98304ec87F64353C4D5C853');
    await aoToken.approve('0x0165878A594ca255338adfa4d48449f69242Eb8F', 1000000000000);
    await oToken.approve('0x0165878A594ca255338adfa4d48449f69242Eb8F', 1000000000000);
    await aoToken.grantRole('0x0165878A594ca255338adfa4d48449f69242Eb8F');
    await olive.deposit(1000000000);
    await olive.depositWLeverage(1000000000, 5)
    await olive.deposit(1000000000);
    await usdc.balanceOf('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6')
    await oToken.balanceOf('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')
    await doToken.balanceOf('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')
    await olive.hf('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')

    await aoToken.balanceOf('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')
    await oToken.balanceOf('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')
    await doToken.balanceOf('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')

    await olive.getCurrentLeverage('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')
    await olive.hf('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')

    await usdc.balanceOf('0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266')
    await usdc.balanceOf('0x0165878A594ca255338adfa4d48449f69242Eb8F')
    await usdc.balanceOf('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6')
    await usdc.balanceOf('0xa513E6E4b8f2a923D98304ec87F64353C4D5C853')
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });