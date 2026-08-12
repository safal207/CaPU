module capu_vcml_store_buffer_v11 #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int TRANSITION_ID_WIDTH = 64,
    parameter int PARENT_REF_WIDTH = 64,
    parameter int AUTHORIZATION_REF_WIDTH = 16,
    parameter int POLICY_EPOCH_WIDTH = 8,
    parameter int SPENT_AUTHORIZATION_SLOTS = 4,
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16,
    parameter bit REQUIRE_WRITE_CLASS = 1'b1
) (
    input logic clk,
    input logic rst_n,

    input logic recovery_begin,
    input logic restore_valid,
    input logic [SPENT_AUTHORIZATION_SLOTS-1:0] restore_spent_valid,
    input logic [(SPENT_AUTHORIZATION_SLOTS*AUTHORIZATION_REF_WIDTH)-1:0] restore_spent_refs,

    input logic checkpoint_trusted,
    input logic cold_start_authorized,
    input logic [CHECKPOINT_REF_WIDTH-1:0] snapshot_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] snapshot_checkpoint_epoch,
    input logic anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] anchor_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] anchor_checkpoint_epoch,

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

    output logic checkpoint_restore_accept,
    output logic checkpoint_restore_rejected,
    output logic checkpoint_rollback_detected,
    output logic checkpoint_anchor_mismatch,
    output logic checkpoint_cold_start_accept,

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
    output logic replay_retirement_without_recovery_fault
);

    logic guarded_restore_valid;

    capu_checkpoint_freshness_guard #(
        .CHECKPOINT_REF_WIDTH(CHECKPOINT_REF_WIDTH),
        .CHECKPOINT_EPOCH_WIDTH(CHECKPOINT_EPOCH_WIDTH)
    ) checkpoint_guard (
        .clk(clk),
        .rst_n(rst_n),
        .recovery_begin(recovery_begin),
        .restore_valid(restore_valid),
        .checkpoint_trusted(checkpoint_trusted),
        .cold_start_authorized(cold_start_authorized),
        .snapshot_checkpoint_ref(snapshot_checkpoint_ref),
        .snapshot_checkpoint_epoch(snapshot_checkpoint_epoch),
        .anchor_valid(anchor_valid),
        .anchor_checkpoint_ref(anchor_checkpoint_ref),
        .anchor_checkpoint_epoch(anchor_checkpoint_epoch),
        .checkpoint_restore_accept(checkpoint_restore_accept),
        .checkpoint_restore_rejected(checkpoint_restore_rejected),
        .checkpoint_rollback_detected(checkpoint_rollback_detected),
        .checkpoint_anchor_mismatch(checkpoint_anchor_mismatch),
        .checkpoint_cold_start_accept(checkpoint_cold_start_accept)
    );

    // v0.10 only sees a restore transaction once v0.11 has accepted the
    // checkpoint freshness/provenance boundary.
    assign guarded_restore_valid = checkpoint_restore_accept;

    capu_vcml_store_buffer_v10 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TRANSITION_ID_WIDTH(TRANSITION_ID_WIDTH),
        .PARENT_REF_WIDTH(PARENT_REF_WIDTH),
        .AUTHORIZATION_REF_WIDTH(AUTHORIZATION_REF_WIDTH),
        .POLICY_EPOCH_WIDTH(POLICY_EPOCH_WIDTH),
        .SPENT_AUTHORIZATION_SLOTS(SPENT_AUTHORIZATION_SLOTS),
        .REQUIRE_WRITE_CLASS(REQUIRE_WRITE_CLASS)
    ) inner (
        .clk(clk),
        .rst_n(rst_n),
        .recovery_begin(recovery_begin),
        .restore_valid(guarded_restore_valid),
        .restore_spent_valid(restore_spent_valid),
        .restore_spent_refs(restore_spent_refs),
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
    property p_replay_restore_requires_checkpoint_accept;
        @(posedge clk) disable iff (!rst_n)
            replay_restore_accept |-> checkpoint_restore_accept;
    endproperty
    assert property (p_replay_restore_requires_checkpoint_accept);

    property p_rollback_never_opens_recovery;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_rollback_detected |-> !replay_restore_accept;
    endproperty
    assert property (p_rollback_never_opens_recovery);
`endif

endmodule
