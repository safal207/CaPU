import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const ROOT = process.cwd();

const checks = [
  ["npm", ["run", "validate:examples"]],
  ["npm", ["run", "test:reference"]],
  ["npm", ["run", "verify:golden"]]
];

function runCheck([cmd, args]) {
  const result = spawnSync(cmd, args, {
    cwd: ROOT,
    encoding: "utf8",
    shell: process.platform === "win32"
  });
  return {
    command: [cmd, ...args].join(" "),
    status: result.status === 0 ? "PASS" : "FAIL",
    stdout: (result.stdout || "").trim(),
    stderr: (result.stderr || "").trim()
  };
}

const results = checks.map(runCheck);
const failed = results.filter((item) => item.status !== "PASS").length;

const lines = [
  "# CaPU Validation Results",
  "",
  "Tracked local validation snapshot for the current CaPU reference runtime and schema surface.",
  "",
  "## Summary",
  "",
  `- Total checks: **${results.length}**`,
  `- Passed: **${results.length - failed}**`,
  `- Failed: **${failed}**`,
  "",
  "## Checks",
  "",
  "| command | status |",
  "|---|---|"
];

for (const result of results) {
  lines.push(`| \`${result.command}\` | ${result.status} |`);
}

lines.push("", "## Outputs", "");

for (const result of results) {
  lines.push(`### \`${result.command}\``, "", `- Status: **${result.status}**`);
  if (result.stdout) {
    lines.push("- Stdout:", "```text", result.stdout, "```");
  }
  if (result.stderr) {
    lines.push("- Stderr:", "```text", result.stderr, "```");
  }
  lines.push("");
}

fs.writeFileSync(path.resolve(ROOT, "VALIDATION_RESULTS.md"), `${lines.join("\n")}\n`, "utf8");

if (failed > 0) {
  process.exit(1);
}