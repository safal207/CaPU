import assert from "node:assert/strict";
import { InMemoryStorage, ReferenceCaPU } from "../src/reference-runtime.mjs";

const capu = new ReferenceCaPU({
  storage: new InMemoryStorage({ failCauseIds: ["t-commit-fail"] })
});

const accept = capu.submit({
  envelope: {
    cause_id: "t-accept",
    received_at: "2025-12-31T19:00:00Z",
    source: "test",
    correlation_id: "corr-accept",
    ttl_ms: 60000
  },
  vcml_record: {
    cause_id: "t-accept",
    intent: "allocate_compute",
    params: { units: 4 },
    thread_id: "thread-1"
  }
});
assert.equal(accept.decision.decision, "ACCEPT");
assert.equal(accept.commit.status, "OK");
assert.equal(accept.execution.status, "OK");
assert.equal(capu.storage.exists("t-accept"), true);

const reject = capu.submit({
  envelope: {
    cause_id: "t-reject",
    received_at: "2025-12-31T19:00:10Z",
    source: "test",
    correlation_id: "corr-reject",
    ttl_ms: 60000
  },
  vcml_record: {
    cause_id: "t-reject",
    intent: "allocate_compute",
    params: { units: 999 },
    thread_id: "thread-1"
  }
});
assert.equal(reject.decision.decision, "REJECT");
assert.equal(capu.storage.exists("t-reject"), false);

const hold = capu.submit({
  envelope: {
    cause_id: "t-hold",
    received_at: "2025-12-31T19:00:20Z",
    source: "test",
    correlation_id: "corr-hold",
    ttl_ms: 60000
  },
  vcml_record: {
    cause_id: "t-hold",
    intent: "allocate_compute",
    params: { units: 2 },
    thread_id: "thread-2",
    parent_cause_id: "t-parent"
  }
});
assert.equal(hold.decision.decision, "HOLD");

capu.submit({
  envelope: {
    cause_id: "t-parent",
    received_at: "2025-12-31T19:00:30Z",
    source: "test",
    correlation_id: "corr-parent",
    ttl_ms: 60000
  },
  vcml_record: {
    cause_id: "t-parent",
    intent: "allocate_compute",
    params: { units: 1 },
    thread_id: "thread-2"
  }
});

const matured = capu.advanceTime("2025-12-31T19:01:20Z");
assert.equal(matured.length, 1);
assert.equal(matured[0].decision.decision, "ACCEPT");
assert.equal(matured[0].commit.status, "OK");
assert.equal(capu.storage.exists("t-hold"), true);

capu.submit({
  envelope: {
    cause_id: "t-expire",
    received_at: "2025-12-31T19:02:00Z",
    source: "test",
    correlation_id: "corr-expire",
    ttl_ms: 15000
  },
  vcml_record: {
    cause_id: "t-expire",
    intent: "await_quorum",
    params: { quorum: 3 },
    thread_id: "thread-3"
  }
});
const expired = capu.advanceTime("2025-12-31T19:02:15Z");
assert.equal(expired.length, 1);
assert.equal(expired[0].decision.decision, "EXPIRE");

const quorumHold = capu.submit({
  envelope: {
    cause_id: "t-quorum-release",
    received_at: "2025-12-31T19:02:20Z",
    source: "test",
    correlation_id: "corr-quorum-release",
    ttl_ms: 30000
  },
  vcml_record: {
    cause_id: "t-quorum-release",
    intent: "await_quorum",
    params: { quorum: 3 },
    thread_id: "thread-3b"
  }
});
assert.equal(quorumHold.decision.decision, "HOLD");
assert.equal(capu.updateHeldCause("t-quorum-release", (held) => { held.vcml_record.params.quorum_met = true; }), true);
const quorumRelease = capu.advanceTime("2025-12-31T19:02:25Z");
assert.equal(quorumRelease.length, 1);
assert.equal(quorumRelease[0].decision.decision, "ACCEPT");
assert.equal(quorumRelease[0].commit.status, "OK");

const executeFail = capu.submit({
  envelope: {
    cause_id: "t-fail",
    received_at: "2025-12-31T19:03:00Z",
    source: "test",
    correlation_id: "corr-fail",
    ttl_ms: 60000
  },
  vcml_record: {
    cause_id: "t-fail",
    intent: "dispatch_webhook",
    params: { url: "https://example.invalid/hook" },
    thread_id: "thread-4"
  }
});
assert.equal(executeFail.decision.decision, "ACCEPT");
assert.equal(executeFail.commit.status, "OK");
assert.equal(executeFail.execution.status, "FAIL");

const commitFail = capu.submit({
  envelope: {
    cause_id: "t-commit-fail",
    received_at: "2025-12-31T19:04:00Z",
    source: "test",
    correlation_id: "corr-commit-fail",
    ttl_ms: 60000
  },
  vcml_record: {
    cause_id: "t-commit-fail",
    intent: "allocate_compute",
    params: { units: 8 },
    thread_id: "thread-5"
  }
});
assert.equal(commitFail.decision.decision, "ACCEPT");
assert.equal(commitFail.commit.status, "FAIL");
assert.equal(capu.storage.exists("t-commit-fail"), false);
assert.equal("execution" in commitFail, false);

const eventTypes = capu.traceSink.events.map((event) => event.event_type);
assert.equal(eventTypes.includes("gate.accept"), true);
assert.equal(eventTypes.includes("gate.reject"), true);
assert.equal(eventTypes.includes("gate.hold"), true);
assert.equal(eventTypes.includes("incubator.release"), true);
assert.equal(eventTypes.includes("incubator.expire"), true);
assert.equal(eventTypes.includes("commit.ok"), true);
assert.equal(eventTypes.includes("commit.fail"), true);
assert.equal(eventTypes.includes("execute.ok"), true);
assert.equal(eventTypes.includes("execute.fail"), true);

const commitFailIndex = eventTypes.lastIndexOf("commit.fail");
assert.notEqual(commitFailIndex, -1);
assert.equal(eventTypes.slice(commitFailIndex + 1).includes("execute.fail"), false);
assert.equal(eventTypes.slice(commitFailIndex + 1).includes("execute.ok"), false);

console.log("reference runtime checks passed");
