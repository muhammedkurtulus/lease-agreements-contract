import hre, { ethers } from "hardhat";
import { sleep } from "./utils/util";

async function main() {
  const network = await ethers.provider.getNetwork();
  console.log("chainId", network.chainId);

  const lease = await ethers.deployContract("Lease");

  await lease.waitForDeployment();

  console.log(`Lease contract deployed to ${lease.target}`);

  if (Number(network.chainId) == 1337) return;

  try {
    console.log("Waiting for verfication...");
    await sleep(10000);

    await hre.run("verify:verify", {
      address: lease.target,
    });
  } catch (error) {
    console.error(error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
