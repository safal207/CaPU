module capu_checkpoint_full_state_binding_v14 #(
    parameter int AUTHORIZATION_REF_WIDTH = 16,
    parameter int SPENT_AUTHORIZATION_SLOTS = 4,
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16,
    parameter int CHECKPOINT_COMMITMENT_WIDTH = 256,
    parameter int TRANSITION_ID_WIDTH = 64
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
    input logic snapshot_commitment_verified,
    input logic snapshot_causal_head_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] snapshot_causal_head_transition_id,
    input logic [3:0] snapshot_causal_head_gen,
    input logic snapshot_sealed_chain,

    input logic current_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] current_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] current_anchor_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] current_anchor_commitment,
    input logic current_anchor_causal_head_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] current_anchor_causal_head_transition_id,
    input logic [3:0] current_anchor_causal_head_gen,
    input logic current_anchor_sealed_chain,

    input logic checkpoint_prepare_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] candidate_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] candidate_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] candidate_checkpoint_commitment,
    input logic candidate_commitment_verified,
    input logic candidate_causal_head_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] candidate_causal_head_transition_id,
    input logic [3:0] candidate_causal_head_gen,
    input logic candidate_sealed_chain,

    // Current authoritative committed CaPU causal state. Speculative state is
    // intentionally absent from this interface.
    input logic committed_causal_head_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] committed_causal_head_transition_id,
    input logic [3:0] committed_causal_head_gen,
    input logic committed_sealed_chain,
    input logic checkpoint_abort,

    input logic snapshot_persisted_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] persisted_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] persisted_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] persisted_checkpoint_commitment,
    input logic persisted_causal_head_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] persisted_causal_head_transition_id,
    input logic [3:0] persisted_causal_head_gen,
    input logic persisted_sealed_chain,

    input logic anchor_commit_ack_valid,
    input logic ack_base_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_base_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_base_anchor_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_base_anchor_commitment,
    input logic ack_base_causal_head_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] ack_base_causal_head_transition_id,
    input logic [3:0] ack_base_causal_head_gen,
    input logic ack_base_sealed_chain,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_checkpoint_commitment,
    input logic ack_causal_head_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] ack_causal_head_transition_id,
    input logic [3:0] ack_causal_head_gen,
    input logic ack_sealed_chain,

    output logic full_state_restore_accept,
    output logic full_state_restore_rejected,
    output logic full_state_restore_mismatch,
    output logic candidate_causal_state_rejected,
    output logic persisted_causal_state_rejected,
    output logic ack_causal_state_rejected,

    output logic recovered_causal_state_ready,
    output logic recovered_causal_head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] recovered_causal_head_transition_id,
    output logic [3:0] recovered_causal_head_gen,
    output logic recovered_sealed_chain,

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
    output logic checkpoint_request_base_causal_head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] checkpoint_request_base_causal_head_transition_id,
    output logic [3:0] checkpoint_request_base_causal_head_gen,
    output logic checkpoint_request_base_sealed_chain,
    output logic [CHECKPOINT_REF_WIDTH-1:0] checkpoint_request_ref,
    output logic [CHECKPOINT_EPOCH_WIDTH-1:0] checkpoint_request_epoch,
    output logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] checkpoint_request_commitment,
    output logic checkpoint_request_causal_head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] checkpoint_request_causal_head_transition_id,
    output logic [3:0] checkpoint_request_causal_head_gen,
    output logic checkpoint_request_sealed_chain
);

    logic inner_restore_accept;
    logic inner_restore_rejected;
    logic inner_prepare_accept;
    logic inner_prepare_rejected;
    logic inner_snapshot_persist_accept;
    logic inner_snapshot_persist_rejected;
    logic inner_anchor_ack_accept;
    logic inner_anchor_ack_rejected;
    logic inner_commit_event;
    logic inner_candidate_pending;

    logic unused_derived_commitment_trusted;
    logic unused_restore_commitment_mismatch;
    logic unused_restore_commitment_unverified;
    logic unused_candidate_commitment_rejected;
    logic unused_checkpoint_rollback_detected;
    logic unused_checkpoint_anchor_mismatch;
    logic unused_checkpoint_cold_start_accept;

    logic guarded_restore_valid;
    logic guarded_prepare_valid;
    logic guarded_snapshot_persisted_valid;
    logic guarded_anchor_commit_ack_valid;

    logic snapshot_state_well_formed;
    logic anchor_state_well_formed;
    logic committed_state_well_formed;
    logic candidate_state_well_formed;
    logic persisted_state_well_formed;
    logic ack_state_well_formed;
    logic ack_base_state_well_formed;

    logic snapshot_matches_anchor_state;
    logic candidate_matches_committed_state;
    logic persisted_matches_pending_state;
    logic ack_matches_pending_state;
    logic ack_base_matches_pending_state;
    logic cold_start_causal_empty;

    logic causal_candidate_pending;
    logic pending_causal_head_valid;
    logic [TRANSITION_ID_WIDTH-1:0] pending_causal_head_transition_id;
    logic [3:0] pending_causal_head_gen;
    logic pending_sealed_chain;
    logic pending_base_causal_head_valid;
    logic [TRANSITION_ID_WIDTH-1:0] pending_base_causal_head_transition_id;
    logic [3:0] pending_base_causal_head_gen;
    logic pending_base_sealed_chain;

    initial begin
        if (TRANSITION_ID_WIDTH < 1)
            $error("CaPU v0.14 requires TRANSITION_ID_WIDTH >= 1");
    end

    function automatic logic causal_state_well_formed_fn(
        input logic head_valid,
        input logic [TRANSITION_ID_WIDTH-1:0] head_transition_id,
        input logic [3:0] head_gen,
        input logic sealed_chain
    );
        begin
            causal_state_well_formed_fn = head_valid
                || (head_transition_id == '0 && head_gen == 4'h0 && !sealed_chain);
        end
    endfunction

    assign snapshot_state_well_formed = causal_state_well_formed_fn(
        snapshot_causal_head_valid,
        snapshot_causal_head_transition_id,
        snapshot_causal_head_gen,
        snapshot_sealed_chain);
    assign anchor_state_well_formed = causal_state_well_formed_fn(
        current_anchor_causal_head_valid,
        current_anchor_causal_head_transition_id,
        current_anchor_causal_head_gen,
        current_anchor_sealed_chain);
    assign committed_state_well_formed = causal_state_well_formed_fn(
        committed_causal_head_valid,
        committed_causal_head_transition_id,
        committed_causal_head_gen,
        committed_sealed_chain);
    assign candidate_state_well_formed = causal_state_well_formed_fn(
        candidate_causal_head_valid,
        candidate_causal_head_transition_id,
        candidate_causal_head_gen,
        candidate_sealed_chain);
    assign persisted_state_well_formed = causal_state_well_formed_fn(
        persisted_causal_head_valid,
        persisted_causal_head_transition_id,
        persisted_causal_head_gen,
        persisted_sealed_chain);
    assign ack_state_well_formed = causal_state_well_formed_fn(
        ack_causal_head_valid,
        ack_causal_head_transition_id,
        ack_causal_head_gen,
        ack_sealed_chain);
    assign ack_base_state_well_formed = causal_state_well_formed_fn(
        ack_base_causal_head_valid,
        ack_base_causal_head_transition_id,
        ack_base_causal_head_gen,
        ack_base_sealed_chain);

    assign snapshot_matches_anchor_state = snapshot_state_well_formed
        && anchor_state_well_formed
        && snapshot_causal_head_valid == current_anchor_causal_head_valid
        && snapshot_causal_head_transition_id == current_anchor_causal_head_transition_id
        && snapshot_causal_head_gen == current_anchor_causal_head_gen
        && snapshot_sealed_chain == current_anchor_sealed_chain;

    assign cold_start_causal_empty = snapshot_state_well_formed
        && !snapshot_causal_head_valid
        && snapshot_causal_head_transition_id == '0
        && snapshot_causal_head_gen == 4'h0
        && !snapshot_sealed_chain;

    assign candidate_matches_committed_state = candidate_state_well_formed
        && committed_state_well_formed
        && candidate_causal_head_valid == committed_causal_head_valid
        && candidate_causal_head_transition_id == committed_causal_head_transition_id
        && candidate_causal_head_gen == committed_causal_head_gen
        && candidate_sealed_chain == committed_sealed_chain;

    assign persisted_matches_pending_state = causal_candidate_pending
        && persisted_state_well_formed
        && persisted_causal_head_valid == pending_causal_head_valid
        && persisted_causal_head_transition_id == pending_causal_head_transition_id
        && persisted_causal_head_gen == pending_causal_head_gen
        && persisted_sealed_chain == pending_sealed_chain;

    assign ack_matches_pending_state = causal_candidate_pending
        && ack_state_well_formed
        && ack_causal_head_valid == pending_causal_head_valid
        && ack_causal_head_transition_id == pending_causal_head_transition_id
        && ack_causal_head_gen == pending_causal_head_gen
        && ack_sealed_chain == pending_sealed_chain;

    assign ack_base_matches_pending_state = causal_candidate_pending
        && ack_base_state_well_formed
        && ack_base_causal_head_valid == pending_base_causal_head_valid
        && ack_base_causal_head_transition_id == pending_base_causal_head_transition_id
        && ack_base_causal_head_gen == pending_base_causal_head_gen
        && ack_base_sealed_chain == pending_base_sealed_chain;

    assign guarded_restore_valid = restore_valid
        && (current_anchor_valid ? snapshot_matches_anchor_state : cold_start_causal_empty);

    assign guarded_prepare_valid = checkpoint_prepare_valid
        && candidate_matches_committed_state
        && (!current_anchor_valid || anchor_state_well_formed);

    assign guarded_snapshot_persisted_valid = snapshot_persisted_valid
        && persisted_matches_pending_state;

    assign guarded_anchor_commit_ack_valid = anchor_commit_ack_valid
        && ack_matches_pending_state
        && ack_base_matches_pending_state;

    assign full_state_restore_accept = inner_restore_accept;
    assign full_state_restore_rejected = restore_valid && !inner_restore_accept;
    assign full_state_restore_mismatch = restore_valid
        && current_anchor_valid
        && !snapshot_matches_anchor_state;

    assign candidate_causal_state_rejected = checkpoint_prepare_valid
        && (!candidate_matches_committed_state
            || (current_anchor_valid && !anchor_state_well_formed));
    assign persisted_causal_state_rejected = snapshot_persisted_valid
        && !persisted_matches_pending_state;
    assign ack_causal_state_rejected = anchor_commit_ack_valid
        && (!ack_matches_pending_state || !ack_base_matches_pending_state);

    assign checkpoint_prepare_accept = inner_prepare_accept;
    assign checkpoint_prepare_rejected = checkpoint_prepare_valid && !inner_prepare_accept;
    assign checkpoint_candidate_pending = inner_candidate_pending;
    assign checkpoint_snapshot_persist_accept = inner_snapshot_persist_accept;
    assign checkpoint_snapshot_persist_rejected = snapshot_persisted_valid
        && !inner_snapshot_persist_accept;
    assign checkpoint_anchor_commit_ack_accept = inner_anchor_ack_accept;
    assign checkpoint_anchor_commit_ack_rejected = anchor_commit_ack_valid
        && !inner_anchor_ack_accept;
    assign checkpoint_commit_event = inner_commit_event;

    assign checkpoint_request_base_causal_head_valid = pending_base_causal_head_valid;
    assign checkpoint_request_base_causal_head_transition_id = pending_base_causal_head_transition_id;
    assign checkpoint_request_base_causal_head_gen = pending_base_causal_head_gen;
    assign checkpoint_request_base_sealed_chain = pending_base_sealed_chain;
    assign checkpoint_request_causal_head_valid = pending_causal_head_valid;
    assign checkpoint_request_causal_head_transition_id = pending_causal_head_transition_id;
    assign checkpoint_request_causal_head_gen = pending_causal_head_gen;
    assign checkpoint_request_sealed_chain = pending_sealed_chain;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            causal_candidate_pending <= 1'b0;
            pending_causal_head_valid <= 1'b0;
            pending_causal_head_transition_id <= '0;
            pending_causal_head_gen <= 4'h0;
            pending_sealed_chain <= 1'b0;
            pending_base_causal_head_valid <= 1'b0;
            pending_base_causal_head_transition_id <= '0;
            pending_base_causal_head_gen <= 4'h0;
            pending_base_sealed_chain <= 1'b0;

            recovered_causal_state_ready <= 1'b0;
            recovered_causal_head_valid <= 1'b0;
            recovered_causal_head_transition_id <= '0;
            recovered_causal_head_gen <= 4'h0;
            recovered_sealed_chain <= 1'b0;
        end else begin
            if (checkpoint_abort || inner_commit_event) begin
                causal_candidate_pending <= 1'b0;
            end else if (inner_prepare_accept) begin
                causal_candidate_pending <= 1'b1;
                pending_causal_head_valid <= candidate_causal_head_valid;
                pending_causal_head_transition_id <= candidate_causal_head_transition_id;
                pending_causal_head_gen <= candidate_causal_head_gen;
                pending_sealed_chain <= candidate_sealed_chain;

                if (current_anchor_valid) begin
                    pending_base_causal_head_valid <= current_anchor_causal_head_valid;
                    pending_base_causal_head_transition_id <= current_anchor_causal_head_transition_id;
                    pending_base_causal_head_gen <= current_anchor_causal_head_gen;
                    pending_base_sealed_chain <= current_anchor_sealed_chain;
                end else begin
                    pending_base_causal_head_valid <= 1'b0;
                    pending_base_causal_head_transition_id <= '0;
                    pending_base_causal_head_gen <= 4'h0;
                    pending_base_sealed_chain <= 1'b0;
                end
            end

            if (recovery_begin) begin
                recovered_causal_state_ready <= 1'b0;
                recovered_causal_head_valid <= 1'b0;
                recovered_causal_head_transition_id <= '0;
                recovered_causal_head_gen <= 4'h0;
                recovered_sealed_chain <= 1'b0;
            end else if (inner_restore_accept) begin
                recovered_causal_state_ready <= 1'b1;
                recovered_causal_head_valid <= snapshot_causal_head_valid;
                recovered_causal_head_transition_id <= snapshot_causal_head_transition_id;
                recovered_causal_head_gen <= snapshot_causal_head_gen;
                recovered_sealed_chain <= snapshot_sealed_chain;
            end
        end
    end

    capu_checkpoint_content_binding_v13 #(
        .AUTHORIZATION_REF_WIDTH(AUTHORIZATION_REF_WIDTH),
        .SPENT_AUTHORIZATION_SLOTS(SPENT_AUTHORIZATION_SLOTS),
        .CHECKPOINT_REF_WIDTH(CHECKPOINT_REF_WIDTH),
        .CHECKPOINT_EPOCH_WIDTH(CHECKPOINT_EPOCH_WIDTH),
        .CHECKPOINT_COMMITMENT_WIDTH(CHECKPOINT_COMMITMENT_WIDTH)
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
        .snapshot_checkpoint_commitment(snapshot_checkpoint_commitment),
        .snapshot_commitment_verified(snapshot_commitment_verified),
        .current_anchor_valid(current_anchor_valid),
        .current_anchor_ref(current_anchor_ref),
        .current_anchor_epoch(current_anchor_epoch),
        .current_anchor_commitment(current_anchor_commitment),
        .checkpoint_prepare_valid(guarded_prepare_valid),
        .candidate_checkpoint_ref(candidate_checkpoint_ref),
        .candidate_checkpoint_epoch(candidate_checkpoint_epoch),
        .candidate_checkpoint_commitment(candidate_checkpoint_commitment),
        .candidate_commitment_verified(candidate_commitment_verified),
        .checkpoint_abort(checkpoint_abort),
        .snapshot_persisted_valid(guarded_snapshot_persisted_valid),
        .persisted_checkpoint_ref(persisted_checkpoint_ref),
        .persisted_checkpoint_epoch(persisted_checkpoint_epoch),
        .persisted_checkpoint_commitment(persisted_checkpoint_commitment),
        .anchor_commit_ack_valid(guarded_anchor_commit_ack_valid),
        .ack_base_anchor_valid(ack_base_anchor_valid),
        .ack_base_anchor_ref(ack_base_anchor_ref),
        .ack_base_anchor_epoch(ack_base_anchor_epoch),
        .ack_base_anchor_commitment(ack_base_anchor_commitment),
        .ack_checkpoint_ref(ack_checkpoint_ref),
        .ack_checkpoint_epoch(ack_checkpoint_epoch),
        .ack_checkpoint_commitment(ack_checkpoint_commitment),
        .derived_commitment_trusted(unused_derived_commitment_trusted),
        .restore_commitment_mismatch(unused_restore_commitment_mismatch),
        .restore_commitment_unverified(unused_restore_commitment_unverified),
        .candidate_commitment_rejected(unused_candidate_commitment_rejected),
        .checkpoint_restore_accept(inner_restore_accept),
        .checkpoint_restore_rejected(inner_restore_rejected),
        .checkpoint_rollback_detected(unused_checkpoint_rollback_detected),
        .checkpoint_anchor_mismatch(unused_checkpoint_anchor_mismatch),
        .checkpoint_cold_start_accept(unused_checkpoint_cold_start_accept),
        .replay_recovery_ready(replay_recovery_ready),
        .replay_restore_accept(replay_restore_accept),
        .replay_restore_rejected(replay_restore_rejected),
        .replay_spent_count(replay_spent_count),
        .checkpoint_prepare_accept(inner_prepare_accept),
        .checkpoint_prepare_rejected(inner_prepare_rejected),
        .checkpoint_candidate_pending(inner_candidate_pending),
        .checkpoint_snapshot_persist_accept(inner_snapshot_persist_accept),
        .checkpoint_snapshot_persist_rejected(inner_snapshot_persist_rejected),
        .checkpoint_snapshot_durable(checkpoint_snapshot_durable),
        .checkpoint_anchor_commit_request(checkpoint_anchor_commit_request),
        .checkpoint_anchor_commit_ack_accept(inner_anchor_ack_accept),
        .checkpoint_anchor_commit_ack_rejected(inner_anchor_ack_rejected),
        .checkpoint_commit_event(inner_commit_event),
        .checkpoint_stale_base_detected(checkpoint_stale_base_detected),
        .checkpoint_request_base_anchor_valid(checkpoint_request_base_anchor_valid),
        .checkpoint_request_base_anchor_ref(checkpoint_request_base_anchor_ref),
        .checkpoint_request_base_anchor_epoch(checkpoint_request_base_anchor_epoch),
        .checkpoint_request_base_anchor_commitment(checkpoint_request_base_anchor_commitment),
        .checkpoint_request_ref(checkpoint_request_ref),
        .checkpoint_request_epoch(checkpoint_request_epoch),
        .checkpoint_request_commitment(checkpoint_request_commitment)
    );

