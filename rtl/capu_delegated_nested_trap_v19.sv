module capu_delegated_nested_trap_v19 #(
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16,
    parameter int CHECKPOINT_COMMITMENT_WIDTH = 256,
    parameter int BASE_PAYLOAD_WIDTH = 256,
    parameter int PC_WIDTH = 16,
    parameter int PRIV_WIDTH = 2,
    parameter int CAUSE_WIDTH = 8,
    parameter int DELEGATION_WIDTH = 4,
    parameter int CTX_WIDTH = 1 + 1 + CAUSE_WIDTH + PC_WIDTH + PRIV_WIDTH + PRIV_WIDTH,
    parameter int PAYLOAD_WIDTH = BASE_PAYLOAD_WIDTH + PC_WIDTH + PRIV_WIDTH + DELEGATION_WIDTH + 2 + (2*CTX_WIDTH)
) (
    input logic clk,
    input logic rst_n,

    input logic recovery_begin,
    input logic restore_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] snapshot_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] snapshot_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] snapshot_checkpoint_commitment,
    input logic [PAYLOAD_WIDTH-1:0] snapshot_checkpoint_payload,
    input logic snapshot_commitment_verified,

    input logic [BASE_PAYLOAD_WIDTH-1:0] restore_base_payload,
    input logic [PC_WIDTH-1:0] restore_pc,
    input logic [PRIV_WIDTH-1:0] restore_privilege,
    input logic [DELEGATION_WIDTH-1:0] restore_delegation_mask,
    input logic [1:0] restore_trap_depth,
    input logic restore_ctx0_valid,
    input logic restore_ctx0_is_interrupt,
    input logic [CAUSE_WIDTH-1:0] restore_ctx0_cause,
    input logic [PC_WIDTH-1:0] restore_ctx0_return_pc,
    input logic [PRIV_WIDTH-1:0] restore_ctx0_return_privilege,
    input logic [PRIV_WIDTH-1:0] restore_ctx0_target_privilege,
    input logic restore_ctx1_valid,
    input logic restore_ctx1_is_interrupt,
    input logic [CAUSE_WIDTH-1:0] restore_ctx1_cause,
    input logic [PC_WIDTH-1:0] restore_ctx1_return_pc,
    input logic [PRIV_WIDTH-1:0] restore_ctx1_return_privilege,
    input logic [PRIV_WIDTH-1:0] restore_ctx1_target_privilege,

    input logic current_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] current_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] current_anchor_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] current_anchor_commitment,
    input logic [PAYLOAD_WIDTH-1:0] current_anchor_payload,

    input logic checkpoint_prepare_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] candidate_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] candidate_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] candidate_checkpoint_commitment,
    input logic [PAYLOAD_WIDTH-1:0] candidate_checkpoint_payload,
    input logic candidate_commitment_verified,
    input logic [PAYLOAD_WIDTH-1:0] committed_checkpoint_payload,
    input logic checkpoint_abort,

    input logic snapshot_persisted_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] persisted_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] persisted_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] persisted_checkpoint_commitment,
    input logic [PAYLOAD_WIDTH-1:0] persisted_checkpoint_payload,

    input logic anchor_commit_ack_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_checkpoint_commitment,
    input logic [PAYLOAD_WIDTH-1:0] ack_checkpoint_payload,

    input logic trap_enter_valid,
    input logic trap_is_interrupt,
    input logic [CAUSE_WIDTH-1:0] trap_cause,
    input logic [PC_WIDTH-1:0] trap_vector_pc,
    input logic [PRIV_WIDTH-1:0] trap_target_privilege,
    input logic trap_return_valid,

    input logic normal_step_valid,
    input logic [PC_WIDTH-1:0] normal_next_pc,
    input logic [PRIV_WIDTH-1:0] normal_step_privilege,

    input logic effect_issue_valid,
    input logic effect_commit_valid,

    output logic checkpoint_prepare_accept,
    output logic checkpoint_prepare_rejected,
    output logic checkpoint_snapshot_persist_accept,
    output logic checkpoint_snapshot_persist_rejected,
    output logic checkpoint_anchor_commit_request,
    output logic checkpoint_commit_event,
    output logic checkpoint_candidate_pending,
    output logic checkpoint_snapshot_durable,
    output logic checkpoint_restore_accept,
    output logic checkpoint_restore_rejected,
    output logic checkpoint_restore_mismatch,

    output logic live_execution_ready,
    output logic [PC_WIDTH-1:0] live_pc,
    output logic [PRIV_WIDTH-1:0] live_privilege,
    output logic [DELEGATION_WIDTH-1:0] live_delegation_mask,
    output logic [1:0] live_trap_depth,
    output logic live_ctx0_valid,
    output logic live_ctx0_is_interrupt,
    output logic [CAUSE_WIDTH-1:0] live_ctx0_cause,
    output logic [PC_WIDTH-1:0] live_ctx0_return_pc,
    output logic [PRIV_WIDTH-1:0] live_ctx0_return_privilege,
    output logic [PRIV_WIDTH-1:0] live_ctx0_target_privilege,
    output logic live_ctx1_valid,
    output logic live_ctx1_is_interrupt,
    output logic [CAUSE_WIDTH-1:0] live_ctx1_cause,
    output logic [PC_WIDTH-1:0] live_ctx1_return_pc,
    output logic [PRIV_WIDTH-1:0] live_ctx1_return_privilege,
    output logic [PRIV_WIDTH-1:0] live_ctx1_target_privilege,

    output logic trap_enter_accept,
    output logic delegation_rejected,
    output logic trap_depth_overflow_rejected,
    output logic trap_return_accept,
    output logic trap_return_underflow_rejected,
    output logic normal_step_accept,
    output logic privilege_mismatch_rejected,
    output logic speculative_effect_pending,
    output logic visible_effect,
    output logic speculation_kill,
    output logic [PAYLOAD_WIDTH-1:0] checkpoint_request_payload
);

    logic pending_valid, durable, arch_ready;
    logic [CHECKPOINT_REF_WIDTH-1:0] pending_ref;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] pending_epoch;
    logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] pending_commitment;
    logic [PAYLOAD_WIDTH-1:0] pending_payload;
    logic [PAYLOAD_WIDTH-1:0] restore_exact_payload;
    logic anchor_epoch_exhausted;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] expected_candidate_epoch;
    logic candidate_exact_live_state, persisted_exact, ack_exact, anchored_snapshot_exact;
    logic delegation_allowed, trap_boundary, effect_issue_accept;

    assign restore_exact_payload = {
        restore_base_payload, restore_pc, restore_privilege, restore_delegation_mask,
        restore_trap_depth,
        restore_ctx0_valid, restore_ctx0_is_interrupt, restore_ctx0_cause,
        restore_ctx0_return_pc, restore_ctx0_return_privilege, restore_ctx0_target_privilege,
        restore_ctx1_valid, restore_ctx1_is_interrupt, restore_ctx1_cause,
        restore_ctx1_return_pc, restore_ctx1_return_privilege, restore_ctx1_target_privilege
    };

    assign anchor_epoch_exhausted = current_anchor_valid && (&current_anchor_epoch);
    assign expected_candidate_epoch = current_anchor_valid
        ? current_anchor_epoch + {{(CHECKPOINT_EPOCH_WIDTH-1){1'b0}},1'b1}
        : {{(CHECKPOINT_EPOCH_WIDTH-1){1'b0}},1'b1};
    assign candidate_exact_live_state = candidate_checkpoint_payload == committed_checkpoint_payload;

    assign checkpoint_prepare_accept = checkpoint_prepare_valid && !recovery_begin && !restore_valid
        && !checkpoint_abort && !pending_valid && !anchor_epoch_exhausted
        && candidate_checkpoint_ref != '0 && candidate_checkpoint_commitment != '0
        && candidate_checkpoint_epoch == expected_candidate_epoch
        && candidate_commitment_verified && candidate_exact_live_state;
    assign checkpoint_prepare_rejected = checkpoint_prepare_valid && !checkpoint_prepare_accept;

    assign persisted_exact = pending_valid
        && persisted_checkpoint_ref == pending_ref
        && persisted_checkpoint_epoch == pending_epoch
        && persisted_checkpoint_commitment == pending_commitment
        && persisted_checkpoint_payload == pending_payload;
    assign checkpoint_snapshot_persist_accept = snapshot_persisted_valid && !recovery_begin
        && !restore_valid && !checkpoint_abort && persisted_exact;
    assign checkpoint_snapshot_persist_rejected = snapshot_persisted_valid && !checkpoint_snapshot_persist_accept;
    assign checkpoint_candidate_pending = pending_valid;
    assign checkpoint_snapshot_durable = durable;
    assign checkpoint_anchor_commit_request = pending_valid && durable;

    assign ack_exact = pending_valid
        && ack_checkpoint_ref == pending_ref
        && ack_checkpoint_epoch == pending_epoch
        && ack_checkpoint_commitment == pending_commitment
        && ack_checkpoint_payload == pending_payload;
    assign checkpoint_commit_event = anchor_commit_ack_valid && !recovery_begin && !restore_valid
        && !checkpoint_abort && checkpoint_anchor_commit_request && ack_exact;

    assign anchored_snapshot_exact = current_anchor_valid && snapshot_commitment_verified
        && snapshot_checkpoint_ref == current_anchor_ref
        && snapshot_checkpoint_epoch == current_anchor_epoch
        && snapshot_checkpoint_commitment == current_anchor_commitment
        && snapshot_checkpoint_payload == current_anchor_payload
        && snapshot_checkpoint_payload == restore_exact_payload;
    assign checkpoint_restore_accept = restore_valid && !recovery_begin && anchored_snapshot_exact
        && restore_trap_depth <= 2
        && (restore_trap_depth != 0 || (!restore_ctx0_valid && !restore_ctx1_valid))
        && (restore_trap_depth != 1 || (restore_ctx0_valid && !restore_ctx1_valid))
        && (restore_trap_depth != 2 || (restore_ctx0_valid && restore_ctx1_valid));
    assign checkpoint_restore_rejected = restore_valid && !checkpoint_restore_accept;
    assign checkpoint_restore_mismatch = restore_valid && !anchored_snapshot_exact;
    assign checkpoint_request_payload = pending_payload;

    assign live_execution_ready = arch_ready;
    assign delegation_allowed = live_delegation_mask[trap_target_privilege];
    assign delegation_rejected = trap_enter_valid && live_execution_ready
        && live_trap_depth < 2 && !delegation_allowed;
    assign trap_depth_overflow_rejected = trap_enter_valid && live_execution_ready && live_trap_depth >= 2;
    assign trap_enter_accept = trap_enter_valid && live_execution_ready && !recovery_begin && !restore_valid
        && live_trap_depth < 2 && delegation_allowed;
    assign trap_return_accept = trap_return_valid && live_execution_ready && !recovery_begin && !restore_valid
        && !trap_enter_accept && live_trap_depth != 0;
    assign trap_return_underflow_rejected = trap_return_valid && live_execution_ready && live_trap_depth == 0;
    assign privilege_mismatch_rejected = normal_step_valid && live_execution_ready
        && normal_step_privilege != live_privilege;
    assign normal_step_accept = normal_step_valid && live_execution_ready && !recovery_begin && !restore_valid
        && !trap_enter_accept && !trap_return_accept && normal_step_privilege == live_privilege;

    assign trap_boundary = recovery_begin || restore_valid || trap_enter_accept || trap_return_accept;
    assign speculation_kill = trap_boundary;
    assign effect_issue_accept = effect_issue_valid && live_execution_ready
        && !speculative_effect_pending && !trap_boundary;
    assign visible_effect = effect_commit_valid && speculative_effect_pending && !trap_boundary;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_valid <= 1'b0; durable <= 1'b0;
            pending_ref <= '0; pending_epoch <= '0; pending_commitment <= '0; pending_payload <= '0;
            arch_ready <= 1'b0; live_pc <= '0; live_privilege <= '0; live_delegation_mask <= '0;
            live_trap_depth <= '0;
            live_ctx0_valid <= 1'b0; live_ctx0_is_interrupt <= 1'b0; live_ctx0_cause <= '0;
            live_ctx0_return_pc <= '0; live_ctx0_return_privilege <= '0; live_ctx0_target_privilege <= '0;
            live_ctx1_valid <= 1'b0; live_ctx1_is_interrupt <= 1'b0; live_ctx1_cause <= '0;
            live_ctx1_return_pc <= '0; live_ctx1_return_privilege <= '0; live_ctx1_target_privilege <= '0;
            speculative_effect_pending <= 1'b0;
        end else begin
            if (recovery_begin || restore_valid || checkpoint_abort || checkpoint_commit_event) begin
                pending_valid <= 1'b0; durable <= 1'b0;
            end else if (checkpoint_prepare_accept) begin
                pending_valid <= 1'b1; durable <= 1'b0;
                pending_ref <= candidate_checkpoint_ref; pending_epoch <= candidate_checkpoint_epoch;
                pending_commitment <= candidate_checkpoint_commitment; pending_payload <= candidate_checkpoint_payload;
            end
            if (checkpoint_snapshot_persist_accept) durable <= 1'b1;

            if (recovery_begin) begin
                arch_ready <= 1'b0;
                speculative_effect_pending <= 1'b0;
            end else if (checkpoint_restore_accept) begin
                arch_ready <= 1'b1;
                live_pc <= restore_pc; live_privilege <= restore_privilege;
                live_delegation_mask <= restore_delegation_mask; live_trap_depth <= restore_trap_depth;
                live_ctx0_valid <= restore_ctx0_valid; live_ctx0_is_interrupt <= restore_ctx0_is_interrupt;
                live_ctx0_cause <= restore_ctx0_cause; live_ctx0_return_pc <= restore_ctx0_return_pc;
                live_ctx0_return_privilege <= restore_ctx0_return_privilege; live_ctx0_target_privilege <= restore_ctx0_target_privilege;
                live_ctx1_valid <= restore_ctx1_valid; live_ctx1_is_interrupt <= restore_ctx1_is_interrupt;
                live_ctx1_cause <= restore_ctx1_cause; live_ctx1_return_pc <= restore_ctx1_return_pc;
                live_ctx1_return_privilege <= restore_ctx1_return_privilege; live_ctx1_target_privilege <= restore_ctx1_target_privilege;
                speculative_effect_pending <= 1'b0;
            end else begin
                if (trap_enter_accept) begin
                    if (live_trap_depth == 0) begin
                        live_ctx0_valid <= 1'b1;
                        live_ctx0_is_interrupt <= trap_is_interrupt;
                        live_ctx0_cause <= trap_cause;
                        live_ctx0_return_pc <= live_pc;
                        live_ctx0_return_privilege <= live_privilege;
                        live_ctx0_target_privilege <= trap_target_privilege;
                    end else begin
                        live_ctx1_valid <= 1'b1;
                        live_ctx1_is_interrupt <= trap_is_interrupt;
                        live_ctx1_cause <= trap_cause;
                        live_ctx1_return_pc <= live_pc;
                        live_ctx1_return_privilege <= live_privilege;
                        live_ctx1_target_privilege <= trap_target_privilege;
                    end
                    live_trap_depth <= live_trap_depth + 1'b1;
                    live_pc <= trap_vector_pc;
                    live_privilege <= trap_target_privilege;
                end else if (trap_return_accept) begin
                    if (live_trap_depth == 2) begin
                        live_pc <= live_ctx1_return_pc;
                        live_privilege <= live_ctx1_return_privilege;
                        live_ctx1_valid <= 1'b0;
                        live_trap_depth <= 1;
                    end else begin
                        live_pc <= live_ctx0_return_pc;
                        live_privilege <= live_ctx0_return_privilege;
                        live_ctx0_valid <= 1'b0;
                        live_trap_depth <= 0;
                    end
                end else if (normal_step_accept) begin
                    live_pc <= normal_next_pc;
                end

                if (trap_enter_accept || trap_return_accept)
                    speculative_effect_pending <= 1'b0;
                else if (visible_effect)
                    speculative_effect_pending <= effect_issue_accept;
                else if (effect_issue_accept)
                    speculative_effect_pending <= 1'b1;
            end
        end
    end

`ifdef CAPU_ASSERTIONS
    property p_unauthorized_delegation_rejects;
        @(posedge clk) disable iff (!rst_n)
            delegation_rejected |-> !trap_enter_accept;
    endproperty
    assert property (p_unauthorized_delegation_rejects);

    property p_depth_overflow_rejects;
        @(posedge clk) disable iff (!rst_n)
            trap_depth_overflow_rejected |-> !trap_enter_accept;
    endproperty
    assert property (p_depth_overflow_rejects);

    property p_trap_boundary_no_visible_effect;
        @(posedge clk) disable iff (!rst_n)
            trap_boundary |-> !visible_effect;
    endproperty
    assert property (p_trap_boundary_no_visible_effect);

    property p_recovery_closes_runtime;
        @(posedge clk) disable iff (!rst_n)
            recovery_begin |=> !live_execution_ready;
    endproperty
    assert property (p_recovery_closes_runtime);
`endif
endmodule
