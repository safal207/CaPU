import fs from "node:fs";
import path from "node:path";
import Ajv2020 from "ajv/dist/2020.js";

const ROOT = process.cwd();
const fixturePath = "examples/conformance/lifecycle-matrix.json";
const schemaPath = "schemas/conformance/lifecycle-matrix.schema.json";

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.resolve(ROOT, relativePath), "utf8"));
}

const matrix = readJson(fixturePath);
const schema = readJson(schemaPath);
const ajv = new Ajv2020({ strict: true, allErrors: true });
const validate = ajv.compile(schema);

if (!validate(matrix)) {
  for (const error of validate.errors || []) {
    console.error(`${error.instancePath || "/"} ${error.message}`);
  }
  process.exit(1);
}

const requiredIds = new Set([
  "valid-mature-commit-ok",
  "valid-mature-commit-fail",
  "valid-hold-mature-commit-ok",
  "valid-hold-expire",
  "invalid-reject",
  "policy-denied-reject",
  "missing-parent-hold"
]);

const decisionByTerminalEvent = {
  EXECUTE: "EXECUTE_OK",
  COMMIT_FAIL: "REJECT_COMMIT_FAILED",
  EXPIRE: "EXPIRED_NO_EXECUTE",
  GATE_REJECT_INVALID: "REJECT_INVALID",
  GATE_REJECT_POLICY: "REJECT_POLICY_DENIED"
};

const seen = new Set();

for (const scenario of matrix.scenarios) {
  if (seen.has(scenario.id)) throw new Error(`duplicate scenario id: ${scenario.id}`);
  seen.add(scenario.id);

  const events = scenario.events;
  const executeIndexes = events.flatMap((event, index) => event === "EXECUTE" ? [index] : []);
  const executeCount = executeIndexes.length;

  if (executeCount !== scenario.expected.execute_count) {
    throw new Error(`${scenario.id}: expected ${scenario.expected.execute_count} execute events, got ${executeCount}`);
  }

  for (const executeIndex of executeIndexes) {
    const before = events.slice(0, executeIndex);
    if (!before.includes("GATE_PERMIT") && !before.includes("PARENT_AVAILABLE")) {
      throw new Error(`${scenario.id}: execute lacks a permitted/parent-available path`);
    }
    if (!before.includes("MATURE")) throw new Error(`${scenario.id}: execute occurred before maturity`);
    if (!before.includes("COMMIT_OK")) throw new Error(`${scenario.id}: execute occurred before commit_ok`);
    if (before.some((event) => ["COMMIT_FAIL", "EXPIRE", "GATE_REJECT_INVALID", "GATE_REJECT_POLICY"].includes(event))) {
      throw new Error(`${scenario.id}: execute occurred after a terminal blocker`);
    }
    if (before.includes("MISSING_PARENT") && !before.includes("PARENT_AVAILABLE")) {
      throw new Error(`${scenario.id}: execute occurred before parent availability`);
    }
  }

  if (events.includes("HOLD") && executeCount > 0 && events.indexOf("HOLD") > events.indexOf("MATURE")) {
    throw new Error(`${scenario.id}: hold must precede maturity`);
  }

  const terminalEvent = events.at(-1);
  const actualDecision = decisionByTerminalEvent[terminalEvent];
  if (actualDecision !== scenario.expected.decision_code) {
    throw new Error(`${scenario.id}: expected decision ${scenario.expected.decision_code}, got ${actualDecision || "unknown"}`);
  }

  console.log(`CONFORMANCE_PASS ${scenario.id} decision=${actualDecision} execute_count=${executeCount}`);
}

for (const id of requiredIds) {
  if (!seen.has(id)) throw new Error(`missing required scenario: ${id}`);
}
if (seen.size !== requiredIds.size) throw new Error("unexpected scenarios require an explicit conformance-version update");

console.log("CAPU_LIFECYCLE_CONFORMANCE_V1_PASS");
