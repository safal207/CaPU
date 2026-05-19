pub mod trace_crypto;

use std::collections::{HashMap, HashSet};

pub type Address = u64;
pub type ActorId = u32;
pub type CauseId = u64;
pub type EffectId = u64;
pub type ValueHash = [u8; 32];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DecisionCode { AcceptWrite, AcceptRead, AcceptEffect, RejectMissingCause, RejectUnknownCause, RejectEffectBeforeCommit }
impl DecisionCode { pub fn as_str(self) -> &'static str { match self { Self::AcceptWrite => "ACCEPT_WRITE", Self::AcceptRead => "ACCEPT_READ", Self::AcceptEffect => "ACCEPT_EFFECT", Self::RejectMissingCause => "REJECT_MISSING_CAUSE", Self::RejectUnknownCause => "REJECT_UNKNOWN_CAUSE", Self::RejectEffectBeforeCommit => "REJECT_EFFECT_BEFORE_COMMIT" } } }

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Decision { pub code: DecisionCode, pub cause_id: Option<CauseId>, pub message: &'static str }
impl Decision { pub fn accepted(&self) -> bool { matches!(self.code, DecisionCode::AcceptWrite | DecisionCode::AcceptRead | DecisionCode::AcceptEffect) } }

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TraceEventKind { Write, Read, Effect }
impl TraceEventKind { pub fn as_str(self) -> &'static str { match self { Self::Write => "WRITE", Self::Read => "READ", Self::Effect => "EFFECT" } } }

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TraceEvent { pub seq: u64, pub kind: TraceEventKind, pub decision: DecisionCode, pub address: Option<Address>, pub effect_id: Option<EffectId>, pub cause_id: Option<CauseId>, pub message: &'static str }
impl TraceEvent { pub fn to_json_line(&self) -> String { format!("{{\"seq\":{},\"kind\":\"{}\",\"decision\":\"{}\",\"address\":{},\"effect_id\":{},\"cause_id\":{},\"message\":\"{}\"}}", self.seq, self.kind.as_str(), self.decision.as_str(), opt(self.address), opt(self.effect_id), opt(self.cause_id), self.message.replace('\\', "\\\\").replace('"', "\\\"")) } }
fn opt(v: Option<u64>) -> String { v.map_or_else(|| "null".to_string(), |x| x.to_string()) }

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CauseRecord { pub id: CauseId, pub parent: Option<CauseId>, pub committed: bool }
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CausalMemoryEntry { pub address: Address, pub value_hash: ValueHash, pub writer: ActorId, pub cause_id: CauseId, pub parent_cause: Option<CauseId>, pub timestamp: u64 }
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EffectRecord { pub effect_id: EffectId, pub parent_cause: CauseId }
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuditFinding { pub code: &'static str, pub message: &'static str, pub cause_id: Option<CauseId>, pub address: Option<Address> }
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuditReport { pub entries: usize, pub effects: usize, pub findings: Vec<AuditFinding> }

#[derive(Debug, Default)]
pub struct CausalMemoryController { causes: HashMap<CauseId, CauseRecord>, memory: HashMap<Address, CausalMemoryEntry>, effects: Vec<EffectRecord>, trace: Vec<TraceEvent>, clock: u64, trace_seq: u64 }
impl CausalMemoryController {
    pub fn new() -> Self { Self::default() }
    pub fn add_cause(&mut self, id: CauseId, parent: Option<CauseId>, committed: bool) { self.causes.insert(id, CauseRecord { id, parent, committed }); }
    pub fn commit_cause(&mut self, id: CauseId) -> bool { self.causes.get_mut(&id).map(|c| { c.committed = true; true }).unwrap_or(false) }
    pub fn trace_events(&self) -> &[TraceEvent] { &self.trace }
    pub fn trace_jsonl(&self) -> String { let mut s = self.trace.iter().map(TraceEvent::to_json_line).collect::<Vec<_>>().join("\n"); if !s.is_empty() { s.push('\n'); } s }
    fn emit(&mut self, kind: TraceEventKind, decision: &Decision, address: Option<Address>, effect_id: Option<EffectId>) { self.trace_seq += 1; self.trace.push(TraceEvent { seq: self.trace_seq, kind, decision: decision.code, address, effect_id, cause_id: decision.cause_id, message: decision.message }); }
    pub fn write(&mut self, address: Address, value_hash: ValueHash, writer: ActorId, cause_id: Option<CauseId>) -> Decision { let Some(cid) = cause_id else { let d = Decision { code: DecisionCode::RejectMissingCause, cause_id: None, message: "memory write requires an explicit cause" }; self.emit(TraceEventKind::Write, &d, Some(address), None); return d; }; let Some(cause) = self.causes.get(&cid) else { let d = Decision { code: DecisionCode::RejectUnknownCause, cause_id: Some(cid), message: "memory write references an unknown cause" }; self.emit(TraceEventKind::Write, &d, Some(address), None); return d; }; let parent_cause = cause.parent; self.clock += 1; self.memory.insert(address, CausalMemoryEntry { address, value_hash, writer, cause_id: cid, parent_cause, timestamp: self.clock }); let d = Decision { code: DecisionCode::AcceptWrite, cause_id: Some(cid), message: "causal memory write accepted" }; self.emit(TraceEventKind::Write, &d, Some(address), None); d }
    pub fn read(&mut self, address: Address, _requester: ActorId, cause_id: Option<CauseId>) -> Decision { let Some(cid) = cause_id else { let d = Decision { code: DecisionCode::RejectMissingCause, cause_id: None, message: "memory read requires an explicit cause" }; self.emit(TraceEventKind::Read, &d, Some(address), None); return d; }; if !self.causes.contains_key(&cid) || !self.memory.contains_key(&address) { let d = Decision { code: DecisionCode::RejectUnknownCause, cause_id: Some(cid), message: "memory read references an unknown cause or address" }; self.emit(TraceEventKind::Read, &d, Some(address), None); return d; } let d = Decision { code: DecisionCode::AcceptRead, cause_id: Some(cid), message: "causal memory read accepted" }; self.emit(TraceEventKind::Read, &d, Some(address), None); d }
    pub fn effect(&mut self, effect_id: EffectId, parent_cause: Option<CauseId>) -> Decision { let Some(cid) = parent_cause else { let d = Decision { code: DecisionCode::RejectMissingCause, cause_id: None, message: "effect requires a committed parent cause" }; self.emit(TraceEventKind::Effect, &d, None, Some(effect_id)); return d; }; let Some(cause) = self.causes.get(&cid) else { let d = Decision { code: DecisionCode::RejectUnknownCause, cause_id: Some(cid), message: "effect references an unknown parent cause" }; self.emit(TraceEventKind::Effect, &d, None, Some(effect_id)); return d; }; if !cause.committed { let d = Decision { code: DecisionCode::RejectEffectBeforeCommit, cause_id: Some(cid), message: "effect cannot execute before causal commit" }; self.emit(TraceEventKind::Effect, &d, None, Some(effect_id)); return d; } self.effects.push(EffectRecord { effect_id, parent_cause: cid }); let d = Decision { code: DecisionCode::AcceptEffect, cause_id: Some(cid), message: "effect accepted after committed causal authorization" }; self.emit(TraceEventKind::Effect, &d, None, Some(effect_id)); d }
    pub fn reconstruct_chain(&self, cause_id: CauseId) -> Vec<CauseId> { let mut out = Vec::new(); let mut seen = HashSet::new(); let mut cur = Some(cause_id); while let Some(id) = cur { if !seen.insert(id) { break; } out.push(id); cur = self.causes.get(&id).and_then(|c| c.parent); } out }
    pub fn audit(&self) -> AuditReport { AuditReport { entries: self.memory.len(), effects: self.effects.len(), findings: Vec::new() } }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn hash(b: u8) -> ValueHash { [b; 32] }
    #[test] fn valid_write_is_accepted() { let mut c = CausalMemoryController::new(); c.add_cause(1, None, true); assert_eq!(c.write(0x1000, hash(7), 42, Some(1)).code, DecisionCode::AcceptWrite); assert_eq!(c.trace_events()[0].kind, TraceEventKind::Write); }
    #[test] fn missing_cause_write_is_rejected() { let mut c = CausalMemoryController::new(); assert_eq!(c.write(0x1000, hash(7), 42, None).code, DecisionCode::RejectMissingCause); assert_eq!(c.audit().entries, 0); }
    #[test] fn unknown_cause_write_is_rejected() { let mut c = CausalMemoryController::new(); assert_eq!(c.write(0x1000, hash(7), 42, Some(999)).code, DecisionCode::RejectUnknownCause); }
    #[test] fn effect_before_commit_is_rejected() { let mut c = CausalMemoryController::new(); c.add_cause(7, None, false); assert_eq!(c.effect(99, Some(7)).code, DecisionCode::RejectEffectBeforeCommit); }
    #[test] fn committed_effect_is_accepted() { let mut c = CausalMemoryController::new(); c.add_cause(7, None, false); assert!(c.commit_cause(7)); assert_eq!(c.effect(99, Some(7)).code, DecisionCode::AcceptEffect); }
    #[test] fn read_emits_trace_event() { let mut c = CausalMemoryController::new(); c.add_cause(1, None, true); assert!(c.write(0x2000, hash(9), 42, Some(1)).accepted()); assert_eq!(c.read(0x2000, 43, Some(1)).code, DecisionCode::AcceptRead); assert_eq!(c.trace_events()[1].kind, TraceEventKind::Read); }
    #[test] fn trace_exports_jsonl() { let mut c = CausalMemoryController::new(); c.write(0x1000, hash(7), 42, None); assert!(c.trace_jsonl().contains("\"decision\":\"REJECT_MISSING_CAUSE\"")); }
    #[test] fn memory_derived_effect_chain_is_reconstructable() { let mut c = CausalMemoryController::new(); c.add_cause(1, None, true); c.add_cause(2, Some(1), true); assert_eq!(c.reconstruct_chain(2), vec![2,1]); }
    #[test] fn basic_flow_matches_golden_fixture() { let mut c = CausalMemoryController::new(); c.add_cause(1, None, true); c.add_cause(2, Some(1), false); let w1=c.write(0x2000, hash(9), 42, Some(1)); let w2=c.write(0x3000, hash(10), 42, None); let e1=c.effect(500, Some(2)); assert!(c.commit_cause(2)); let e2=c.effect(500, Some(2)); let actual=format!("CMC-GOLDEN basic-flow v0\nwrite_known_cause={:?} accepted={}\nwrite_missing_cause={:?} accepted={}\neffect_before_commit={:?} accepted={}\neffect_after_commit={:?} accepted={}\nchain_2={:?}\naudit.entries={}\naudit.effects={}\naudit.findings={}\ntrace.events={}\n", w1.code,w1.accepted(),w2.code,w2.accepted(),e1.code,e1.accepted(),e2.code,e2.accepted(),c.reconstruct_chain(2),c.audit().entries,c.audit().effects,c.audit().findings.len(),c.trace_events().len()); assert_eq!(actual, include_str!("../fixtures/basic_flow.golden.txt")); }
}
