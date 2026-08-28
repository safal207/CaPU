import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const schemaDir = path.join(root, "schemas", "accelerator-effect-authority", "v1");
const fixtureDir = path.join(root, "fixtures", "accelerator-effect-authority-v1");

const readJson = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
const requestSchema = readJson(path.join(schemaDir, "request.schema.json"));
const evidenceSchema = readJson(path.join(schemaDir, "evidence.schema.json"));
const lifecycleSchema = readJson(path.join(schemaDir, "lifecycle.schema.json"));
const lifecycle = readJson(path.join(fixtureDir, "valid-lifecycle.json"));

const ajv = new Ajv2020({ allErrors: true, strict: false });
ajv.addSchema(requestSchema);
ajv.addSchema(evidenceSchema);
const validateLifecycle = ajv.compile(lifecycleSchema);

if (!validateLifecycle(lifecycle)) {
  throw new Error(`valid lifecycle failed schema validation: ${ajv.errorsText(validateLifecycle.errors)}`);
}
console.log("valid_lifecycle_schema_pass=1");

const clone = (value) => JSON.parse(JSON.stringify(value));
const structuralCases = [
  {
    name: "unknown_without_evidence_gate_schema_rejected",
    mutate(doc) { doc.evidence[2].evidence_required = false; },
  },
  {
    name: "false_success_without_outcome_schema_rejected",
    mutate(doc) { doc.evidence[4].committed_outcome_evidence_commitment = null; },
  },
  {
    name: "receipt_on_unknown_schema_rejected",
    mutate(doc) { doc.evidence[2].receipt_commitment = "9".repeat(64); },
  },
  {
    name: "missing_previous_commitment_schema_rejected",
    mutate(doc) { doc.evidence[3].previous_evidence_commitment = null; },
  },
];

for (const testCase of structuralCases) {
  const candidate = clone(lifecycle);
  testCase.mutate(candidate);
  const rejected = !validateLifecycle(candidate);
  console.log(`${testCase.name}=${rejected ? 1 : 0}`);
  if (!rejected) {
    throw new Error(`${testCase.name}: schema unexpectedly accepted candidate`);
  }
}

console.log("ACCELERATOR_EFFECT_AUTHORITY_V1_SCHEMA_PASS");
