import { addMs, clone, toIso } from "./utils.mjs";
import { InMemoryExecutor } from "./executor.mjs";
import { InMemoryStorage } from "./storage.mjs";
import { InMemoryTraceSink } from "./trace-sink.mjs";

export class ReferenceCaPU {
  constructor({ storage = new InMemoryStorage(), executor = new InMemoryExecutor(), traceSink = new InMemoryTraceSink() } = {}) {
    this.storage = storage;
    this.executor = executor;
    this.traceSink = traceSink;
    this.heldCauses = new Map();
  }

  submit({ envelope, vcml_record }) {
    const decision = this.#gate({ envelope, vcml_record });
    const causeId = envelope?.cause_id || vcml_record?.cause_id || "unknown";
    const correlationId = envelope?.correlation_id;
    const baseTimestamp = envelope?.received_at || new Date().toISOString();

    if (decision.decision === "REJECT") {
      this.#emitTrace({
        timestamp: baseTimestamp,
        causeId,
        correlationId,
        event_type: "gate.reject",
        details: {
          decision: "REJECT",
          reason_code: decision.reason_code,
          state_from: "VALIDATING",
          state_to: "REJECTED",
          latency_ms: 1
        }
      });

      return { ack: this.#ack(causeId, correlationId), decision };
    }

