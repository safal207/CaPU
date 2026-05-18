//! Causal Memory Controller (CMC) reference simulator.
//!
//! CMC-0 models a tiny causal metadata plane for memory/effect operations.
//! It is intentionally small: the goal is deterministic behavior and testable
//! invariants, not performance or hardware readiness.

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
pub struct AuditReport {
    pub entries: usize,
    pub effects: usize,
    pub findings: Vec<AuditFinding>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuditFinding {
    pub code: &'static str,
    pub message: &'static str,
    pub cause_id: Option<CauseId>,
    pub address: Option<Address>,
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
        match self.causes.get_mut(&id) {
            Some(cause) => {
                cause.committed = true;
                true
            }
            None => false,
        }
    }

    pub fn trace_events(&self) -> &[TraceEvent] {
        &self.trace
    }

    fn emit_trace(
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
        let Some(cause_id) = cause_id else {
            let decision = Decision {
                code: DecisionCode::RejectMissingCause,
                cause_id: None,
                message: "memory write requires an explicit cause",
            };
            self.emit_trace(TraceEventKind::Write, &decision, Some(address), None);
            return decision;
        };

        let Some(cause) = self.causes.get(&cause_id) else {
            let decision = Decision {
                code: DecisionCode::RejectUnknownCause,
                cause_id: Some(cause_id),
                message: "memory write references an unknown cause",
            };
            self.emit_trace(TraceEventKind::Write, &decision, Some(address), None);
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
                cause_id,
                parent_cause,
                timestamp: self.clock,
            },
        );

