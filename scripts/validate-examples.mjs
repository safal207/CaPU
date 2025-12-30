import fs from "node:fs";
import path from "node:path";
import Ajv from "ajv";
import draft2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const ROOT = process.cwd();

const examples = [
  { file: "examples/ports-causein.json", schema: "schemas/ports/causein.schema.json" },
  { file: "examples/ports-decision.json", schema: "schemas/ports/permissionout.schema.json" },
  { file: "examples/ports-effectplan.json", schema: "schemas/ports/effectout.schema.json" },
  { file: "examples/ports-traceevent.json", schema: "schemas/ports/traceout.schema.json" }
];

const ajv = new Ajv({ strict: true, allErrors: true });

addFormats(ajv);

ajv.addMetaSchema(draft2020);
ajv.addSchema(draft2020, "https://json-schema.org/draft/2020-12/schema");

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
