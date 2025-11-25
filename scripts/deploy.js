// scripts/deploy.js (auto-find artifact, run with: node scripts/deploy.js)
// Works in ESM projects (package.json "type": "module") — uses ethers package

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { ethers } from "ethers";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  // find artifact JSON under artifacts/contracts/*/*.json
  const artifactsDir = path.join(__dirname, "..", "artifacts", "contracts");
  if (!fs.existsSync(artifactsDir)) {
    console.error("Artifacts directory not found. Run: npx hardhat compile");
    process.exit(1);
  }

  // find first JSON artifact in subfolders
  const subfolders = fs.readdirSync(artifactsDir, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  let artifactPath = null;
  for (const sub of subfolders) {
    const folder = path.join(artifactsDir, sub);
    const files = fs.readdirSync(folder).filter(f => f.endsWith(".json"));
    if (files.length) {
      // prefer CarRentalSimple.json if present
      const preferred = files.find(f => f.toLowerCase().includes("carrentalsimple") || f.toLowerCase().includes("smartrental"));
      artifactPath = preferred ? path.join(folder, preferred) : path.join(folder, files[0]);
      break;
    }
  }

  if (!artifactPath) {
    console.error("No contract artifact found under artifacts/contracts. Run: npx hardhat compile");
    process.exit(1);
  }

  console.log("Using artifact:", artifactPath);
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

  const abi = artifact.abi;
  const bytecode = artifact.bytecode?.object ?? artifact.bytecode;
  if (!bytecode || bytecode === "0x") {
    console.error("Bytecode missing in artifact:", artifactPath);
    process.exit(1);
  }

  // provider and wallet (uses Hardhat node default RPC)
  const rpc = process.env.RPC_URL || "http://127.0.0.1:8545";
  const provider = new ethers.JsonRpcProvider(rpc);

  // Use PRIVATE_KEY env var if provided, otherwise use Hardhat default dev key
  const envKey = process.env.PRIVATE_KEY;
  const defaultKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  const privateKey = envKey && envKey.length ? envKey : defaultKey;

  const wallet = new ethers.Wallet(privateKey, provider);
  const deployer = await wallet.getAddress();
  console.log("Using deployer:", deployer);

  // build tx
  const tx = {
    from: deployer,
    data: bytecode,
    gasLimit: 6_000_000n
  };

  try {
    const est = await provider.estimateGas({ from: deployer, data: bytecode });
    tx.gasLimit = (est * 120n) / 100n;
    console.log("estimated gas:", est.toString(), "using gasLimit:", tx.gasLimit.toString());
  } catch (err) {
    console.log("estimateGas failed, using default gasLimit");
  }

  tx.nonce = await provider.getTransactionCount(deployer);

  console.log("Sending deployment transaction...");
  const txResp = await wallet.sendTransaction(tx);
  console.log("tx hash:", txResp.hash);
  const receipt = await provider.waitForTransaction(txResp.hash);
  if (!receipt) {
    console.error("No receipt received.");
    process.exit(1);
  }

  const contractAddress = receipt.contractAddress ?? receipt.creates ?? null;
  console.log("Contract deployed at:", contractAddress);
  console.log("Paste this address into frontend/index.html -> CONTRACT_ADDRESS");
}

main().catch((err) => {
  console.error("Deployment error:", err);
  process.exit(1);
});
