import { ethers } from "hardhat";

async function main() {
    //Commands to interact with contract
    const GLP = await ethers.getContractFactory("Token");
    const glp = await GLP.attach('0x5FbDB2315678afecb367f032d93F642f64180aa3');

    // Lending pools
    const USDC = await ethers.getContractFactory("Token");
    const usdc = await USDC.attach('0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512');

    // ATokens for pools
    const AUSDC = await ethers.getContractFactory("Token");
    const aUSDC = await AUSDC.attach('0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9');
    
    // doTokens for pools
    const DOUSDC = await ethers.getContractFactory("Token");
    const doUSDC = await DOUSDC.attach('0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0');

    //Rate calculator
    const RCL = await ethers.getContractFactory("RateCalculator");
    const rcl = await RCL.attach('0x0165878A594ca255338adfa4d48449f69242Eb8F');

    // Lending pools and grant roles for a and do tokens
    const LPUSDC = await ethers.getContractFactory("Pool");
    const lpUSDC = await LPUSDC.attach('0xa513E6E4b8f2a923D98304ec87F64353C4D5C853');
    await aUSDC.grantRole(lpUSDC.address);
    await doUSDC.grantRole(lpUSDC.address);

    // Olive vault and strategy tokens
    const SOToken = await ethers.getContractFactory("Token");
    const soToken = await SOToken.attach('0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9');
    
    const OToken = await ethers.getContractFactory("Token");
    const oToken = await OToken.attach('0x5FC8d32690cc91D4c39d9d3abcBD16989F875707');


    const Strategy = await ethers.getContractFactory('Strategy');
    const strategy = await Strategy.attach('0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6');
    await soToken.grantRole(strategy.address);

    const GLPManager = await ethers.getContractFactory("GLPManager");
    const glpManager = await GLPManager.attach('0x8A791620dd6260079BF849Dc5567aDC3F2FdC318');
    await glp.grantRole(glpManager.address);

    const Olive = await ethers.getContractFactory("OliveV2");
    const olive = await Olive.attach('0x610178dA211FEF7D417bC0e6FeD39F05609AD788');
    await oToken.grantRole(olive.address);
    // await coToken.grantRole(olive.address);

    let user = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
    
    await rcl.calculateBorrowRate(0.995e12);
    await rcl.calculateSimpleInterest(0.02e12, 0, 365*86400)/1e12;
    await rcl.calculateCompoundInterest(0.02e12, 0, 365*86400)/1e12;


    // function to execute 
    await glp.mint(user, 100e8);
    await usdc.mint(user, 1000e8);
   
    // Approvals for olive vault
    await glp.approve(olive.address, 1000000e8);
    await usdc.approve(lpUSDC.address, 1e14);
   
    // fund the pools
    await lpUSDC.fund(user, 100e8);
    

    // Set the mock price feed
    await glpManager.setPrice(usdc.address, 0.5e4);

    1685939886
    1685939924


    // Allow Olive contract to borrow from the pool
    await lpUSDC.grantRole(olive.address);


    await glp.balanceOf(user);
    await glp.balanceOf(olive.address);
    await glp.balanceOf(strategy.address);

    await oToken.balanceOf(user);
    await oToken.balanceOf(olive.address);
    await oToken.balanceOf(strategy.address);

    // await coToken.balanceOf(user);
    // await coToken.balanceOf(olive.address);
    // await coToken.balanceOf(strategy.address);

    // Call the deposit function
    await olive.deposit(10e8, 5e2);
    await olive.deposit(40e8, 5e2);
    await olive.deleverage(2);

    await soToken.balanceOf(user);
    await soToken.balanceOf(olive.address);
    await soToken.balanceOf(strategy.address);

    await doUSDC.balanceOf(user);
   
    await usdc.balanceOf(user);
    await usdc.balanceOf(lpUSDC.address);

    
    await usdc.balanceOf(olive.address);
    
    // Call the deposit with leverage
    await olive.deposit(10e8, 5);
    await olive.hf(user);

    await olive.deleverage(30e8);
    await olive.hf(user);

    await olive.hf(user);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });