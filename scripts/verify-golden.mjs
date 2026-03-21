import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { InMemoryStorage, ReferenceCaPU } from "../src/reference-runtime.mjs";

const ROOT = process.cwd();
const GOLDEN_FLOW = path.resolve(ROOT, "examples/golden_flow.jsonl");

function readGoldenRecords() {
  const lines = fs.readFileSync(GOLDEN_FLOW, "utf8").split(/\r?\n/);
  const records = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    records.push(JSON.parse(trimmed));
  }
  return records;
}

function splitScenarios(records) {
  const scenarios = [];
  let current = null;
  for (const record of records) {
    if (record.submit) {
      if (current) scenarios.push(current);
      current = { submit: record.submit, records: [] };
      continue;
    }
    if (!current) {
      throw new Error("golden flow must start each scenario with submit");
    }
    current.records.push(record);
  }
  if (current) scenarios.push(current);
  return scenarios;
}

function normalizeDateTime(value) {
  return new Date(value).toISOString();
}

function normalizeDecision(decision) {
  return {
    decision: decision.decision,
    reason_code: decision.reason_code,
    ...(decision.next_check_at ? { next_check_at: normalizeDateTime(decision.next_check_at) } : {})
  };
}

function normalizeEffectPlan(effectPlan) {
  return JSON.parse(JSON.stringify(effectPlan));
}

function normalizeTraceEvent(traceEvent) {
  return {
    cause_id: traceEvent.cause_id,
    correlation_id: traceEvent.correlation_id,
    component: traceEvent.component,
    event_type: traceEvent.event_type,
    details: {
      ...(traceEvent.details?.decision ? { decision: traceEvent.details.decision } : {}),
      ...(traceEvent.details?.reason_code ? { reason_code: traceEvent.details.reason_code } : {}),
      ...(traceEvent.details?.state_from ? { state_from: traceEvent.details.state_from } : {}),
      ...(traceEvent.details?.state_to ? { state_to: traceEvent.details.state_to } : {})
    }
  };
}

function syntheticParentSubmit(parentCauseId, timestamp, correlationId) {
  return {
    envelope: {
      cause_id: parentCauseId,
      received_at: timestamp,
      source: "golden-verify",
      correlation_id: correlationId,
      ttl_ms: 60000
    },
    vcml_record: {
      cause_id: parentCauseId,
      intent: "allocate_compute",
      params: { units: 1 },
      thread_id: "golden-parent"
    }
  };
}

function assertDeepEqual(actual, expected, label) {
  assert.deepEqual(actual, expected, `${label}\nactual: ${JSON.stringify(actual, null, 2)}\nexpected: ${JSON.stringify(expected, null, 2)}`);
}

function expectedTraces(records) {
  return records.filter((record) => record.trace_event).map((record) => normalizeTraceEvent(record.trace_event));
}

function expectedInitialDecision(records) {
  const decisionRecord = records.find((record) => record.decision);
  return decisionRecord ? normalizeDecision(decisionRecord.decision) : null;
}

function expectedInitialEffectPlan(records) {
  const firstDecision = expectedInitialDecision(records);
  if (firstDecision?.decision === "HOLD") return null;
  const effectPlanRecord = records.find((record) => record.effect_plan);
  return effectPlanRecord ? normalizeEffectPlan(effectPlanRecord.effect_plan) : null;
}

function expectedFollowUpDecision(records) {
  const decisions = records.filter((record) => record.decision);
  return decisions[1] ? normalizeDecision(decisions[1].decision) : null;
}

function expectedFollowUpEffectPlan(records) {
  const firstDecision = expectedInitialDecision(records);
  const effectPlans = records.filter((record) => record.effect_plan);
  if (firstDecision?.decision === "HOLD") {
    return effectPlans[0] ? normalizeEffectPlan(effectPlans[0].effect_plan) : null;
  }
  return effectPlans[1] ? normalizeEffectPlan(effectPlans[1].effect_plan) : null;
}

function nextEvaluationTimestamp(records) {
  const trace = records.find((record) => record.trace_event?.event_type === "incubator.release" || record.trace_event?.event_type === "incubator.expire");
  return trace?.trace_event?.timestamp;
}

async function main() {
  const capu = new ReferenceCaPU({
    storage: new InMemoryStorage({ failCauseIds: ["c-006"] })
  });

  const scenarios = splitScenarios(readGoldenRecords());

  for (const scenario of scenarios) {
    const causeId = scenario.submit.envelope.cause_id;
    const traceStart = capu.traceSink.events.length;
    const result = capu.submit(scenario.submit);
    const actualInitialDecision = normalizeDecision(result.decision);
    const expectedDecision = expectedInitialDecision(scenario.records);
    assertDeepEqual(actualInitialDecision, expectedDecision, `${causeId}: initial decision mismatch`);

    const expectedEffectPlan = expectedInitialEffectPlan(scenario.records);
    if (expectedEffectPlan) {
      assert.ok(result.effect_plan, `${causeId}: missing initial effect plan`);
      assertDeepEqual(normalizeEffectPlan(result.effect_plan), expectedEffectPlan, `${causeId}: initial effect plan mismatch`);
    } else {
      assert.equal("effect_plan" in result, false, `${causeId}: unexpected initial effect plan`);
    }

    if (expectedDecision?.decision === "HOLD") {
      if (scenario.submit.vcml_record.parent_cause_id) {
        capu.submit(
          syntheticParentSubmit(
            scenario.submit.vcml_record.parent_cause_id,
            scenario.submit.envelope.received_at,
            `${scenario.submit.envelope.correlation_id}-parent`
          )
        );
      }

      if (scenario.submit.vcml_record.intent === "await_quorum" && expectedFollowUpDecision(scenario.records)?.decision === "ACCEPT") {
        capu.updateHeldCause(causeId, (held) => {
          held.vcml_record.params.quorum_met = true;
        });
      }

      const followUpTimestamp = nextEvaluationTimestamp(scenario.records);
      assert.ok(followUpTimestamp, `${causeId}: missing follow-up evaluation timestamp`);
      const followUpResults = capu.advanceTime(followUpTimestamp);
      const followUp = followUpResults.find((entry) => entry.cause_id === causeId);
      assert.ok(followUp, `${causeId}: missing held follow-up result`);
      assertDeepEqual(normalizeDecision(followUp.decision), expectedFollowUpDecision(scenario.records), `${causeId}: follow-up decision mismatch`);

      const expectedFollowUpPlan = expectedFollowUpEffectPlan(scenario.records);
      if (expectedFollowUpPlan) {
        assert.ok(followUp.effect_plan, `${causeId}: missing follow-up effect plan`);
        assertDeepEqual(normalizeEffectPlan(followUp.effect_plan), expectedFollowUpPlan, `${causeId}: follow-up effect plan mismatch`);
      }
    }

    const actualTraces = capu.traceSink.events.slice(traceStart)
      .filter((trace) => trace.cause_id === causeId)
      .map(normalizeTraceEvent);
    assertDeepEqual(actualTraces, expectedTraces(scenario.records), `${causeId}: trace mismatch`);
  }

  console.log("golden fixture verification passed");
}

main().catch((error) => {
  console.error(error?.stack || error);
  process.exit(1);
});