`ifdef CAPU_ASSERTIONS
    property p_prepare_captures_committed_causal_state;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_prepare_accept
            |-> (candidate_causal_head_valid == committed_causal_head_valid
                 && candidate_causal_head_transition_id == committed_causal_head_transition_id
                 && candidate_causal_head_gen == committed_causal_head_gen
                 && candidate_sealed_chain == committed_sealed_chain);
    endproperty
    assert property (p_prepare_captures_committed_causal_state);

    property p_persistence_preserves_causal_state;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_snapshot_persist_accept
            |-> (persisted_causal_head_valid == checkpoint_request_causal_head_valid
                 && persisted_causal_head_transition_id == checkpoint_request_causal_head_transition_id
                 && persisted_causal_head_gen == checkpoint_request_causal_head_gen
                 && persisted_sealed_chain == checkpoint_request_sealed_chain);
    endproperty
    assert property (p_persistence_preserves_causal_state);

    property p_anchor_ack_preserves_causal_state;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_commit_event
            |-> (ack_causal_head_valid == checkpoint_request_causal_head_valid
                 && ack_causal_head_transition_id == checkpoint_request_causal_head_transition_id
                 && ack_causal_head_gen == checkpoint_request_causal_head_gen
                 && ack_sealed_chain == checkpoint_request_sealed_chain);
    endproperty
    assert property (p_anchor_ack_preserves_causal_state);

    property p_anchored_restore_requires_exact_causal_state;
        @(posedge clk) disable iff (!rst_n)
            (full_state_restore_accept && current_anchor_valid)
            |-> snapshot_matches_anchor_state;
    endproperty
    assert property (p_anchored_restore_requires_exact_causal_state);

    property p_causal_mismatch_fails_closed;
        @(posedge clk) disable iff (!rst_n)
            full_state_restore_mismatch |-> !full_state_restore_accept;
    endproperty
    assert property (p_causal_mismatch_fails_closed);
`endif

endmodule
