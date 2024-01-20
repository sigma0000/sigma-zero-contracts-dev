import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log('Deploying contracts with the account:', deployer.address);
  
  const sigmaZero = await ethers.deployContract("SigmaZero", []);

  await sigmaZero.waitForDeployment();
  const myContractDeployedAddress = await sigmaZero.getAddress();
  console.log(`SigmaZero deployed to: ${myContractDeployedAddress}`);
}
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
