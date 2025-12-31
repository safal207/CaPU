import fs from "node:fs";
import path from "node:path";
import Ajv2020 from "ajv/dist/2020.js";

const ROOT = process.cwd();

const examples = [
  { file: "examples/ports-causein.json", schema: "schemas/ports/causein.schema.json" },
  { file: "examples/ports-decision.json", schema: "schemas/ports/permissionout.schema.json" },
  { file: "examples/ports-effectplan.json", schema: "schemas/ports/effectout.schema.json" },
  { file: "examples/ports-traceevent.json", schema: "schemas/ports/traceout.schema.json" }
];

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
const sharedSchemas = [
  "schemas/ports/envelope.schema.json",
  "schemas/ports/causein.schema.json",
  "schemas/ports/permissionout.schema.json",
  "schemas/ports/effectout.schema.json",
  "schemas/ports/traceout.schema.json"
].map(readJson);

for (const s of sharedSchemas) {
  ajv.addSchema(s);
}

let ok = true;

for (const { file, schema } of examples) {
  const data = readJson(file);
  const schemaObj = readJson(schema);

  // Compile from the already-registered schema (by $id) when possible.
  const validate =
    (schemaObj.$id && ajv.getSchema(schemaObj.$id)) || ajv.compile(schemaObj);
  const valid = validate(data);

  if (!valid) {
    ok = false;
    console.error(`\n❌ Validation failed: ${file}\nSchema: ${schema}\n`);
    for (const err of validate.errors || []) {
      console.error(`- ${err.instancePath || "/"} ${err.message}`);
    }
  } else {
    console.log(`✅ ${file}`);
  }
}

if (!ok) process.exit(1);
console.log("\nAll example files are valid ✅");
