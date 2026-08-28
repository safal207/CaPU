module capu_checkpoint_content_binding_v13 #(
    parameter int AUTHORIZATION_REF_WIDTH = 16,
    parameter int SPENT_AUTHORIZATION_SLOTS = 4,
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16,
    parameter int CHECKPOINT_COMMITMENT_WIDTH = 256
) (
    input logic clk,
    input logic rst_n,

    input logic recovery_begin,
    input logic restore_valid,
    input logic [SPENT_AUTHORIZATION_SLOTS-1:0] restore_spent_valid,
    input logic [(SPENT_AUTHORIZATION_SLOTS*AUTHORIZATION_REF_WIDTH)-1:0] restore_spent_refs,
    input logic cold_start_authorized,
    input logic [CHECKPOINT_REF_WIDTH-1:0] snapshot_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] snapshot_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] snapshot_checkpoint_commitment,
    // Trusted verdict from the off-path canonical commitment verifier.
    input logic snapshot_commitment_verified,

    input logic current_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] current_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] current_anchor_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] current_anchor_commitment,

    input logic checkpoint_prepare_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] candidate_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] candidate_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] candidate_checkpoint_commitment,
    // Trusted verdict that the candidate commitment was computed from the
    // canonical replay snapshot intended for persistence.
    input logic candidate_commitment_verified,
    input logic checkpoint_abort,

    input logic snapshot_persisted_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] persisted_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] persisted_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] persisted_checkpoint_commitment,

    input logic anchor_commit_ack_valid,
    input logic ack_base_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_base_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_base_anchor_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_base_anchor_commitment,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_checkpoint_commitment,

    output logic derived_commitment_trusted,
    output logic restore_commitment_mismatch,
    output logic restore_commitment_unverified,
    output logic candidate_commitment_rejected,

    output logic checkpoint_restore_accept,
    output logic checkpoint_restore_rejected,
    output logic checkpoint_rollback_detected,
    output logic checkpoint_anchor_mismatch,
    output logic checkpoint_cold_start_accept,
    output logic replay_recovery_ready,
    output logic replay_restore_accept,
    output logic replay_restore_rejected,
    output logic [$clog2(SPENT_AUTHORIZATION_SLOTS+1)-1:0] replay_spent_count,

    output logic checkpoint_prepare_accept,
    output logic checkpoint_prepare_rejected,
    output logic checkpoint_candidate_pending,
    output logic checkpoint_snapshot_persist_accept,
    output logic checkpoint_snapshot_persist_rejected,
    output logic checkpoint_snapshot_durable,
    output logic checkpoint_anchor_commit_request,
    output logic checkpoint_anchor_commit_ack_accept,
    output logic checkpoint_anchor_commit_ack_rejected,
    output logic checkpoint_commit_event,
    output logic checkpoint_stale_base_detected,

    output logic checkpoint_request_base_anchor_valid,
    output logic [CHECKPOINT_REF_WIDTH-1:0] checkpoint_request_base_anchor_ref,
    output logic [CHECKPOINT_EPOCH_WIDTH-1:0] checkpoint_request_base_anchor_epoch,
    output logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] checkpoint_request_base_anchor_commitment,
    output logic [CHECKPOINT_REF_WIDTH-1:0] checkpoint_request_ref,
    output logic [CHECKPOINT_EPOCH_WIDTH-1:0] checkpoint_request_epoch,
    output logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] checkpoint_request_commitment
);

    logic guarded_restore_valid;
    logic guarded_prepare_valid;
    logic inner_restore_accept;
    logic inner_restore_rejected;
    logic inner_prepare_accept;
    logic inner_prepare_rejected;

    logic unused_buffer_valid;
    logic unused_memory_write_enable;
    logic [1:0] unused_memory_write_addr;
    logic [3:0] unused_memory_write_data;
    logic unused_vcml_event_valid;
    logic [3:0] unused_retired_transition_id;
    logic [3:0] unused_retired_parent_ref;
    logic unused_retired_root_authorized;
    logic [AUTHORIZATION_REF_WIDTH-1:0] unused_retired_root_authorization_ref;
    logic [1:0] unused_retired_root_policy_epoch;
    logic unused_issue_rejected;
    logic unused_derived_checkpoint_trusted;
    logic unused_snapshot_well_formed;
    logic unused_replay_authorization_accept;
    logic unused_replay_authorization_ref_fresh;
    logic unused_replay_detected;
    logic unused_replay_capacity_exhausted;
    logic unused_replay_retirement_fault;
    logic unused_replay_retirement_without_recovery_fault;
    logic unused_checkpoint_candidate_invalid;
    logic unused_checkpoint_epoch_exhausted;

    initial begin
        if (CHECKPOINT_COMMITMENT_WIDTH < 1)
            $error("CaPU v0.13 requires CHECKPOINT_COMMITMENT_WIDTH >= 1");
    end

    assign derived_commitment_trusted = current_anchor_valid
                                      && snapshot_commitment_verified
                                      && snapshot_checkpoint_commitment != '0
                                      && current_anchor_commitment != '0
                                      && snapshot_checkpoint_commitment == current_anchor_commitment;

    assign restore_commitment_mismatch = restore_valid
                                      && current_anchor_valid
                                      && snapshot_commitment_verified
                                      && snapshot_checkpoint_commitment != current_anchor_commitment;

    assign restore_commitment_unverified = restore_valid
                                        && current_anchor_valid
                                        && !snapshot_commitment_verified;

    // Cold start remains the explicit v0.11/v0.12 path when no anchor exists.
    // v0.13 content-binding claims apply to anchored restore only.
    assign guarded_restore_valid = restore_valid
                                && (!current_anchor_valid || derived_commitment_trusted);

    assign candidate_commitment_rejected = checkpoint_prepare_valid
                                        && (!candidate_commitment_verified
                                            || candidate_checkpoint_commitment == '0);

    assign guarded_prepare_valid = checkpoint_prepare_valid
                                && candidate_commitment_verified
                                && candidate_checkpoint_commitment != '0;

    assign checkpoint_restore_accept = inner_restore_accept;
    assign checkpoint_restore_rejected = restore_valid && !inner_restore_accept;
    assign checkpoint_prepare_accept = inner_prepare_accept;
    assign checkpoint_prepare_rejected = checkpoint_prepare_valid && !inner_prepare_accept;

    capu_vcml_store_buffer_v12 #(
        .ADDR_WIDTH(2),
        .DATA_WIDTH(4),
        .TRANSITION_ID_WIDTH(4),
        .PARENT_REF_WIDTH(4),
        .AUTHORIZATION_REF_WIDTH(AUTHORIZATION_REF_WIDTH),
        .POLICY_EPOCH_WIDTH(2),
        .SPENT_AUTHORIZATION_SLOTS(SPENT_AUTHORIZATION_SLOTS),
        .CHECKPOINT_REF_WIDTH(CHECKPOINT_REF_WIDTH),
        .CHECKPOINT_EPOCH_WIDTH(CHECKPOINT_EPOCH_WIDTH),
        .CHECKPOINT_STATE_TAG_WIDTH(CHECKPOINT_COMMITMENT_WIDTH)
    ) inner (
        .clk(clk),
        .rst_n(rst_n),
        .recovery_begin(recovery_begin),
        .restore_valid(guarded_restore_valid),
        .restore_spent_valid(restore_spent_valid),
        .restore_spent_refs(restore_spent_refs),
        .cold_start_authorized(cold_start_authorized),
        .snapshot_checkpoint_ref(snapshot_checkpoint_ref),
        .snapshot_checkpoint_epoch(snapshot_checkpoint_epoch),
        .snapshot_checkpoint_state_tag(snapshot_checkpoint_commitment),
        .current_anchor_valid(current_anchor_valid),
        .current_anchor_ref(current_anchor_ref),
        .current_anchor_epoch(current_anchor_epoch),
        .current_anchor_state_tag(current_anchor_commitment),
        .checkpoint_prepare_valid(guarded_prepare_valid),
        .candidate_checkpoint_ref(candidate_checkpoint_ref),
        .candidate_checkpoint_epoch(candidate_checkpoint_epoch),
        .candidate_checkpoint_state_tag(candidate_checkpoint_commitment),
        .checkpoint_abort(checkpoint_abort),
        .snapshot_persisted_valid(snapshot_persisted_valid),
        .persisted_checkpoint_ref(persisted_checkpoint_ref),
        .persisted_checkpoint_epoch(persisted_checkpoint_epoch),
        .persisted_checkpoint_state_tag(persisted_checkpoint_commitment),
        .anchor_commit_ack_valid(anchor_commit_ack_valid),
        .ack_base_anchor_valid(ack_base_anchor_valid),
        .ack_base_anchor_ref(ack_base_anchor_ref),
        .ack_base_anchor_epoch(ack_base_anchor_epoch),
        .ack_base_anchor_state_tag(ack_base_anchor_commitment),
        .ack_checkpoint_ref(ack_checkpoint_ref),
        .ack_checkpoint_epoch(ack_checkpoint_epoch),
        .ack_checkpoint_state_tag(ack_checkpoint_commitment),
        .issue_valid(1'b0),
        .gate_allow(1'b0),
        .execute_ok(1'b0),
        .store_addr('0),
        .store_data('0),
        .store_ctag('0),
        .store_ctag_valid(1'b0),
        .store_transition_id('0),
        .store_parent_ref('0),
        .explicit_new_cause(1'b0),
        .root_authorized(1'b0),
        .root_authorization_ref('0),
        .root_policy_epoch('0),
        .causal_valid(1'b0),
        .commit_request(1'b0),
        .flush(1'b0),
        .buffer_valid(unused_buffer_valid),
        .memory_write_enable(unused_memory_write_enable),
        .memory_write_addr(unused_memory_write_addr),
        .memory_write_data(unused_memory_write_data),
        .vcml_event_valid(unused_vcml_event_valid),
        .retired_transition_id(unused_retired_transition_id),
        .retired_parent_ref(unused_retired_parent_ref),
        .retired_root_authorized(unused_retired_root_authorized),
        .retired_root_authorization_ref(unused_retired_root_authorization_ref),
        .retired_root_policy_epoch(unused_retired_root_policy_epoch),
        .issue_rejected(unused_issue_rejected),
        .checkpoint_restore_accept(inner_restore_accept),
        .checkpoint_restore_rejected(inner_restore_rejected),
        .checkpoint_rollback_detected(checkpoint_rollback_detected),
        .checkpoint_anchor_mismatch(checkpoint_anchor_mismatch),
        .checkpoint_cold_start_accept(checkpoint_cold_start_accept),
        .derived_checkpoint_trusted(unused_derived_checkpoint_trusted),
        .replay_recovery_ready(replay_recovery_ready),
        .replay_restore_snapshot_well_formed(unused_snapshot_well_formed),
        .replay_restore_accept(replay_restore_accept),
        .replay_restore_rejected(replay_restore_rejected),
        .replay_authorization_accept(unused_replay_authorization_accept),
        .replay_authorization_ref_fresh(unused_replay_authorization_ref_fresh),
        .replay_detected(unused_replay_detected),
        .replay_capacity_exhausted(unused_replay_capacity_exhausted),
        .replay_spent_count(replay_spent_count),
        .replay_retirement_fault(unused_replay_retirement_fault),
        .replay_retirement_without_recovery_fault(unused_replay_retirement_without_recovery_fault),
        .checkpoint_prepare_accept(inner_prepare_accept),
        .checkpoint_prepare_rejected(inner_prepare_rejected),
        .checkpoint_candidate_pending(checkpoint_candidate_pending),
        .checkpoint_candidate_invalid(unused_checkpoint_candidate_invalid),
        .checkpoint_epoch_exhausted(unused_checkpoint_epoch_exhausted),
        .checkpoint_stale_base_detected(checkpoint_stale_base_detected),
        .checkpoint_snapshot_persist_accept(checkpoint_snapshot_persist_accept),
        .checkpoint_snapshot_persist_rejected(checkpoint_snapshot_persist_rejected),
        .checkpoint_snapshot_durable(checkpoint_snapshot_durable),
        .checkpoint_anchor_commit_request(checkpoint_anchor_commit_request),
        .checkpoint_anchor_commit_ack_accept(checkpoint_anchor_commit_ack_accept),
        .checkpoint_anchor_commit_ack_rejected(checkpoint_anchor_commit_ack_rejected),
        .checkpoint_commit_event(checkpoint_commit_event),
        .checkpoint_request_base_anchor_valid(checkpoint_request_base_anchor_valid),
        .checkpoint_request_base_anchor_ref(checkpoint_request_base_anchor_ref),
        .checkpoint_request_base_anchor_epoch(checkpoint_request_base_anchor_epoch),
        .checkpoint_request_base_anchor_state_tag(checkpoint_request_base_anchor_commitment),
        .checkpoint_request_ref(checkpoint_request_ref),
        .checkpoint_request_epoch(checkpoint_request_epoch),
        .checkpoint_request_state_tag(checkpoint_request_commitment)
    );

`ifdef CAPU_ASSERTIONS
    property p_anchored_restore_is_content_bound;
        @(posedge clk) disable iff (!rst_n)
            (checkpoint_restore_accept && current_anchor_valid)
            |-> (snapshot_commitment_verified
                 && snapshot_checkpoint_commitment != '0
                 && snapshot_checkpoint_commitment == current_anchor_commitment);
    endproperty
    assert property (p_anchored_restore_is_content_bound);

    property p_prepare_requires_verified_commitment;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_prepare_accept
            |-> (candidate_commitment_verified && candidate_checkpoint_commitment != '0);
    endproperty
    assert property (p_prepare_requires_verified_commitment);

    property p_persist_accept_binds_commitment;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_snapshot_persist_accept
            |-> (persisted_checkpoint_commitment == checkpoint_request_commitment);
    endproperty
    assert property (p_persist_accept_binds_commitment);

    property p_commit_event_binds_commitment;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_commit_event
            |-> (ack_checkpoint_commitment == checkpoint_request_commitment);
    endproperty
    assert property (p_commit_event_binds_commitment);
`endif

endmodule
