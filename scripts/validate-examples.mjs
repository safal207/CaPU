import fs from "node:fs";
import path from "node:path";
import Ajv2020 from "ajv/dist/2020.js";
import readline from "node:readline";

const ROOT = process.cwd();

const examples = [
  { file: "examples/ports-causein.json", schema: "schemas/ports/causein.schema.json" },
  { file: "examples/ports-decision.json", schema: "schemas/ports/permissionout.schema.json" },
  { file: "examples/ports-effectplan.json", schema: "schemas/ports/effectout.schema.json" },
  { file: "examples/ports-traceevent.json", schema: "schemas/ports/traceout.schema.json" }
];

const goldenFlowFile = "examples/golden_flow.jsonl";

const schemaByTopKey = {
  submit: "schemas/ports/causein.schema.json",
  decision: "schemas/ports/permissionout.schema.json",
  effect_plan: "schemas/ports/effectout.schema.json",
  trace_event: "schemas/ports/traceout.schema.json"
};

// Use Ajv2020 for draft 2020-12 schemas.
const ajv = new Ajv2020({
  strict: true,
  allErrors: true,
  // Avoid ajv-formats ESM meta-schema crash in CI
  validateFormats: false
});

function readJson(rel) {
  const p = path.resolve(ROOT, rel);
  return JSON.parse(fs.readFileSync(p, "utf-8"));
}

// Register shared schemas so $ref resolution is deterministic.
// (Works best when refs point to schema $id URLs.)
const sharedSchemaPaths = [
  "schemas/ports/envelope.schema.json",
  "schemas/ports/causein.schema.json",
  "schemas/ports/permissionout.schema.json",
  "schemas/ports/effectout.schema.json",
  "schemas/ports/traceout.schema.json"
];

let ok = true;
function fail(msg) {
  ok = false;
  console.error(msg);
}

function registerSharedSchemas() {
  const sharedSchemas = sharedSchemaPaths.map(readJson);

  // Ensure every shared schema has a stable $id and is registered under that $id.
  for (const s of sharedSchemas) {
    if (!s || typeof s !== "object") {
      fail(`\n❌ Shared schema is not an object (check JSON): ${JSON.stringify(s)?.slice(0, 80) || "(unknown)"}\n`);
      continue;
    }
    if (!s.$id || typeof s.$id !== "string") {
      fail(`\n❌ Shared schema missing $id (required for deterministic $ref): ${s?.title || "(no title)"}\n`);
      continue;
    }
    ajv.addSchema(s);
  }

  // Verify registration worked (no silent drift).
  for (const s of sharedSchemas) {
    if (s?.$id && !ajv.getSchema(s.$id)) {
      fail(`\n❌ Shared schema not registered in Ajv for $id: ${s.$id}\n`);
    }
  }
}

function compileSchema(schemaPath) {
  const schemaObj = readJson(schemaPath);
  return (
    (schemaObj.$id && ajv.getSchema(schemaObj.$id)) ||
    ajv.compile(schemaObj)
  );
}

function printErrors(prefix, validateFn) {
  for (const err of validateFn.errors || []) {
    console.error(`- ${prefix}${err.instancePath || "/"} ${err.message}`);
  }
}

async function main() {
  registerSharedSchemas();
  for (const { file, schema } of examples) {
    const data = readJson(file);
    const validate = compileSchema(schema);
    const valid = validate(data);

    if (!valid) {
      ok = false;
      console.error(`\n❌ Validation failed: ${file}\nSchema: ${schema}\n`);
      printErrors("", validate);
    } else {
      console.log(`✅ ${file}`);
    }
  }

  // Validate golden flow JSONL (each line is a single port object)
  const goldenPath = path.resolve(ROOT, goldenFlowFile);
  let goldenOk = true;
  if (!fs.existsSync(goldenPath)) {
    ok = false;
    goldenOk = false;
    console.error(`\n❌ Missing golden flow file: ${goldenFlowFile}\n`);
  } else {
    const validators = {};
    for (const [key, schemaPath] of Object.entries(schemaByTopKey)) {
      validators[key] = compileSchema(schemaPath);
    }

    const rl = readline.createInterface({
      input: fs.createReadStream(goldenPath, { encoding: "utf-8" }),
      crlfDelay: Infinity
    });

    let lineNo = 0;
    for await (const line of rl) {
      lineNo += 1;
      const trimmed = line.trim();
      if (!trimmed) continue; // allow blank lines

      let obj;
      try {
        obj = JSON.parse(trimmed);
      } catch (e) {
        ok = false;
        goldenOk = false;
        console.error(`\n❌ ${goldenFlowFile}:${lineNo} invalid JSON\n- ${String(e.message || e)}\n`);
        continue;
      }

      const keys = Object.keys(obj || {});
      if (keys.length !== 1) {
        ok = false;
        goldenOk = false;
        console.error(`\n❌ ${goldenFlowFile}:${lineNo} must contain exactly one top-level key\n- got: ${keys.join(", ") || "(none)"}\n`);
        continue;
      }

      const topKey = keys[0];
      const validate = validators[topKey];
      if (!validate) {
        ok = false;
        goldenOk = false;
        console.error(`\n❌ ${goldenFlowFile}:${lineNo} unknown top-level key\n- got: ${topKey}\n- allowed: ${Object.keys(schemaByTopKey).join(", ")}\n`);
        continue;
      }

      const valid = validate(obj);
      if (!valid) {
        ok = false;
        goldenOk = false;
        console.error(`\n❌ Validation failed: ${goldenFlowFile}:${lineNo}\nSchema: ${schemaByTopKey[topKey]}\n`);
        printErrors("", validate);
      }
    }

    if (goldenOk) console.log(`✅ ${goldenFlowFile}`);
  }

  if (!ok) process.exit(1);
  console.log("\nAll example files are valid ✅");
}

main().catch((e) => {
  console.error("\n❌ Validator crashed\n- " + String(e?.stack || e));
  process.exit(1);
});
