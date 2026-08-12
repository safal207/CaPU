module capu_vcml_store_buffer_v12 #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int TRANSITION_ID_WIDTH = 64,
    parameter int PARENT_REF_WIDTH = 64,
    parameter int AUTHORIZATION_REF_WIDTH = 16,
    parameter int POLICY_EPOCH_WIDTH = 8,
    parameter int SPENT_AUTHORIZATION_SLOTS = 4,
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16,
    parameter int CHECKPOINT_STATE_TAG_WIDTH = 32,
    parameter bit REQUIRE_WRITE_CLASS = 1'b1
) (
    input logic clk,
    input logic rst_n,

    // v0.10/v0.11 recovery inputs.
    input logic recovery_begin,
    input logic restore_valid,
    input logic [SPENT_AUTHORIZATION_SLOTS-1:0] restore_spent_valid,
    input logic [(SPENT_AUTHORIZATION_SLOTS*AUTHORIZATION_REF_WIDTH)-1:0] restore_spent_refs,
    input logic cold_start_authorized,
    input logic [CHECKPOINT_REF_WIDTH-1:0] snapshot_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] snapshot_checkpoint_epoch,
    input logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] snapshot_checkpoint_state_tag,

    // Trusted external durable-anchor view.
    input logic current_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] current_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] current_anchor_epoch,
    input logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] current_anchor_state_tag,

    // v0.12 checkpoint creation protocol.
    input logic checkpoint_prepare_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] candidate_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] candidate_checkpoint_epoch,
    input logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] candidate_checkpoint_state_tag,
    input logic checkpoint_abort,
    input logic snapshot_persisted_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] persisted_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] persisted_checkpoint_epoch,
    input logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] persisted_checkpoint_state_tag,
    input logic anchor_commit_ack_valid,
    input logic ack_base_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_base_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_base_anchor_epoch,
    input logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] ack_base_anchor_state_tag,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_checkpoint_epoch,
    input logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] ack_checkpoint_state_tag,

    // Existing causal STORE path.
    input logic issue_valid,
    input logic gate_allow,
    input logic execute_ok,
    input logic [ADDR_WIDTH-1:0] store_addr,
    input logic [DATA_WIDTH-1:0] store_data,
    input logic [15:0] store_ctag,
    input logic store_ctag_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] store_transition_id,
    input logic [PARENT_REF_WIDTH-1:0] store_parent_ref,
    input logic explicit_new_cause,
    input logic root_authorized,
    input logic [AUTHORIZATION_REF_WIDTH-1:0] root_authorization_ref,
    input logic [POLICY_EPOCH_WIDTH-1:0] root_policy_epoch,
    input logic causal_valid,
    input logic commit_request,
    input logic flush,

    output logic buffer_valid,
    output logic memory_write_enable,
    output logic [ADDR_WIDTH-1:0] memory_write_addr,
    output logic [DATA_WIDTH-1:0] memory_write_data,
    output logic vcml_event_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] retired_transition_id,
    output logic [PARENT_REF_WIDTH-1:0] retired_parent_ref,
    output logic retired_root_authorized,
    output logic [AUTHORIZATION_REF_WIDTH-1:0] retired_root_authorization_ref,
    output logic [POLICY_EPOCH_WIDTH-1:0] retired_root_policy_epoch,
    output logic issue_rejected,

    // Recovery/checkpoint observability.
    output logic checkpoint_restore_accept,
    output logic checkpoint_restore_rejected,
    output logic checkpoint_rollback_detected,
    output logic checkpoint_anchor_mismatch,
    output logic checkpoint_cold_start_accept,
    output logic derived_checkpoint_trusted,

    output logic replay_recovery_ready,
    output logic replay_restore_snapshot_well_formed,
    output logic replay_restore_accept,
    output logic replay_restore_rejected,
    output logic replay_authorization_accept,
    output logic replay_authorization_ref_fresh,
    output logic replay_detected,
    output logic replay_capacity_exhausted,
    output logic [$clog2(SPENT_AUTHORIZATION_SLOTS+1)-1:0] replay_spent_count,
    output logic replay_retirement_fault,
    output logic replay_retirement_without_recovery_fault,

    output logic checkpoint_prepare_accept,
    output logic checkpoint_prepare_rejected,
    output logic checkpoint_candidate_pending,
    output logic checkpoint_candidate_invalid,
    output logic checkpoint_epoch_exhausted,
    output logic checkpoint_stale_base_detected,
    output logic checkpoint_snapshot_persist_accept,
    output logic checkpoint_snapshot_persist_rejected,
    output logic checkpoint_snapshot_durable,
    output logic checkpoint_anchor_commit_request,
    output logic checkpoint_anchor_commit_ack_accept,
    output logic checkpoint_anchor_commit_ack_rejected,
    output logic checkpoint_commit_event,
    output logic checkpoint_request_base_anchor_valid,
    output logic [CHECKPOINT_REF_WIDTH-1:0] checkpoint_request_base_anchor_ref,
    output logic [CHECKPOINT_EPOCH_WIDTH-1:0] checkpoint_request_base_anchor_epoch,
    output logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] checkpoint_request_base_anchor_state_tag,
    output logic [CHECKPOINT_REF_WIDTH-1:0] checkpoint_request_ref,
    output logic [CHECKPOINT_EPOCH_WIDTH-1:0] checkpoint_request_epoch,
    output logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] checkpoint_request_state_tag
);

    // v0.12 removes the free-standing checkpoint_trusted restore sideband from
    // the wrapper. Trust at this boundary is derived by exact equality to the
    // externally authoritative anchor's state binding. The state tag is opaque
    // metadata here; CaPU does not compute or cryptographically validate it.
    assign derived_checkpoint_trusted = current_anchor_valid
                                      && current_anchor_ref != '0
                                      && current_anchor_epoch != '0
                                      && current_anchor_state_tag != '0
                                      && snapshot_checkpoint_state_tag == current_anchor_state_tag;

    capu_checkpoint_commit_controller #(
        .CHECKPOINT_REF_WIDTH(CHECKPOINT_REF_WIDTH),
        .CHECKPOINT_EPOCH_WIDTH(CHECKPOINT_EPOCH_WIDTH),
        .CHECKPOINT_STATE_TAG_WIDTH(CHECKPOINT_STATE_TAG_WIDTH)
    ) commit_controller (
        .clk(clk),
        .rst_n(rst_n),
        .current_anchor_valid(current_anchor_valid),
        .current_anchor_ref(current_anchor_ref),
        .current_anchor_epoch(current_anchor_epoch),
        .current_anchor_state_tag(current_anchor_state_tag),
        .checkpoint_prepare_valid(checkpoint_prepare_valid),
        .candidate_checkpoint_ref(candidate_checkpoint_ref),
        .candidate_checkpoint_epoch(candidate_checkpoint_epoch),
        .candidate_checkpoint_state_tag(candidate_checkpoint_state_tag),
        .checkpoint_abort(checkpoint_abort),
        .snapshot_persisted_valid(snapshot_persisted_valid),
        .persisted_checkpoint_ref(persisted_checkpoint_ref),
        .persisted_checkpoint_epoch(persisted_checkpoint_epoch),
        .persisted_checkpoint_state_tag(persisted_checkpoint_state_tag),
        .anchor_commit_ack_valid(anchor_commit_ack_valid),
        .ack_base_anchor_valid(ack_base_anchor_valid),
        .ack_base_anchor_ref(ack_base_anchor_ref),
        .ack_base_anchor_epoch(ack_base_anchor_epoch),
        .ack_base_anchor_state_tag(ack_base_anchor_state_tag),
        .ack_checkpoint_ref(ack_checkpoint_ref),
        .ack_checkpoint_epoch(ack_checkpoint_epoch),
        .ack_checkpoint_state_tag(ack_checkpoint_state_tag),
        .prepare_accept(checkpoint_prepare_accept),
        .prepare_rejected(checkpoint_prepare_rejected),
        .candidate_pending(checkpoint_candidate_pending),
        .candidate_invalid(checkpoint_candidate_invalid),
        .epoch_exhausted(checkpoint_epoch_exhausted),
        .stale_base_detected(checkpoint_stale_base_detected),
        .snapshot_persist_accept(checkpoint_snapshot_persist_accept),
        .snapshot_persist_rejected(checkpoint_snapshot_persist_rejected),
        .snapshot_durable(checkpoint_snapshot_durable),
        .anchor_commit_request(checkpoint_anchor_commit_request),
        .anchor_commit_ack_accept(checkpoint_anchor_commit_ack_accept),
        .anchor_commit_ack_rejected(checkpoint_anchor_commit_ack_rejected),
        .checkpoint_commit_event(checkpoint_commit_event),
        .request_base_anchor_valid(checkpoint_request_base_anchor_valid),
        .request_base_anchor_ref(checkpoint_request_base_anchor_ref),
        .request_base_anchor_epoch(checkpoint_request_base_anchor_epoch),
        .request_base_anchor_state_tag(checkpoint_request_base_anchor_state_tag),
        .request_checkpoint_ref(checkpoint_request_ref),
        .request_checkpoint_epoch(checkpoint_request_epoch),
        .request_checkpoint_state_tag(checkpoint_request_state_tag)
    );

    capu_vcml_store_buffer_v11 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TRANSITION_ID_WIDTH(TRANSITION_ID_WIDTH),
        .PARENT_REF_WIDTH(PARENT_REF_WIDTH),
        .AUTHORIZATION_REF_WIDTH(AUTHORIZATION_REF_WIDTH),
        .POLICY_EPOCH_WIDTH(POLICY_EPOCH_WIDTH),
        .SPENT_AUTHORIZATION_SLOTS(SPENT_AUTHORIZATION_SLOTS),
        .CHECKPOINT_REF_WIDTH(CHECKPOINT_REF_WIDTH),
        .CHECKPOINT_EPOCH_WIDTH(CHECKPOINT_EPOCH_WIDTH),
        .REQUIRE_WRITE_CLASS(REQUIRE_WRITE_CLASS)
    ) recovery_and_store (
        .clk(clk),
        .rst_n(rst_n),
        .recovery_begin(recovery_begin),
        .restore_valid(restore_valid),
        .restore_spent_valid(restore_spent_valid),
        .restore_spent_refs(restore_spent_refs),
        .checkpoint_trusted(derived_checkpoint_trusted),
        .cold_start_authorized(cold_start_authorized),
        .snapshot_checkpoint_ref(snapshot_checkpoint_ref),
        .snapshot_checkpoint_epoch(snapshot_checkpoint_epoch),
        .anchor_valid(current_anchor_valid),
        .anchor_checkpoint_ref(current_anchor_ref),
        .anchor_checkpoint_epoch(current_anchor_epoch),
        .issue_valid(issue_valid),
        .gate_allow(gate_allow),
        .execute_ok(execute_ok),
        .store_addr(store_addr),
        .store_data(store_data),
        .store_ctag(store_ctag),
        .store_ctag_valid(store_ctag_valid),
        .store_transition_id(store_transition_id),
        .store_parent_ref(store_parent_ref),
        .explicit_new_cause(explicit_new_cause),
        .root_authorized(root_authorized),
        .root_authorization_ref(root_authorization_ref),
        .root_policy_epoch(root_policy_epoch),
        .causal_valid(causal_valid),
        .commit_request(commit_request),
        .flush(flush),
        .buffer_valid(buffer_valid),
        .memory_write_enable(memory_write_enable),
        .memory_write_addr(memory_write_addr),
        .memory_write_data(memory_write_data),
        .vcml_event_valid(vcml_event_valid),
        .retired_transition_id(retired_transition_id),
        .retired_parent_ref(retired_parent_ref),
        .retired_root_authorized(retired_root_authorized),
        .retired_root_authorization_ref(retired_root_authorization_ref),
        .retired_root_policy_epoch(retired_root_policy_epoch),
        .issue_rejected(issue_rejected),
        .checkpoint_restore_accept(checkpoint_restore_accept),
        .checkpoint_restore_rejected(checkpoint_restore_rejected),
        .checkpoint_rollback_detected(checkpoint_rollback_detected),
        .checkpoint_anchor_mismatch(checkpoint_anchor_mismatch),
        .checkpoint_cold_start_accept(checkpoint_cold_start_accept),
        .replay_recovery_ready(replay_recovery_ready),
        .replay_restore_snapshot_well_formed(replay_restore_snapshot_well_formed),
        .replay_restore_accept(replay_restore_accept),
        .replay_restore_rejected(replay_restore_rejected),
        .replay_authorization_accept(replay_authorization_accept),
        .replay_authorization_ref_fresh(replay_authorization_ref_fresh),
        .replay_detected(replay_detected),
        .replay_capacity_exhausted(replay_capacity_exhausted),
        .replay_spent_count(replay_spent_count),
        .replay_retirement_fault(replay_retirement_fault),
        .replay_retirement_without_recovery_fault(replay_retirement_without_recovery_fault)
    );

`ifdef CAPU_ASSERTIONS
    property p_anchored_restore_requires_state_binding;
        @(posedge clk) disable iff (!rst_n)
            (checkpoint_restore_accept && current_anchor_valid)
            |-> derived_checkpoint_trusted;
    endproperty
    assert property (p_anchored_restore_requires_state_binding);

    property p_commit_event_requires_external_ack;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_commit_event |-> checkpoint_anchor_commit_ack_accept;
    endproperty
    assert property (p_commit_event_requires_external_ack);
`endif

endmodule
