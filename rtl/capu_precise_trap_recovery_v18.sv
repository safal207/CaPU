module capu_precise_trap_recovery_v18 #(
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16,
    parameter int CHECKPOINT_COMMITMENT_WIDTH = 256,
    parameter int BASE_PAYLOAD_WIDTH = 256,
    parameter int PC_WIDTH = 16,
    parameter int PRIV_WIDTH = 2,
    parameter int CAUSE_WIDTH = 8,
    parameter int TRAP_PAYLOAD_WIDTH = BASE_PAYLOAD_WIDTH + PRIV_WIDTH + 1 + 1
        + CAUSE_WIDTH + PC_WIDTH + PRIV_WIDTH + 1
) (
    input logic clk,
    input logic rst_n,

    input logic recovery_begin,
    input logic restore_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] snapshot_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] snapshot_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] snapshot_checkpoint_commitment,
    input logic [TRAP_PAYLOAD_WIDTH-1:0] snapshot_checkpoint_payload,
    input logic snapshot_commitment_verified,

    // Explicit restore fields are re-packed and must equal the anchored payload.
    input logic [BASE_PAYLOAD_WIDTH-1:0] restore_base_payload,
    input logic [PC_WIDTH-1:0] restore_pc,
    input logic [PRIV_WIDTH-1:0] restore_privilege_mode,
    input logic restore_trap_pending,
    input logic restore_trap_is_interrupt,
    input logic [CAUSE_WIDTH-1:0] restore_trap_cause,
    input logic [PC_WIDTH-1:0] restore_trap_return_pc,
    input logic [PRIV_WIDTH-1:0] restore_trap_return_privilege,
    input logic restore_interrupt_mask,

    input logic current_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] current_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] current_anchor_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] current_anchor_commitment,
    input logic [TRAP_PAYLOAD_WIDTH-1:0] current_anchor_payload,

    input logic checkpoint_prepare_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] candidate_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] candidate_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] candidate_checkpoint_commitment,
    input logic [TRAP_PAYLOAD_WIDTH-1:0] candidate_checkpoint_payload,
    input logic candidate_commitment_verified,
    input logic [TRAP_PAYLOAD_WIDTH-1:0] committed_checkpoint_payload,
    input logic checkpoint_abort,

    input logic snapshot_persisted_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] persisted_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] persisted_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] persisted_checkpoint_commitment,
    input logic [TRAP_PAYLOAD_WIDTH-1:0] persisted_checkpoint_payload,

    input logic anchor_commit_ack_valid,
    input logic ack_base_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_base_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_base_anchor_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_base_anchor_commitment,
    input logic [TRAP_PAYLOAD_WIDTH-1:0] ack_base_anchor_payload,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_checkpoint_commitment,
    input logic [TRAP_PAYLOAD_WIDTH-1:0] ack_checkpoint_payload,

    // Minimal resumed architectural/trap execution surface.
    input logic normal_step_valid,
    input logic [PC_WIDTH-1:0] normal_next_pc,
    input logic [PRIV_WIDTH-1:0] normal_step_privilege,

    input logic exception_valid,
    input logic [CAUSE_WIDTH-1:0] exception_cause,
    input logic [PC_WIDTH-1:0] exception_vector_pc,
    input logic [PRIV_WIDTH-1:0] exception_target_privilege,

    input logic interrupt_valid,
    input logic [CAUSE_WIDTH-1:0] interrupt_cause,
    input logic [PC_WIDTH-1:0] interrupt_vector_pc,
    input logic [PRIV_WIDTH-1:0] interrupt_target_privilege,

    input logic trap_return_valid,

    // One-entry visible-effect model used only to prove boundary precision.
    input logic effect_issue_valid,
    input logic effect_commit_valid,

    output logic checkpoint_prepare_accept,
    output logic checkpoint_prepare_rejected,
    output logic checkpoint_snapshot_persist_accept,
    output logic checkpoint_snapshot_persist_rejected,
    output logic checkpoint_anchor_commit_request,
    output logic checkpoint_anchor_commit_ack_accept,
    output logic checkpoint_anchor_commit_ack_rejected,
    output logic checkpoint_commit_event,
    output logic checkpoint_candidate_pending,
    output logic checkpoint_snapshot_durable,

    output logic checkpoint_restore_accept,
    output logic checkpoint_restore_rejected,
    output logic checkpoint_restore_mismatch,

    output logic live_execution_ready,
    output logic [PC_WIDTH-1:0] live_pc,
    output logic [PRIV_WIDTH-1:0] live_privilege_mode,
    output logic live_trap_pending,
    output logic live_trap_is_interrupt,
    output logic [CAUSE_WIDTH-1:0] live_trap_cause,
    output logic [PC_WIDTH-1:0] live_trap_return_pc,
    output logic [PRIV_WIDTH-1:0] live_trap_return_privilege,
    output logic live_interrupt_mask,
    output logic [BASE_PAYLOAD_WIDTH-1:0] live_base_payload,

    output logic normal_step_accept,
    output logic normal_step_rejected,
    output logic trap_enter_accept,
    output logic trap_return_accept,
    output logic privilege_mismatch_rejected,
    output logic masked_interrupt_rejected,

    output logic speculative_effect_pending,
    output logic visible_effect,
    output logic speculation_kill,

    output logic [TRAP_PAYLOAD_WIDTH-1:0] checkpoint_request_payload
);

    logic pending_valid;
    logic durable;
    logic pending_base_valid;
    logic [CHECKPOINT_REF_WIDTH-1:0] pending_base_ref;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] pending_base_epoch;
    logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] pending_base_commitment;
    logic [TRAP_PAYLOAD_WIDTH-1:0] pending_base_payload;
    logic [CHECKPOINT_REF_WIDTH-1:0] pending_ref;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] pending_epoch;
    logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] pending_commitment;
    logic [TRAP_PAYLOAD_WIDTH-1:0] pending_payload;

    logic anchor_epoch_exhausted;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] expected_candidate_epoch;
    logic candidate_exact_live_state;
    logic candidate_identity_valid;
    logic base_still_current;
    logic persisted_candidate_exact;
    logic ack_base_exact;
    logic ack_candidate_exact;
    logic anchored_snapshot_exact;
    logic [TRAP_PAYLOAD_WIDTH-1:0] restore_exact_payload;

    logic arch_ready;
    logic exception_take;
    logic interrupt_take;
    logic trap_boundary;
    logic effect_issue_accept;

    assign restore_exact_payload = {
        restore_base_payload,
        restore_pc,
        restore_privilege_mode,
        restore_trap_pending,
        restore_trap_is_interrupt,
        restore_trap_cause,
        restore_trap_return_pc,
        restore_trap_return_privilege,
        restore_interrupt_mask
    };

    assign anchor_epoch_exhausted = current_anchor_valid && (&current_anchor_epoch);
    assign expected_candidate_epoch = current_anchor_valid
        ? current_anchor_epoch + {{(CHECKPOINT_EPOCH_WIDTH-1){1'b0}}, 1'b1}
        : {{(CHECKPOINT_EPOCH_WIDTH-1){1'b0}}, 1'b1};
    assign candidate_exact_live_state = candidate_checkpoint_payload == committed_checkpoint_payload;
    assign candidate_identity_valid = candidate_checkpoint_ref != '0
        && candidate_checkpoint_commitment != '0
        && candidate_checkpoint_epoch == expected_candidate_epoch;

    assign checkpoint_prepare_accept = checkpoint_prepare_valid
        && !recovery_begin && !restore_valid && !checkpoint_abort
        && !pending_valid && !anchor_epoch_exhausted
        && candidate_identity_valid && candidate_commitment_verified
        && candidate_exact_live_state;
    assign checkpoint_prepare_rejected = checkpoint_prepare_valid && !checkpoint_prepare_accept;

    assign base_still_current = pending_valid
        && current_anchor_valid == pending_base_valid
        && (!pending_base_valid
            || (current_anchor_ref == pending_base_ref
                && current_anchor_epoch == pending_base_epoch
                && current_anchor_commitment == pending_base_commitment
                && current_anchor_payload == pending_base_payload));

    assign persisted_candidate_exact = pending_valid
        && persisted_checkpoint_ref == pending_ref
        && persisted_checkpoint_epoch == pending_epoch
        && persisted_checkpoint_commitment == pending_commitment
        && persisted_checkpoint_payload == pending_payload;
    assign checkpoint_snapshot_persist_accept = snapshot_persisted_valid
        && !recovery_begin && !restore_valid && !checkpoint_abort
        && !checkpoint_commit_event && base_still_current && persisted_candidate_exact;
    assign checkpoint_snapshot_persist_rejected = snapshot_persisted_valid
        && !checkpoint_snapshot_persist_accept;

    assign checkpoint_candidate_pending = pending_valid;
    assign checkpoint_snapshot_durable = durable;
    assign checkpoint_anchor_commit_request = pending_valid && durable && base_still_current;

    assign ack_base_exact = pending_valid
        && ack_base_anchor_valid == pending_base_valid
        && (!pending_base_valid
            || (ack_base_anchor_ref == pending_base_ref
                && ack_base_anchor_epoch == pending_base_epoch
                && ack_base_anchor_commitment == pending_base_commitment
                && ack_base_anchor_payload == pending_base_payload));
    assign ack_candidate_exact = pending_valid
        && ack_checkpoint_ref == pending_ref
        && ack_checkpoint_epoch == pending_epoch
        && ack_checkpoint_commitment == pending_commitment
        && ack_checkpoint_payload == pending_payload;
    assign checkpoint_anchor_commit_ack_accept = anchor_commit_ack_valid
        && !recovery_begin && !restore_valid && !checkpoint_abort
        && checkpoint_anchor_commit_request && ack_base_exact && ack_candidate_exact;
    assign checkpoint_anchor_commit_ack_rejected = anchor_commit_ack_valid
        && !checkpoint_anchor_commit_ack_accept;
    assign checkpoint_commit_event = checkpoint_anchor_commit_ack_accept;

    assign anchored_snapshot_exact = current_anchor_valid
        && snapshot_commitment_verified
        && snapshot_checkpoint_ref == current_anchor_ref
        && snapshot_checkpoint_epoch == current_anchor_epoch
        && snapshot_checkpoint_commitment == current_anchor_commitment
        && snapshot_checkpoint_payload == current_anchor_payload
        && snapshot_checkpoint_payload == restore_exact_payload;
    assign checkpoint_restore_accept = restore_valid && !recovery_begin && anchored_snapshot_exact;
    assign checkpoint_restore_rejected = restore_valid && !checkpoint_restore_accept;
    assign checkpoint_restore_mismatch = restore_valid && !anchored_snapshot_exact;

    assign checkpoint_request_payload = pending_payload;

    // Exception has strict priority over interrupt. Nested traps are outside v0.18.
    assign exception_take = exception_valid && live_execution_ready && !live_trap_pending
        && !recovery_begin && !restore_valid;
    assign interrupt_take = !exception_take && interrupt_valid && live_execution_ready
        && !live_trap_pending && !live_interrupt_mask
        && !recovery_begin && !restore_valid;
    assign trap_enter_accept = exception_take || interrupt_take;
    assign masked_interrupt_rejected = interrupt_valid && live_execution_ready
        && !live_trap_pending && live_interrupt_mask && !exception_take;

    assign trap_return_accept = trap_return_valid && live_execution_ready && live_trap_pending
        && !trap_enter_accept && !recovery_begin && !restore_valid;

    assign privilege_mismatch_rejected = normal_step_valid && live_execution_ready
        && normal_step_privilege != live_privilege_mode;
    assign normal_step_accept = normal_step_valid && live_execution_ready
        && !recovery_begin && !restore_valid
        && !trap_enter_accept && !trap_return_accept
        && normal_step_privilege == live_privilege_mode;
    assign normal_step_rejected = normal_step_valid && !normal_step_accept;

    assign trap_boundary = recovery_begin || restore_valid || trap_enter_accept;
    assign speculation_kill = trap_boundary;
    assign effect_issue_accept = effect_issue_valid && live_execution_ready
        && !speculative_effect_pending && !trap_boundary;
    assign visible_effect = effect_commit_valid && speculative_effect_pending && !trap_boundary;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_valid <= 1'b0;
            durable <= 1'b0;
            pending_base_valid <= 1'b0;
            pending_base_ref <= '0;
            pending_base_epoch <= '0;
            pending_base_commitment <= '0;
            pending_base_payload <= '0;
            pending_ref <= '0;
            pending_epoch <= '0;
            pending_commitment <= '0;
            pending_payload <= '0;

            arch_ready <= 1'b0;
            live_pc <= '0;
            live_privilege_mode <= '0;
            live_trap_pending <= 1'b0;
            live_trap_is_interrupt <= 1'b0;
            live_trap_cause <= '0;
            live_trap_return_pc <= '0;
            live_trap_return_privilege <= '0;
            live_interrupt_mask <= 1'b0;
            live_base_payload <= '0;
            speculative_effect_pending <= 1'b0;
        end else begin
            if (recovery_begin || restore_valid || checkpoint_abort || checkpoint_commit_event) begin
                pending_valid <= 1'b0;
                durable <= 1'b0;
            end else if (checkpoint_prepare_accept) begin
                pending_valid <= 1'b1;
                durable <= 1'b0;
                pending_base_valid <= current_anchor_valid;
                pending_base_ref <= current_anchor_valid ? current_anchor_ref : '0;
                pending_base_epoch <= current_anchor_valid ? current_anchor_epoch : '0;
                pending_base_commitment <= current_anchor_valid ? current_anchor_commitment : '0;
                pending_base_payload <= current_anchor_valid ? current_anchor_payload : '0;
                pending_ref <= candidate_checkpoint_ref;
                pending_epoch <= candidate_checkpoint_epoch;
                pending_commitment <= candidate_checkpoint_commitment;
                pending_payload <= candidate_checkpoint_payload;
            end
            if (checkpoint_snapshot_persist_accept)
                durable <= 1'b1;

            if (recovery_begin) begin
                arch_ready <= 1'b0;
                speculative_effect_pending <= 1'b0;
            end else if (checkpoint_restore_accept) begin
                arch_ready <= 1'b1;
                live_base_payload <= restore_base_payload;
                live_pc <= restore_pc;
                live_privilege_mode <= restore_privilege_mode;
                live_trap_pending <= restore_trap_pending;
                live_trap_is_interrupt <= restore_trap_is_interrupt;
                live_trap_cause <= restore_trap_cause;
                live_trap_return_pc <= restore_trap_return_pc;
                live_trap_return_privilege <= restore_trap_return_privilege;
                live_interrupt_mask <= restore_interrupt_mask;
                speculative_effect_pending <= 1'b0;
            end else begin
                if (trap_enter_accept) begin
                    live_trap_pending <= 1'b1;
                    live_trap_is_interrupt <= interrupt_take;
                    live_trap_cause <= exception_take ? exception_cause : interrupt_cause;
                    live_trap_return_pc <= live_pc;
                    live_trap_return_privilege <= live_privilege_mode;
                    live_pc <= exception_take ? exception_vector_pc : interrupt_vector_pc;
                    live_privilege_mode <= exception_take
                        ? exception_target_privilege : interrupt_target_privilege;
                end else if (trap_return_accept) begin
                    live_pc <= live_trap_return_pc;
                    live_privilege_mode <= live_trap_return_privilege;
                    live_trap_pending <= 1'b0;
                    live_trap_is_interrupt <= 1'b0;
                    live_trap_cause <= '0;
                end else if (normal_step_accept) begin
                    live_pc <= normal_next_pc;
                end

                if (trap_enter_accept)
                    speculative_effect_pending <= 1'b0;
                else if (visible_effect)
                    speculative_effect_pending <= effect_issue_accept;
                else if (effect_issue_accept)
                    speculative_effect_pending <= 1'b1;
            end
        end
    end

    assign live_execution_ready = arch_ready;

`ifdef CAPU_ASSERTIONS
    property p_restore_exact_payload;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_restore_accept |-> (snapshot_checkpoint_payload == restore_exact_payload);
    endproperty
    assert property (p_restore_exact_payload);

    property p_recovery_closes_runtime;
        @(posedge clk) disable iff (!rst_n)
            recovery_begin |=> !live_execution_ready;
    endproperty
    assert property (p_recovery_closes_runtime);

    property p_exception_priority;
        @(posedge clk) disable iff (!rst_n)
            exception_take |-> (trap_enter_accept && !interrupt_take);
    endproperty
    assert property (p_exception_priority);

    property p_masked_interrupt_fails_closed;
        @(posedge clk) disable iff (!rst_n)
            masked_interrupt_rejected |-> !interrupt_take;
    endproperty
    assert property (p_masked_interrupt_fails_closed);

    property p_privilege_mismatch_fails_closed;
        @(posedge clk) disable iff (!rst_n)
            privilege_mismatch_rejected |-> !normal_step_accept;
    endproperty
    assert property (p_privilege_mismatch_fails_closed);

    property p_trap_is_precise_visible_effect_barrier;
        @(posedge clk) disable iff (!rst_n)
            trap_enter_accept |-> (!visible_effect && speculation_kill);
    endproperty
    assert property (p_trap_is_precise_visible_effect_barrier);

    property p_pretrap_speculation_does_not_survive;
        @(posedge clk) disable iff (!rst_n)
            trap_enter_accept |=> !speculative_effect_pending;
    endproperty
    assert property (p_pretrap_speculation_does_not_survive);

    property p_trap_entry_captures_return_context;
        @(posedge clk) disable iff (!rst_n)
            trap_enter_accept |=> (live_trap_pending
                && live_trap_return_pc == $past(live_pc)
                && live_trap_return_privilege == $past(live_privilege_mode));
    endproperty
    assert property (p_trap_entry_captures_return_context);

    property p_restore_or_recovery_discards_authority;
        @(posedge clk) disable iff (!rst_n)
            (restore_valid || recovery_begin)
            |=> (!checkpoint_candidate_pending && !checkpoint_snapshot_durable);
    endproperty
    assert property (p_restore_or_recovery_discards_authority);
`endif

endmodule
