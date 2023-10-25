import { ethers } from "hardhat";

async function main() {
  const lease = await ethers.deployContract("Lease");

  await lease.waitForDeployment();

  console.log(`Lease contract deployed to ${lease.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