    if (decision.decision === "HOLD") {
      this.heldCauses.set(causeId, {
        envelope: clone(envelope),
        vcml_record: clone(vcml_record),
        next_check_at: decision.next_check_at,
        expire_at: addMs(baseTimestamp, envelope?.ttl_ms ?? 60000)
      });

      this.#emitTrace({
        timestamp: baseTimestamp,
        causeId,
        correlationId,
        event_type: "gate.hold",
        details: {
          decision: "HOLD",
          reason_code: decision.reason_code,
          state_from: "VALIDATING",
          state_to: "HELD",
          latency_ms: 1
        }
      });

      return { ack: this.#ack(causeId, correlationId), decision };
    }

    return {
      ack: this.#ack(causeId, correlationId),
      decision,
      ...this.#commitAndExecute({
        envelope,
        vcml_record,
        acceptedAt: baseTimestamp,
        acceptedEvent: "gate.accept",
        acceptedStateFrom: "VALIDATING"
      })
    };
  }

  advanceTime(nowIso) {
    const matured = [];
    const expired = [];

    for (const [causeId, held] of this.heldCauses.entries()) {
      const evaluation = this.#evaluateHeld(held, nowIso);
      if (evaluation === "release") matured.push([causeId, held]);
      if (evaluation === "expire") expired.push([causeId, held]);
    }

    const results = [];

    for (const [causeId, held] of matured) {
      this.heldCauses.delete(causeId);
      const decision = {
        decision: "ACCEPT",
        reason_code: "PERMIT_OK",
        explain: "preconditions satisfied"
      };
      this.#emitTrace({
        timestamp: nowIso,
        causeId,
        correlationId: held.envelope.correlation_id,
        event_type: "incubator.release",
        details: {
          decision: "ACCEPT",
          reason_code: decision.reason_code,
          state_from: "HELD",
          state_to: "ACCEPTED",
          latency_ms: new Date(nowIso).getTime() - new Date(held.envelope.received_at).getTime()
        }
      });
      results.push({
        cause_id: causeId,
        decision,
        ...this.#commitAndExecute({
          envelope: held.envelope,
          vcml_record: held.vcml_record,
          acceptedAt: nowIso,
          acceptedEvent: null,
          acceptedStateFrom: "HELD"
        })
      });
    }

    for (const [causeId, held] of expired) {
      this.heldCauses.delete(causeId);
      const decision = {
        decision: "EXPIRE",
        reason_code: "TTL_EXPIRED",
        explain: "held cause exceeded ttl"
      };
      this.#emitTrace({
        timestamp: nowIso,
        causeId,
        correlationId: held.envelope.correlation_id,
        event_type: "incubator.expire",
        details: {
          decision: "EXPIRE",
          reason_code: decision.reason_code,
          state_from: "HELD",
          state_to: "EXPIRED",
          latency_ms: new Date(nowIso).getTime() - new Date(held.envelope.received_at).getTime()
        }
      });
      results.push({ cause_id: causeId, decision });
    }

    return results;
  }

  #ack(causeId, correlationId) {
    return {
      accepted_for_validation: true,
      cause_id: causeId,
      ...(correlationId ? { correlation_id: correlationId } : {})
    };
  }

  #gate({ envelope, vcml_record }) {
    const causeId = vcml_record?.cause_id;
    if (!causeId || !envelope?.cause_id || envelope.cause_id !== causeId) {
      return {
        decision: "REJECT",
        reason_code: "REJECT_INVALID_CAUSE",
        explain: "envelope and vcml cause_id must match"
      };
    }

    const intent = vcml_record.intent;
    if (intent === "allocate_compute" && Number(vcml_record.params?.units || 0) > 100) {
      return {
        decision: "REJECT",
        reason_code: "REJECT_CAPACITY_LIMIT",
        explain: "capacity exceeded"
      };
    }

    if (vcml_record.parent_cause_id && !this.storage.exists(vcml_record.parent_cause_id)) {
      return {
        decision: "HOLD",
        reason_code: "DEFER_PENDING_CONTEXT",
        explain: "waiting for parent cause",
        next_check_at: addMs(envelope.received_at, envelope.ttl_ms ?? 60000)
      };
    }

    if (intent === "await_quorum" && vcml_record.params?.quorum_met !== true) {
      return {
        decision: "HOLD",
        reason_code: "DEFER_PENDING_CONTEXT",
        explain: "quorum not reached",
        next_check_at: addMs(envelope.received_at, envelope.ttl_ms ?? 60000)
      };
    }

    return {
      decision: "ACCEPT",
      reason_code: "PERMIT_OK",
      explain: "cause permitted"
    };
  }

  #evaluateHeld(held, nowIso) {
    if (new Date(nowIso).getTime() >= new Date(held.expire_at).getTime()) {
      if (held.vcml_record.parent_cause_id && this.storage.exists(held.vcml_record.parent_cause_id)) {
        return "release";
      }
      if (held.vcml_record.intent === "await_quorum" && held.vcml_record.params?.quorum_met === true) {
        return "release";
      }
      return "expire";
    }

    if (held.vcml_record.parent_cause_id && this.storage.exists(held.vcml_record.parent_cause_id)) {
      return "release";
    }
    if (held.vcml_record.intent === "await_quorum" && held.vcml_record.params?.quorum_met === true) {
      return "release";
    }

    return "hold";
  }

  #buildEffectPlan(vcml_record) {
    if (vcml_record.intent === "allocate_compute") {
      return {
        effect_type: "allocate",
        target: "compute_pool",
        parameters: { units: vcml_record.params?.units ?? 1 },
        idempotency_key: `idem-${vcml_record.cause_id}`,
        safety: { dry_run_allowed: true, max_retries: 3 }
      };
    }

    if (vcml_record.intent === "dispatch_webhook") {
      return {
        effect_type: "dispatch",
        target: "webhook",
        parameters: { url: vcml_record.params?.url },
        idempotency_key: `idem-${vcml_record.cause_id}`,
        safety: { dry_run_allowed: false, max_retries: 1 }
      };
    }

    return {
      effect_type: vcml_record.intent || "noop",
      target: "local",
      parameters: { ...vcml_record.params },
      idempotency_key: `idem-${vcml_record.cause_id}`,
      safety: { dry_run_allowed: true, max_retries: 0 }
    };
  }

  #commitAndExecute({ envelope, vcml_record, acceptedAt, acceptedEvent, acceptedStateFrom }) {
    const causeId = envelope.cause_id;
    const correlationId = envelope.correlation_id;

    if (acceptedEvent) {
      this.#emitTrace({
        timestamp: acceptedAt,
        causeId,
        correlationId,
        event_type: acceptedEvent,
        details: {
          decision: "ACCEPT",
          reason_code: "PERMIT_OK",
          state_from: acceptedStateFrom,
          state_to: "ACCEPTED",
          latency_ms: 1
        }
      });
    }

    try {
      const commitId = this.storage.commit(vcml_record);
      this.#emitTrace({
        timestamp: toIso(new Date(acceptedAt).getTime() + 1),
        causeId,
        correlationId,
        event_type: "commit.ok",
        details: {
          state_from: "ACCEPTED",
          state_to: "COMMITTED",
          latency_ms: 1
        }
      });

      const effect_plan = this.#buildEffectPlan(vcml_record);
      const execution = this.executor.execute(effect_plan);
      const executeTimestamp = toIso(new Date(acceptedAt).getTime() + 2);
      this.#emitTrace({
        timestamp: executeTimestamp,
        causeId,
        correlationId,
        event_type: execution.status === "OK" ? "execute.ok" : "execute.fail",
        details: {
          reason_code: execution.reason_code,
          state_from: "COMMITTED",
          state_to: "EXECUTED",
          latency_ms: 1
        }
      });

      return {
        commit: { status: "OK", cause_id: commitId },
        effect_plan,
        execution
      };
    } catch (error) {
      this.#emitTrace({
        timestamp: toIso(new Date(acceptedAt).getTime() + 1),
        causeId,
        correlationId,
        event_type: "commit.fail",
        details: {
          decision: "REJECT",
          reason_code: "ABORT_INTERNAL_ERROR",
          state_from: "ACCEPTED",
          state_to: "REJECTED",
          latency_ms: 1
        }
      });

      return {
        commit: {
          status: "FAIL",
          reason_code: "ABORT_INTERNAL_ERROR",
          explain: String(error?.message || error)
        }
      };
    }
  }

  #emitTrace({ timestamp, causeId, correlationId, event_type, details }) {
    this.traceSink.emit({
      timestamp,
      cause_id: causeId,
      ...(correlationId ? { correlation_id: correlationId } : {}),
      component: "CaPU",
      event_type,
      details
    });
  }
}
