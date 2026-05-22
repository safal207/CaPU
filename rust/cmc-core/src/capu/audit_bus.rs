use crate::CauseId;

use super::transition::{DecisionClass, Transition, TransitionType, UnitDecision};

/// Audit-shaped record emitted by the CaPU software reference pipeline.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuditRecord {
    pub transition_id: String,
    pub transition_type: &'static str,
    pub action_kind: Option<String>,
    pub decision_class: &'static str,
    pub code: &'static str,
    pub invariant_id: &'static str,
    pub boundary: &'static str,
    pub verdict: &'static str,
    pub cause_id: Option<CauseId>,
}

impl AuditRecord {
    pub fn to_json_line(&self) -> String {
        format!(
            "{{\"transition_id\":{},\"transition_type\":\"{}\",\"action_kind\":{},\"decision_class\":\"{}\",\"code\":\"{}\",\"invariant_id\":\"{}\",\"boundary\":\"{}\",\"verdict\":\"{}\",\"cause_id\":{}}}",
            json_string(&self.transition_id),
            self.transition_type,
            json_opt_string(self.action_kind.as_deref()),
            self.decision_class,
            self.code,
            self.invariant_id,
            self.boundary,
            self.verdict,
            json_opt_u64(self.cause_id)
        )
    }
}

/// Emit a stable audit record for a transition decision.
pub fn emit_audit_record(transition: &Transition, decision: &UnitDecision) -> AuditRecord {
    AuditRecord {
        transition_id: transition.transition_id.clone(),
        transition_type: transition_type_name(transition.transition_type),
        action_kind: transition.action_kind.clone(),
        decision_class: decision_class_name(decision.class),
        code: decision.code,
        invariant_id: decision.invariant_id,
        boundary: decision.boundary.as_str(),
        verdict: decision.verdict,
        cause_id: decision.cause_id,
    }
}

fn transition_type_name(transition_type: TransitionType) -> &'static str {
    match transition_type {
        TransitionType::MemoryWrite => "memory_write",
        TransitionType::MemoryRead => "memory_read",
        TransitionType::Effect => "effect",
        TransitionType::PersonaMemory => "persona_memory",
        TransitionType::PersonaStateChange => "persona_state_change",
        TransitionType::ExternalAction => "external_action",
        TransitionType::Introspection => "introspection",
    }
}

fn decision_class_name(class: DecisionClass) -> &'static str {
    match class {
        DecisionClass::Accept => "accept",
        DecisionClass::Reject => "reject",
        DecisionClass::Hold => "hold",
    }
}

fn json_opt_u64(value: Option<u64>) -> String {
    value.map_or_else(|| "null".to_string(), |value| value.to_string())
}

fn json_opt_string(value: Option<&str>) -> String {
    value.map_or_else(|| "null".to_string(), json_string)
}

fn json_string(value: &str) -> String {
    format!("\"{}\"", escape_json(value))
}

fn escape_json(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capu::decision_unit::decide_transition;
    use crate::capu::decoder::{decode_external_action, ExternalActionRequest};

    #[test]
    fn audit_bus_emits_rejected_p6_record() {
        let transition = decode_external_action(ExternalActionRequest::new(
            "tx-uncommitted",
            "send_email",
            None,
            false,
        ));
        let decision = decide_transition(&transition);
        let record = emit_audit_record(&transition, &decision);

        assert_eq!(record.transition_id, "tx-uncommitted");
        assert_eq!(record.transition_type, "external_action");
        assert_eq!(record.action_kind.as_deref(), Some("send_email"));
        assert_eq!(record.decision_class, "reject");
        assert_eq!(record.code, "REJECT_ACTION_WITHOUT_COMMIT");
        assert_eq!(record.invariant_id, "P6");
        assert_eq!(record.boundary, "action_requires_commit");
        assert_eq!(record.verdict, "blocked_action_without_commit");
        assert_eq!(record.cause_id, None);
    }

    #[test]
    fn audit_bus_emits_accepted_p6_record_jsonl() {
        let transition = decode_external_action(ExternalActionRequest::new(
            "tx-committed",
            "send_email",
            Some(101),
            true,
        ));
        let decision = decide_transition(&transition);
        let record = emit_audit_record(&transition, &decision);
        let jsonl = record.to_json_line();

        assert!(jsonl.contains("\"transition_id\":\"tx-committed\""));
        assert!(jsonl.contains("\"transition_type\":\"external_action\""));
        assert!(jsonl.contains("\"action_kind\":\"send_email\""));
        assert!(jsonl.contains("\"decision_class\":\"accept\""));
        assert!(jsonl.contains("\"code\":\"ACCEPT_COMMITTED_ACTION\""));
        assert!(jsonl.contains("\"invariant_id\":\"P6\""));
        assert!(jsonl.contains("\"boundary\":\"action_requires_commit\""));
        assert!(jsonl.contains("\"verdict\":\"accepted_committed_action\""));
        assert!(jsonl.contains("\"cause_id\":101"));
    }
}
