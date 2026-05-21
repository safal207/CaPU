pub mod capu;
pub mod trace_crypto;

use std::collections::{HashMap, HashSet};

pub type Address = u64;
pub type ActorId = u32;
pub type CauseId = u64;
pub type EffectId = u64;
pub type ValueHash = [u8; 32];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DecisionCode {
    AcceptWrite,
    AcceptRead,
    AcceptEffect,
    RejectMissingCause,
    RejectUnknownCause,
    RejectEffectBeforeCommit,
}

impl DecisionCode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::AcceptWrite => "ACCEPT_WRITE",
            Self::AcceptRead => "ACCEPT_READ",
            Self::AcceptEffect => "ACCEPT_EFFECT",
            Self::RejectMissingCause => "REJECT_MISSING_CAUSE",
            Self::RejectUnknownCause => "REJECT_UNKNOWN_CAUSE",
            Self::RejectEffectBeforeCommit => "REJECT_EFFECT_BEFORE_COMMIT",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Decision {
    pub code: DecisionCode,
    pub cause_id: Option<CauseId>,
    pub message: &'static str,
}

impl Decision {
    pub fn accepted(&self) -> bool {
        matches!(
            self.code,
            DecisionCode::AcceptWrite | DecisionCode::AcceptRead | DecisionCode::AcceptEffect
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TraceEventKind {
    Write,
    Read,
    Effect,
}

impl TraceEventKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Write => "WRITE",
            Self::Read => "READ",
            Self::Effect => "EFFECT",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TraceEvent {
    pub seq: u64,
    pub kind: TraceEventKind,
    pub decision: DecisionCode,
    pub address: Option<Address>,
    pub effect_id: Option<EffectId>,
    pub cause_id: Option<CauseId>,
    pub message: &'static str,
}

impl TraceEvent {
    pub fn to_json_line(&self) -> String {
        format!(
            "{{\"seq\":{},\"kind\":\"{}\",\"decision\":\"{}\",\"address\":{},\"effect_id\":{},\"cause_id\":{},\"message\":\"{}\"}}",
            self.seq,
            self.kind.as_str(),
            self.decision.as_str(),
            opt(self.address),
            opt(self.effect_id),
            opt(self.cause_id),
            self.message.replace('\\', "\\\\").replace('"', "\\\"")
        )
    }
}

fn opt(v: Option<u64>) -> String {
    v.map_or_else(|| "null".to_string(), |x| x.to_string())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CauseRecord {
    pub id: CauseId,
    pub parent: Option<CauseId>,
    pub committed: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CausalMemoryEntry {
    pub address: Address,
    pub value_hash: ValueHash,
    pub writer: ActorId,
    pub cause_id: CauseId,
    pub parent_cause: Option<CauseId>,
    pub timestamp: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EffectRecord {
    pub effect_id: EffectId,
    pub parent_cause: CauseId,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuditFinding {
    pub code: &'static str,
    pub message: &'static str,
    pub cause_id: Option<CauseId>,
    pub address: Option<Address>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuditReport {
    pub entries: usize,
    pub effects: usize,
    pub findings: Vec<AuditFinding>,
}

#[derive(Debug, Default)]
pub struct CausalMemoryController {
    causes: HashMap<CauseId, CauseRecord>,
    memory: HashMap<Address, CausalMemoryEntry>,
    effects: Vec<EffectRecord>,
    trace: Vec<TraceEvent>,
    clock: u64,
    trace_seq: u64,
}

impl CausalMemoryController {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_cause(&mut self, id: CauseId, parent: Option<CauseId>, committed: bool) {
        self.causes.insert(
            id,
            CauseRecord {
                id,
                parent,
                committed,
            },
        );
    }

    pub fn commit_cause(&mut self, id: CauseId) -> bool {
        self.causes
            .get_mut(&id)
            .map(|cause| {
                cause.committed = true;
                true
            })
            .unwrap_or(false)
    }

    pub fn trace_events(&self) -> &[TraceEvent] {
        &self.trace
    }

    pub fn trace_jsonl(&self) -> String {
        let mut trace = self
            .trace
            .iter()
            .map(TraceEvent::to_json_line)
            .collect::<Vec<_>>()
            .join("\n");
        if !trace.is_empty() {
            trace.push('\n');
        }
        trace
    }

    fn emit(
        &mut self,
        kind: TraceEventKind,
        decision: &Decision,
        address: Option<Address>,
        effect_id: Option<EffectId>,
    ) {
        self.trace_seq += 1;
        self.trace.push(TraceEvent {
            seq: self.trace_seq,
            kind,
            decision: decision.code,
            address,
            effect_id,
            cause_id: decision.cause_id,
            message: decision.message,
        });
    }

    pub fn write(
        &mut self,
        address: Address,
        value_hash: ValueHash,
        writer: ActorId,
        cause_id: Option<CauseId>,
    ) -> Decision {
        let Some(cid) = cause_id else {
            let decision = Decision {
                code: DecisionCode::RejectMissingCause,
                cause_id: None,
                message: "memory write requires an explicit cause",
            };
            self.emit(TraceEventKind::Write, &decision, Some(address), None);
            return decision;
        };

        let Some(cause) = self.causes.get(&cid) else {
            let decision = Decision {
                code: DecisionCode::RejectUnknownCause,
                cause_id: Some(cid),
                message: "memory write references an unknown cause",
            };
            self.emit(TraceEventKind::Write, &decision, Some(address), None);
            return decision;
        };

        let parent_cause = cause.parent;
        self.clock += 1;
        self.memory.insert(
            address,
            CausalMemoryEntry {
                address,
                value_hash,
                writer,
                cause_id: cid,
                parent_cause,
                timestamp: self.clock,
            },
        );

        let decision = Decision {
            code: DecisionCode::AcceptWrite,
            cause_id: Some(cid),
            message: "causal memory write accepted",
        };
        self.emit(TraceEventKind::Write, &decision, Some(address), None);
        decision
    }

    pub fn read(
        &mut self,
        address: Address,
        _requester: ActorId,
        cause_id: Option<CauseId>,
    ) -> Decision {
        let Some(cid) = cause_id else {
            let decision = Decision {
                code: DecisionCode::RejectMissingCause,
                cause_id: None,
                message: "memory read requires an explicit cause",
            };
            self.emit(TraceEventKind::Read, &decision, Some(address), None);
            return decision;
        };

        if !self.causes.contains_key(&cid) || !self.memory.contains_key(&address) {
            let decision = Decision {
                code: DecisionCode::RejectUnknownCause,
                cause_id: Some(cid),
                message: "memory read references an unknown cause or address",
            };
            self.emit(TraceEventKind::Read, &decision, Some(address), None);
            return decision;
        }

        let decision = Decision {
            code: DecisionCode::AcceptRead,
            cause_id: Some(cid),
            message: "causal memory read accepted",
        };
        self.emit(TraceEventKind::Read, &decision, Some(address), None);
        decision
    }

    pub fn effect(&mut self, effect_id: EffectId, parent_cause: Option<CauseId>) -> Decision {
        let Some(cid) = parent_cause else {
            let decision = Decision {
                code: DecisionCode::RejectMissingCause,
                cause_id: None,
                message: "effect requires a committed parent cause",
            };
            self.emit(TraceEventKind::Effect, &decision, None, Some(effect_id));
            return decision;
        };

        let Some(cause) = self.causes.get(&cid) else {
            let decision = Decision {
                code: DecisionCode::RejectUnknownCause,
                cause_id: Some(cid),
                message: "effect references an unknown parent cause",
            };
            self.emit(TraceEventKind::Effect, &decision, None, Some(effect_id));
            return decision;
        };

        if !cause.committed {
            let decision = Decision {
                code: DecisionCode::RejectEffectBeforeCommit,
                cause_id: Some(cid),
                message: "effect cannot execute before causal commit",
            };
            self.emit(TraceEventKind::Effect, &decision, None, Some(effect_id));
            return decision;
        }

        self.effects.push(EffectRecord {
            effect_id,
            parent_cause: cid,
        });

        let decision = Decision {
            code: DecisionCode::AcceptEffect,
            cause_id: Some(cid),
            message: "effect accepted after committed causal authorization",
        };
        self.emit(TraceEventKind::Effect, &decision, None, Some(effect_id));
        decision
    }

    pub fn reconstruct_chain(&self, cause_id: CauseId) -> Vec<CauseId> {
        let mut out = Vec::new();
        let mut seen = HashSet::new();
        let mut cur = Some(cause_id);

        while let Some(id) = cur {
            if !seen.insert(id) {
                break;
            }
            out.push(id);
            cur = self.causes.get(&id).and_then(|cause| cause.parent);
        }

        out
    }

    pub fn audit(&self) -> AuditReport {
        AuditReport {
            entries: self.memory.len(),
            effects: self.effects.len(),
            findings: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hash(byte: u8) -> ValueHash {
        [byte; 32]
    }

    #[test]
    fn valid_write_is_accepted() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(1, None, true);

        assert_eq!(
            cmc.write(0x1000, hash(7), 42, Some(1)).code,
            DecisionCode::AcceptWrite
        );
        assert_eq!(cmc.trace_events()[0].kind, TraceEventKind::Write);
    }

    #[test]
    fn missing_cause_write_is_rejected() {
        let mut cmc = CausalMemoryController::new();

        assert_eq!(
            cmc.write(0x1000, hash(7), 42, None).code,
            DecisionCode::RejectMissingCause
        );
        assert_eq!(cmc.audit().entries, 0);
    }

    #[test]
    fn unknown_cause_write_is_rejected() {
        let mut cmc = CausalMemoryController::new();

        assert_eq!(
            cmc.write(0x1000, hash(7), 42, Some(999)).code,
            DecisionCode::RejectUnknownCause
        );
    }

    #[test]
    fn effect_before_commit_is_rejected() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(7, None, false);

        assert_eq!(
            cmc.effect(99, Some(7)).code,
            DecisionCode::RejectEffectBeforeCommit
        );
    }

    #[test]
    fn committed_effect_is_accepted() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(7, None, false);

        assert!(cmc.commit_cause(7));
        assert_eq!(cmc.effect(99, Some(7)).code, DecisionCode::AcceptEffect);
    }

    #[test]
    fn read_emits_trace_event() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(1, None, true);

        assert!(cmc.write(0x2000, hash(9), 42, Some(1)).accepted());
        assert_eq!(
            cmc.read(0x2000, 43, Some(1)).code,
            DecisionCode::AcceptRead
        );
        assert_eq!(cmc.trace_events()[1].kind, TraceEventKind::Read);
    }

    #[test]
    fn trace_exports_jsonl() {
        let mut cmc = CausalMemoryController::new();
        cmc.write(0x1000, hash(7), 42, None);

        assert!(cmc
            .trace_jsonl()
            .contains("\"decision\":\"REJECT_MISSING_CAUSE\""));
    }

    #[test]
    fn memory_derived_effect_chain_is_reconstructable() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(1, None, true);
        cmc.add_cause(2, Some(1), true);

        assert_eq!(cmc.reconstruct_chain(2), vec![2, 1]);
    }

    #[test]
    fn basic_flow_matches_golden_fixture() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(1, None, true);
        cmc.add_cause(2, Some(1), false);

        let write_known = cmc.write(0x2000, hash(9), 42, Some(1));
        let write_missing = cmc.write(0x3000, hash(10), 42, None);
        let effect_before_commit = cmc.effect(500, Some(2));
        assert!(cmc.commit_cause(2));
        let effect_after_commit = cmc.effect(500, Some(2));

        let actual = format!(
            "CMC-GOLDEN basic-flow v0\nwrite_known_cause={:?} accepted={}\nwrite_missing_cause={:?} accepted={}\neffect_before_commit={:?} accepted={}\neffect_after_commit={:?} accepted={}\nchain_2={:?}\naudit.entries={}\naudit.effects={}\naudit.findings={}\ntrace.events={}\n",
            write_known.code,
            write_known.accepted(),
            write_missing.code,
            write_missing.accepted(),
            effect_before_commit.code,
            effect_before_commit.accepted(),
            effect_after_commit.code,
            effect_after_commit.accepted(),
            cmc.reconstruct_chain(2),
            cmc.audit().entries,
            cmc.audit().effects,
            cmc.audit().findings.len(),
            cmc.trace_events().len()
        );

        assert_eq!(actual, include_str!("../fixtures/basic_flow.golden.txt"));
    }
}