        let decision = Decision {
            code: DecisionCode::AcceptWrite,
            cause_id: Some(cause_id),
            message: "causal memory write accepted",
        };
        self.emit_trace(TraceEventKind::Write, &decision, Some(address), None);
        decision
    }

    pub fn read(
        &mut self,
        address: Address,
        _requester: ActorId,
        cause_id: Option<CauseId>,
    ) -> Decision {
        let Some(cause_id) = cause_id else {
            let decision = Decision {
                code: DecisionCode::RejectMissingCause,
                cause_id: None,
                message: "memory read requires an explicit cause",
            };
            self.emit_trace(TraceEventKind::Read, &decision, Some(address), None);
            return decision;
        };

        if !self.causes.contains_key(&cause_id) {
            let decision = Decision {
                code: DecisionCode::RejectUnknownCause,
                cause_id: Some(cause_id),
                message: "memory read references an unknown cause",
            };
            self.emit_trace(TraceEventKind::Read, &decision, Some(address), None);
            return decision;
        }

        if !self.memory.contains_key(&address) {
            let decision = Decision {
                code: DecisionCode::RejectUnknownCause,
                cause_id: Some(cause_id),
                message: "memory read references an unknown address",
            };
            self.emit_trace(TraceEventKind::Read, &decision, Some(address), None);
            return decision;
        }

        let decision = Decision {
            code: DecisionCode::AcceptRead,
            cause_id: Some(cause_id),
            message: "causal memory read accepted",
        };
        self.emit_trace(TraceEventKind::Read, &decision, Some(address), None);
        decision
    }

    pub fn effect(&mut self, effect_id: EffectId, parent_cause: Option<CauseId>) -> Decision {
        let Some(parent_cause) = parent_cause else {
            let decision = Decision {
                code: DecisionCode::RejectMissingCause,
                cause_id: None,
                message: "effect requires a committed parent cause",
            };
            self.emit_trace(TraceEventKind::Effect, &decision, None, Some(effect_id));
            return decision;
        };

        let Some(cause) = self.causes.get(&parent_cause) else {
            let decision = Decision {
                code: DecisionCode::RejectUnknownCause,
                cause_id: Some(parent_cause),
                message: "effect references an unknown parent cause",
            };
            self.emit_trace(TraceEventKind::Effect, &decision, None, Some(effect_id));
            return decision;
        };

        if !cause.committed {
            let decision = Decision {
                code: DecisionCode::RejectEffectBeforeCommit,
                cause_id: Some(parent_cause),
                message: "effect cannot execute before causal commit",
            };
            self.emit_trace(TraceEventKind::Effect, &decision, None, Some(effect_id));
            return decision;
        }

        self.effects.push(EffectRecord {
            effect_id,
            parent_cause,
        });

        let decision = Decision {
            code: DecisionCode::AcceptEffect,
            cause_id: Some(parent_cause),
            message: "effect accepted after committed causal authorization",
        };
        self.emit_trace(TraceEventKind::Effect, &decision, None, Some(effect_id));
        decision
    }

    pub fn reconstruct_chain(&self, cause_id: CauseId) -> Vec<CauseId> {
        let mut chain = Vec::new();
        let mut seen = HashSet::new();
        let mut current = Some(cause_id);

        while let Some(id) = current {
            if !seen.insert(id) {
                break;
            }
            chain.push(id);
            current = self.causes.get(&id).and_then(|cause| cause.parent);
        }

        chain
    }

    pub fn audit(&self) -> AuditReport {
        let mut findings = Vec::new();

        for entry in self.memory.values() {
            if !self.causes.contains_key(&entry.cause_id) {
                findings.push(AuditFinding {
                    code: "CMC-AUDIT-MISSING_WRITE_CAUSE",
                    message: "memory entry references a missing cause",
                    cause_id: Some(entry.cause_id),
                    address: Some(entry.address),
                });
            }
        }

        for effect in &self.effects {
            match self.causes.get(&effect.parent_cause) {
                Some(cause) if cause.committed => {}
                Some(_) => findings.push(AuditFinding {
                    code: "CMC-AUDIT-EFFECT_BEFORE_COMMIT",
                    message: "effect references an uncommitted cause",
                    cause_id: Some(effect.parent_cause),
                    address: None,
                }),
                None => findings.push(AuditFinding {
                    code: "CMC-AUDIT-MISSING_EFFECT_CAUSE",
                    message: "effect references a missing cause",
                    cause_id: Some(effect.parent_cause),
                    address: None,
                }),
            }
        }

        AuditReport {
            entries: self.memory.len(),
            effects: self.effects.len(),
            findings,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hash(byte: u8) -> ValueHash {
        [byte; 32]
    }

    fn render_basic_flow_golden() -> String {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(1, None, true);
        cmc.add_cause(2, Some(1), false);

        let write_known = cmc.write(0x2000, hash(9), 42, Some(1));
        let write_missing = cmc.write(0x3000, hash(10), 42, None);
        let effect_before_commit = cmc.effect(500, Some(2));
        assert!(cmc.commit_cause(2));
        let effect_after_commit = cmc.effect(500, Some(2));
        let chain = cmc.reconstruct_chain(2);
        let audit = cmc.audit();
        let trace_events = cmc.trace_events().len();

        format!(
            concat!(
                "CMC-GOLDEN basic-flow v0\n",
                "write_known_cause={:?} accepted={}\n",
                "write_missing_cause={:?} accepted={}\n",
                "effect_before_commit={:?} accepted={}\n",
                "effect_after_commit={:?} accepted={}\n",
                "chain_2={:?}\n",
                "audit.entries={}\n",
                "audit.effects={}\n",
                "audit.findings={}\n",
                "trace.events={}\n"
            ),
            write_known.code,
            write_known.accepted(),
            write_missing.code,
            write_missing.accepted(),
            effect_before_commit.code,
            effect_before_commit.accepted(),
            effect_after_commit.code,
            effect_after_commit.accepted(),
            chain,
            audit.entries,
            audit.effects,
            audit.findings.len(),
            trace_events
        )
    }

    #[test]
    fn valid_write_is_accepted() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(1, None, true);

        let decision = cmc.write(0x1000, hash(7), 42, Some(1));

        assert_eq!(decision.code, DecisionCode::AcceptWrite);
        assert!(decision.accepted());
        assert_eq!(cmc.trace_events().len(), 1);
        assert_eq!(cmc.trace_events()[0].kind, TraceEventKind::Write);
        assert_eq!(cmc.trace_events()[0].decision, DecisionCode::AcceptWrite);
        assert!(cmc.audit().findings.is_empty());
    }

    #[test]
    fn missing_cause_write_is_rejected() {
        let mut cmc = CausalMemoryController::new();

        let decision = cmc.write(0x1000, hash(7), 42, None);

        assert_eq!(decision.code, DecisionCode::RejectMissingCause);
        assert!(!decision.accepted());
        assert_eq!(cmc.trace_events().len(), 1);
        assert_eq!(cmc.trace_events()[0].decision, DecisionCode::RejectMissingCause);
        assert_eq!(cmc.audit().entries, 0);
    }

    #[test]
    fn unknown_cause_write_is_rejected() {
        let mut cmc = CausalMemoryController::new();

        let decision = cmc.write(0x1000, hash(7), 42, Some(999));

        assert_eq!(decision.code, DecisionCode::RejectUnknownCause);
        assert!(!decision.accepted());
        assert_eq!(cmc.audit().entries, 0);
    }

    #[test]
    fn effect_before_commit_is_rejected() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(7, None, false);

        let decision = cmc.effect(99, Some(7));

        assert_eq!(decision.code, DecisionCode::RejectEffectBeforeCommit);
        assert!(!decision.accepted());
        assert_eq!(cmc.trace_events().len(), 1);
        assert_eq!(cmc.trace_events()[0].kind, TraceEventKind::Effect);
        assert_eq!(
            cmc.trace_events()[0].decision,
            DecisionCode::RejectEffectBeforeCommit
        );
        assert_eq!(cmc.audit().effects, 0);
    }

    #[test]
    fn committed_effect_is_accepted() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(7, None, false);
        assert!(cmc.commit_cause(7));

        let decision = cmc.effect(99, Some(7));

        assert_eq!(decision.code, DecisionCode::AcceptEffect);
        assert!(decision.accepted());
        assert_eq!(cmc.trace_events().len(), 1);
        assert_eq!(cmc.trace_events()[0].decision, DecisionCode::AcceptEffect);
        assert!(cmc.audit().findings.is_empty());
    }

    #[test]
    fn read_emits_trace_event() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(1, None, true);
        assert!(cmc.write(0x2000, hash(9), 42, Some(1)).accepted());

        let decision = cmc.read(0x2000, 43, Some(1));

        assert_eq!(decision.code, DecisionCode::AcceptRead);
        assert_eq!(cmc.trace_events().len(), 2);
        assert_eq!(cmc.trace_events()[1].kind, TraceEventKind::Read);
        assert_eq!(cmc.trace_events()[1].decision, DecisionCode::AcceptRead);
    }

    #[test]
    fn memory_derived_effect_chain_is_reconstructable() {
        let mut cmc = CausalMemoryController::new();
        cmc.add_cause(1, None, true);
        cmc.add_cause(2, Some(1), true);

        assert!(cmc.write(0x2000, hash(9), 42, Some(2)).accepted());
        assert!(cmc.effect(500, Some(2)).accepted());

        assert_eq!(cmc.reconstruct_chain(2), vec![2, 1]);
        assert!(cmc.audit().findings.is_empty());
    }

    #[test]
    fn basic_flow_matches_golden_fixture() {
        let expected = include_str!("../fixtures/basic_flow.golden.txt");
        let actual = render_basic_flow_golden();

        assert_eq!(actual, expected);
    }
}
