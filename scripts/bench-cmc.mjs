#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..");
const cmcDir = resolve(repoRoot, "rust", "cmc-core");

console.log("Running CMC developer microbenchmark...");
console.log(`cwd: ${cmcDir}`);

const result = spawnSync(
  "cargo",
  ["run", "--release", "--bin", "cmc_bench", "--locked"],
  {
    cwd: cmcDir,
    stdio: "inherit",
    shell: process.platform === "win32",
  },
);

if (result.error) {
  console.error(`Failed to run cargo: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
