use crate::trace_crypto::sha256_hex;

const RECEIPT_DOMAIN: &str = "CAPU:ASTRA:R0:PROOF-RECEIPT:V1";
const GENESIS_RECEIPT: &str =
    "0000000000000000000000000000000000000000000000000000000000000000";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OutcomeState {
    NotDispatched,
    DispatchedUnknown,
    NotCommitted,
    Committed,
    Conflict,
}

impl OutcomeState {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::NotDispatched => "NOT_DISPATCHED",
            Self::DispatchedUnknown => "DISPATCHED_UNKNOWN",
            Self::NotCommitted => "NOT_COMMITTED",
            Self::Committed => "COMMITTED",
            Self::Conflict => "CONFLICT",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EffectIdentity {
    pub authority_incarnation: u64,
    pub queue_epoch: u64,
    pub slot_id: u16,
    pub command_id: u64,
    pub execution_epoch: u64,
    pub effect_id: u64,
}

impl EffectIdentity {
    fn canonical_fields(self) -> String {
        format!(
            "{}|{}|{}|{}|{}|{}",
            self.authority_incarnation,
            self.queue_epoch,
            self.slot_id,
            self.command_id,
            self.execution_epoch,
            self.effect_id
        )
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IntentEnvelope {
    pub intent_id: String,
    pub actor_id: String,
    pub cause_id: String,
    pub parent_state_digest: String,
    pub memory_context_digest: String,
    pub policy_digest: String,
    pub requested_effect: String,
}

impl IntentEnvelope {
    pub fn new(
        intent_id: impl Into<String>,
        actor_id: impl Into<String>,
        cause_id: impl Into<String>,
        parent_state_digest: impl Into<String>,
        memory_context_digest: impl Into<String>,
        policy_digest: impl Into<String>,
        requested_effect: impl Into<String>,
    ) -> Self {
        Self {
            intent_id: intent_id.into(),
            actor_id: actor_id.into(),
            cause_id: cause_id.into(),
            parent_state_digest: parent_state_digest.into(),
            memory_context_digest: memory_context_digest.into(),
            policy_digest: policy_digest.into(),
            requested_effect: requested_effect.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuthorityTicket {
    pub authority_id: String,
    pub intent_id: String,
    pub identity: EffectIdentity,
    pub checkpoint_digest: String,
    pub policy_digest: String,
    pub committed: bool,
}

impl AuthorityTicket {
    pub fn committed(
        authority_id: impl Into<String>,
        intent_id: impl Into<String>,
        identity: EffectIdentity,
        checkpoint_digest: impl Into<String>,
        policy_digest: impl Into<String>,
    ) -> Self {
        Self {
            authority_id: authority_id.into(),
            intent_id: intent_id.into(),
            identity,
            checkpoint_digest: checkpoint_digest.into(),
            policy_digest: policy_digest.into(),
            committed: true,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OutcomeEvidence {
    pub authority_id: String,
    pub identity: EffectIdentity,
    pub outcome_state: OutcomeState,
    pub evidence_digest: String,
}

impl OutcomeEvidence {
    pub fn new(
        authority_id: impl Into<String>,
        identity: EffectIdentity,
        outcome_state: OutcomeState,
        evidence_digest: impl Into<String>,
    ) -> Self {
        Self {
            authority_id: authority_id.into(),
            identity,
            outcome_state,
            evidence_digest: evidence_digest.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProofReceipt {
    pub receipt_id: String,
    pub intent_id: String,
    pub authority_id: String,
    pub identity: EffectIdentity,
    pub pre_state_digest: String,
    pub outcome_state: OutcomeState,
    pub outcome_evidence_digest: String,
    pub post_state_digest: String,
    pub parent_receipt_digest: String,
    pub receipt_digest: String,
}

impl ProofReceipt {
    fn build(intent: &IntentEnvelope, ticket: &AuthorityTicket, evidence: &OutcomeEvidence) -> Self {
        let post_state_digest = sha256_hex(
            format!(
                "{}|{}|{}|{}",
                intent.intent_id,
                ticket.identity.effect_id,
                evidence.outcome_state.as_str(),
                evidence.evidence_digest
            )
            .as_bytes(),
        );
        let receipt_id = format!(
            "receipt-{}-{}-{}",
            ticket.identity.authority_incarnation,
            ticket.identity.queue_epoch,
            ticket.identity.effect_id
        );
        let canonical = format!(
            "{RECEIPT_DOMAIN}\0{}\0{}\0{}\0{}\0{}\0{}\0{}\0{}",
            receipt_id,
            intent.intent_id,
            ticket.authority_id,
            ticket.identity.canonical_fields(),
            ticket.checkpoint_digest,
            evidence.outcome_state.as_str(),
            evidence.evidence_digest,
            post_state_digest
        );
        let receipt_digest = sha256_hex(canonical.as_bytes());

        Self {
            receipt_id,
            intent_id: intent.intent_id.clone(),
            authority_id: ticket.authority_id.clone(),
            identity: ticket.identity,
            pre_state_digest: ticket.checkpoint_digest.clone(),
            outcome_state: evidence.outcome_state,
            outcome_evidence_digest: evidence.evidence_digest.clone(),
            post_state_digest,
            parent_receipt_digest: GENESIS_RECEIPT.to_string(),
            receipt_digest,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum R0Error {
    IntentMismatch,
    PolicyMismatch,
    NoCommittedAuthority,
    IdentityMismatch,
    InvalidTransition,
    InvalidOutcomeEvidence,
    OutcomeStillUnknown,
    ConflictEvidence,
    MemoryUpdateBlocked,
}

impl R0Error {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::IntentMismatch => "INTENT_MISMATCH",
            Self::PolicyMismatch => "POLICY_MISMATCH",
            Self::NoCommittedAuthority => "NO_COMMITTED_AUTHORITY",
            Self::IdentityMismatch => "IDENTITY_MISMATCH",
            Self::InvalidTransition => "INVALID_TRANSITION",
            Self::InvalidOutcomeEvidence => "INVALID_OUTCOME_EVIDENCE",
            Self::OutcomeStillUnknown => "OUTCOME_STILL_UNKNOWN",
            Self::ConflictEvidence => "CONFLICT_EVIDENCE",
            Self::MemoryUpdateBlocked => "MEMORY_UPDATE_BLOCKED",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UnsafeBaselineResult {
    pub dispatch_count: u32,
    pub external_effect_count: u32,
    pub duplicate_effect: bool,
    pub assumed_not_executed_after_timeout: bool,
}

pub fn unsafe_timeout_retry(first_attempt_committed: bool) -> UnsafeBaselineResult {
    let mut external_effect_count = if first_attempt_committed { 1 } else { 0 };
    let dispatch_count = 2;

    // The unsafe baseline treats a missing receipt as proof that the first
    // attempt did not execute, then dispatches a second attempt.
    external_effect_count += 1;

    UnsafeBaselineResult {
        dispatch_count,
        external_effect_count,
        duplicate_effect: external_effect_count > 1,
        assumed_not_executed_after_timeout: true,
    }
}

#[derive(Debug, Clone)]
pub struct AstraR0Controller {
    intent: IntentEnvelope,
    authority: Option<AuthorityTicket>,
    state: OutcomeState,
    issue_witness: bool,
    negative_receipt: bool,
    completion_receipt: bool,
    dispatch_count: u32,
    external_effect_count: u32,
    stale_evidence_quarantined: u32,
    trusted_memory_updated: bool,
    proof_receipt: Option<ProofReceipt>,
}

impl AstraR0Controller {
    pub fn new(intent: IntentEnvelope) -> Self {
        Self {
            intent,
            authority: None,
            state: OutcomeState::NotDispatched,
            issue_witness: false,
            negative_receipt: false,
            completion_receipt: false,
            dispatch_count: 0,
            external_effect_count: 0,
            stale_evidence_quarantined: 0,
            trusted_memory_updated: false,
            proof_receipt: None,
        }
    }

    pub fn commit_authority(&mut self, ticket: AuthorityTicket) -> Result<(), R0Error> {
        if ticket.intent_id != self.intent.intent_id {
            return Err(R0Error::IntentMismatch);
        }
        if ticket.policy_digest != self.intent.policy_digest {
            return Err(R0Error::PolicyMismatch);
        }
        if !ticket.committed {
            return Err(R0Error::NoCommittedAuthority);
        }
        if self.authority.is_some() {
            return Err(R0Error::InvalidTransition);
        }

        self.authority = Some(ticket);
        Ok(())
    }

    fn exact_identity(&self, identity: EffectIdentity) -> Result<&AuthorityTicket, R0Error> {
        let Some(ticket) = self.authority.as_ref() else {
            return Err(R0Error::NoCommittedAuthority);
        };
        if !ticket.committed {
            return Err(R0Error::NoCommittedAuthority);
        }
        if ticket.identity != identity {
            return Err(R0Error::IdentityMismatch);
        }
        Ok(ticket)
    }

    pub fn dispatch(
        &mut self,
        identity: EffectIdentity,
        external_effect_committed: bool,
    ) -> Result<(), R0Error> {
        self.exact_identity(identity)?;

        match self.state {
            OutcomeState::NotDispatched => {}
            OutcomeState::NotCommitted if self.negative_receipt => {
                self.negative_receipt = false;
            }
            _ => return Err(R0Error::InvalidTransition),
        }

        self.issue_witness = true;
        self.completion_receipt = false;
        self.proof_receipt = None;
        self.state = OutcomeState::DispatchedUnknown;
        self.dispatch_count += 1;
        if external_effect_committed {
            self.external_effect_count += 1;
        }
        Ok(())
    }

    pub fn restore_stale_pre_dispatch_checkpoint(&mut self) {
        self.trusted_memory_updated = false;
        self.state = if self.completion_receipt {
            OutcomeState::Committed
        } else if self.negative_receipt {
            OutcomeState::NotCommitted
        } else if self.issue_witness {
            OutcomeState::DispatchedUnknown
        } else {
            OutcomeState::NotDispatched
        };
    }

    pub fn reconcile(
        &mut self,
        evidence: OutcomeEvidence,
    ) -> Result<Option<ProofReceipt>, R0Error> {
        let Some(ticket) = self.authority.clone() else {
            return Err(R0Error::NoCommittedAuthority);
        };

        if evidence.authority_id != ticket.authority_id || evidence.identity != ticket.identity {
            self.stale_evidence_quarantined += 1;
            return Err(R0Error::IdentityMismatch);
        }

        if self.state != OutcomeState::DispatchedUnknown || !self.issue_witness {
            return Err(R0Error::InvalidTransition);
        }

        match evidence.outcome_state {
            OutcomeState::NotCommitted => {
                self.issue_witness = false;
                self.negative_receipt = true;
                self.completion_receipt = false;
                self.state = OutcomeState::NotCommitted;
                Ok(None)
            }
            OutcomeState::Committed => {
                self.issue_witness = false;
                self.negative_receipt = false;
                self.completion_receipt = true;
                self.state = OutcomeState::Committed;
                let receipt = ProofReceipt::build(&self.intent, &ticket, &evidence);
                self.proof_receipt = Some(receipt.clone());
                Ok(Some(receipt))
            }
            OutcomeState::Conflict => {
                self.state = OutcomeState::Conflict;
                Err(R0Error::ConflictEvidence)
            }
            OutcomeState::NotDispatched | OutcomeState::DispatchedUnknown => {
                Err(R0Error::InvalidOutcomeEvidence)
            }
        }
    }

    pub fn claim_success(&self) -> Result<(), R0Error> {
        if self.state == OutcomeState::Committed && self.completion_receipt {
            Ok(())
        } else {
            Err(R0Error::OutcomeStillUnknown)
        }
    }

    pub fn update_trusted_memory(&mut self) -> Result<String, R0Error> {
        if self.state != OutcomeState::Committed || !self.completion_receipt {
            return Err(R0Error::MemoryUpdateBlocked);
        }
        let Some(receipt) = self.proof_receipt.as_ref() else {
            return Err(R0Error::MemoryUpdateBlocked);
        };

        self.trusted_memory_updated = true;
        Ok(receipt.post_state_digest.clone())
    }

    pub fn state(&self) -> OutcomeState {
        self.state
    }

    pub fn issue_witness(&self) -> bool {
        self.issue_witness
    }

    pub fn replay_authority(&self) -> bool {
        self.state == OutcomeState::NotCommitted && self.negative_receipt
    }

    pub fn dispatch_count(&self) -> u32 {
        self.dispatch_count
    }

    pub fn external_effect_count(&self) -> u32 {
        self.external_effect_count
    }

    pub fn stale_evidence_quarantined(&self) -> u32 {
        self.stale_evidence_quarantined
    }

    pub fn trusted_memory_updated(&self) -> bool {
        self.trusted_memory_updated
    }

    pub fn proof_receipt(&self) -> Option<&ProofReceipt> {
        self.proof_receipt.as_ref()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct R0ScenarioResult {
    pub baseline_dispatch_count: u32,
    pub baseline_external_effect_count: u32,
    pub baseline_duplicate_effect: bool,
    pub capu_dispatch_count: u32,
    pub capu_external_effect_count: u32,
    pub blind_replay_blocked: bool,
    pub success_claim_blocked: bool,
    pub memory_update_blocked: bool,
    pub stale_evidence_quarantined: u32,
    pub trusted_memory_updated: bool,
    pub proof_receipt_digest: String,
}

impl R0ScenarioResult {
    pub fn to_json(&self) -> String {
        format!(
            concat!(
                "{{",
                "\"schema\":\"capu.astra.r0.result.v1\",",
                "\"baseline_dispatch_count\":{},",
                "\"baseline_external_effect_count\":{},",
                "\"baseline_duplicate_effect\":{},",
                "\"capu_dispatch_count\":{},",
                "\"capu_external_effect_count\":{},",
                "\"blind_replay_blocked\":{},",
                "\"success_claim_blocked\":{},",
                "\"memory_update_blocked\":{},",
                "\"stale_evidence_quarantined\":{},",
                "\"trusted_memory_updated\":{},",
                "\"proof_receipt_digest\":\"{}\"",
                "}}"
            ),
            self.baseline_dispatch_count,
            self.baseline_external_effect_count,
            self.baseline_duplicate_effect,
            self.capu_dispatch_count,
            self.capu_external_effect_count,
            self.blind_replay_blocked,
            self.success_claim_blocked,
            self.memory_update_blocked,
            self.stale_evidence_quarantined,
            self.trusted_memory_updated,
            self.proof_receipt_digest
        )
    }
}

pub fn run_r0_scenario() -> Result<R0ScenarioResult, R0Error> {
    let baseline = unsafe_timeout_retry(true);

    let intent = IntentEnvelope::new(
        "intent-r0-001",
        "agent-1",
        "cause-r0-001",
        sha256_hex(b"r0-pre-state"),
        sha256_hex(b"r0-memory-context"),
        sha256_hex(b"r0-policy"),
        "synthetic-dma-write",
    );
    let identity = EffectIdentity {
        authority_incarnation: 7,
        queue_epoch: 12,
        slot_id: 0,
        command_id: 41,
        execution_epoch: 3,
        effect_id: 99,
    };
    let ticket = AuthorityTicket::committed(
        "authority-r0-001",
        intent.intent_id.clone(),
        identity,
        intent.parent_state_digest.clone(),
        intent.policy_digest.clone(),
    );

    let mut controller = AstraR0Controller::new(intent);
    controller.commit_authority(ticket)?;
    controller.dispatch(identity, true)?;
    controller.restore_stale_pre_dispatch_checkpoint();

    let blind_replay_blocked = matches!(
        controller.dispatch(identity, true),
        Err(R0Error::InvalidTransition)
    );
    let success_claim_blocked = matches!(
        controller.claim_success(),
        Err(R0Error::OutcomeStillUnknown)
    );
    let memory_update_blocked = matches!(
        controller.update_trusted_memory(),
        Err(R0Error::MemoryUpdateBlocked)
    );

    let foreign_identity = EffectIdentity {
        authority_incarnation: 6,
        ..identity
    };
    let foreign = OutcomeEvidence::new(
        "authority-r0-001",
        foreign_identity,
        OutcomeState::Committed,
        sha256_hex(b"stale-foreign-completion"),
    );
    assert_eq!(
        controller.reconcile(foreign),
        Err(R0Error::IdentityMismatch)
    );

    let exact = OutcomeEvidence::new(
        "authority-r0-001",
        identity,
        OutcomeState::Committed,
        sha256_hex(b"exact-device-completion"),
    );
    let receipt = controller
        .reconcile(exact)?
        .ok_or(R0Error::InvalidOutcomeEvidence)?;
    controller.claim_success()?;
    controller.update_trusted_memory()?;

    Ok(R0ScenarioResult {
        baseline_dispatch_count: baseline.dispatch_count,
        baseline_external_effect_count: baseline.external_effect_count,
        baseline_duplicate_effect: baseline.duplicate_effect,
        capu_dispatch_count: controller.dispatch_count(),
        capu_external_effect_count: controller.external_effect_count(),
        blind_replay_blocked,
        success_claim_blocked,
        memory_update_blocked,
        stale_evidence_quarantined: controller.stale_evidence_quarantined(),
        trusted_memory_updated: controller.trusted_memory_updated(),
        proof_receipt_digest: receipt.receipt_digest,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture() -> (IntentEnvelope, AuthorityTicket, EffectIdentity) {
        let intent = IntentEnvelope::new(
            "intent-test",
            "agent-test",
            "cause-test",
            sha256_hex(b"pre"),
            sha256_hex(b"memory"),
            sha256_hex(b"policy"),
            "synthetic-dma-write",
        );
        let identity = EffectIdentity {
            authority_incarnation: 2,
            queue_epoch: 4,
            slot_id: 0,
            command_id: 10,
            execution_epoch: 1,
            effect_id: 20,
        };
        let ticket = AuthorityTicket::committed(
            "authority-test",
            intent.intent_id.clone(),
            identity,
            intent.parent_state_digest.clone(),
            intent.policy_digest.clone(),
        );
        (intent, ticket, identity)
    }

    #[test]
    fn unsafe_timeout_retry_duplicates_a_committed_effect() {
        let result = unsafe_timeout_retry(true);
        assert_eq!(result.dispatch_count, 2);
        assert_eq!(result.external_effect_count, 2);
        assert!(result.duplicate_effect);
    }

    #[test]
    fn unknown_blocks_replay_success_and_memory_update() {
        let (intent, ticket, identity) = fixture();
        let mut controller = AstraR0Controller::new(intent);
        controller.commit_authority(ticket).unwrap();
        controller.dispatch(identity, true).unwrap();
        controller.restore_stale_pre_dispatch_checkpoint();

        assert_eq!(controller.state(), OutcomeState::DispatchedUnknown);
        assert!(controller.issue_witness());
        assert_eq!(
            controller.dispatch(identity, true),
            Err(R0Error::InvalidTransition)
        );
        assert_eq!(
            controller.claim_success(),
            Err(R0Error::OutcomeStillUnknown)
        );
        assert_eq!(
            controller.update_trusted_memory(),
            Err(R0Error::MemoryUpdateBlocked)
        );
        assert_eq!(controller.external_effect_count(), 1);
    }

    #[test]
    fn exact_negative_evidence_reopens_one_replay_attempt() {
        let (intent, ticket, identity) = fixture();
        let mut controller = AstraR0Controller::new(intent);
        controller.commit_authority(ticket).unwrap();
        controller.dispatch(identity, false).unwrap();

        let negative = OutcomeEvidence::new(
            "authority-test",
            identity,
            OutcomeState::NotCommitted,
            sha256_hex(b"not-committed"),
        );
        assert_eq!(controller.reconcile(negative).unwrap(), None);
        assert!(controller.replay_authority());

        controller.dispatch(identity, true).unwrap();
        assert_eq!(controller.state(), OutcomeState::DispatchedUnknown);
        assert!(!controller.replay_authority());
        assert_eq!(controller.dispatch_count(), 2);
        assert_eq!(controller.external_effect_count(), 1);
    }

    #[test]
    fn exact_committed_evidence_seals_receipt_and_memory_update() {
        let (intent, ticket, identity) = fixture();
        let mut controller = AstraR0Controller::new(intent);
        controller.commit_authority(ticket).unwrap();
        controller.dispatch(identity, true).unwrap();

        let committed = OutcomeEvidence::new(
            "authority-test",
            identity,
            OutcomeState::Committed,
            sha256_hex(b"committed"),
        );
        let receipt = controller.reconcile(committed).unwrap().unwrap();

        assert_eq!(receipt.outcome_state, OutcomeState::Committed);
        assert_eq!(receipt.receipt_digest.len(), 64);
        assert!(controller.claim_success().is_ok());
        assert_eq!(
            controller.update_trusted_memory().unwrap(),
            receipt.post_state_digest
        );
        assert!(controller.trusted_memory_updated());
    }

    #[test]
    fn foreign_incarnation_is_quarantined() {
        let (intent, ticket, identity) = fixture();
        let mut controller = AstraR0Controller::new(intent);
        controller.commit_authority(ticket).unwrap();
        controller.dispatch(identity, true).unwrap();

        let foreign = OutcomeEvidence::new(
            "authority-test",
            EffectIdentity {
                authority_incarnation: identity.authority_incarnation - 1,
                ..identity
            },
            OutcomeState::Committed,
            sha256_hex(b"foreign"),
        );

        assert_eq!(
            controller.reconcile(foreign),
            Err(R0Error::IdentityMismatch)
        );
        assert_eq!(controller.stale_evidence_quarantined(), 1);
        assert_eq!(controller.state(), OutcomeState::DispatchedUnknown);
    }

    #[test]
    fn deterministic_r0_witness_has_one_causal_effect() {
        let result = run_r0_scenario().unwrap();
        assert!(result.baseline_duplicate_effect);
        assert_eq!(result.baseline_external_effect_count, 2);
        assert_eq!(result.capu_external_effect_count, 1);
        assert!(result.blind_replay_blocked);
        assert!(result.success_claim_blocked);
        assert!(result.memory_update_blocked);
        assert!(result.trusted_memory_updated);
        assert_eq!(result.proof_receipt_digest.len(), 64);
    }
}
