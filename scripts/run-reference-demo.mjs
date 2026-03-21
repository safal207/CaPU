import { InMemoryStorage, ReferenceCaPU } from "../src/reference-runtime.mjs";

const capu = new ReferenceCaPU({
  storage: new InMemoryStorage({ failCauseIds: ["c-006"] })
});

const scenarios = [
  {
    envelope: {
      cause_id: "c-001",
      received_at: "2025-12-31T18:00:00Z",
      source: "demo",
      correlation_id: "corr-001",
      ttl_ms: 60000
    },
    vcml_record: {
      cause_id: "c-001",
      intent: "allocate_compute",
      params: { units: 4 },
      thread_id: "t-42"
    }
  },
  {
    envelope: {
      cause_id: "c-002",
      received_at: "2025-12-31T18:00:10Z",
      source: "demo",
      correlation_id: "corr-002",
      ttl_ms: 60000
    },
    vcml_record: {
      cause_id: "c-002",
      intent: "allocate_compute",
      params: { units: 999 },
      thread_id: "t-42"
    }
  },
  {
    envelope: {
      cause_id: "c-003",
      received_at: "2025-12-31T18:00:20Z",
      source: "demo",
      correlation_id: "corr-003",
      ttl_ms: 60000
    },
    vcml_record: {
      cause_id: "c-003",
      intent: "allocate_compute",
      params: { units: 2 },
      thread_id: "t-43",
      parent_cause_id: "c-parent"
    }
  },
  {
    envelope: {
      cause_id: "c-004",
      received_at: "2025-12-31T18:02:00Z",
      source: "demo",
      correlation_id: "corr-004",
      ttl_ms: 15000
    },
    vcml_record: {
      cause_id: "c-004",
      intent: "await_quorum",
      params: { quorum: 3 },
      thread_id: "t-44"
    }
  },
  {
    envelope: {
      cause_id: "c-005",
      received_at: "2025-12-31T18:03:00Z",
      source: "demo",
      correlation_id: "corr-005",
      ttl_ms: 60000
    },
    vcml_record: {
      cause_id: "c-005",
      intent: "dispatch_webhook",
      params: { url: "https://example.invalid/hook" },
      thread_id: "t-45"
    }
  },
  {
    envelope: {
      cause_id: "c-006",
      received_at: "2025-12-31T18:04:00Z",
      source: "demo",
      correlation_id: "corr-006",
      ttl_ms: 60000
    },
    vcml_record: {
      cause_id: "c-006",
      intent: "allocate_compute",
      params: { units: 8 },
      thread_id: "t-46"
    }
  },
  {
    envelope: {
      cause_id: "c-007",
      received_at: "2025-12-31T18:05:00Z",
      source: "demo",
      correlation_id: "corr-007",
      ttl_ms: 30000
    },
    vcml_record: {
      cause_id: "c-007",
      intent: "await_quorum",
      params: { quorum: 3 },
      thread_id: "t-47"
    }
  }
];

const results = scenarios.map((scenario) => capu.submit(scenario));

capu.submit({
  envelope: {
    cause_id: "c-parent",
    received_at: "2025-12-31T18:00:30Z",
    source: "demo",
    correlation_id: "corr-parent",
    ttl_ms: 60000
  },
  vcml_record: {
    cause_id: "c-parent",
    intent: "allocate_compute",
    params: { units: 1 },
    thread_id: "t-43"
  }
});

const holdRelease = capu.advanceTime("2025-12-31T18:01:20Z");
capu.updateHeldCause("c-007", (held) => {
  held.vcml_record.params.quorum_met = true;
});
const quorumRelease = capu.advanceTime("2025-12-31T18:05:10Z");
const expirations = capu.advanceTime("2025-12-31T18:02:15Z");

console.log("# Decisions");
for (const result of results) {
  console.log(JSON.stringify(result));
}

console.log("# Matured / Expired");
for (const result of [...holdRelease, ...quorumRelease, ...expirations]) {
  console.log(JSON.stringify(result));
}

console.log("# Trace JSONL");
console.log(capu.traceSink.toJsonl());
