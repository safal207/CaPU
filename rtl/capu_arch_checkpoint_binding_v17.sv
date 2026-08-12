module capu_arch_checkpoint_binding_v17 #(
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16,
    parameter int CHECKPOINT_COMMITMENT_WIDTH = 256,
    parameter int ARCH_EPOCH_WIDTH = 8,
    parameter int PC_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int TRANSITION_ID_WIDTH = 64,
    parameter int AUTHORIZATION_REF_WIDTH = 16,
    parameter int SPENT_AUTHORIZATION_SLOTS = 4,
    // Canonical packed snapshot: recovery epoch, PC, GPR0..3, status,
    // causal head valid/id/GEN/SEAL, spent-valid bits and spent refs.
    parameter int CHECKPOINT_PAYLOAD_WIDTH = ARCH_EPOCH_WIDTH
        + PC_WIDTH + (4 * DATA_WIDTH) + 8
        + 1 + TRANSITION_ID_WIDTH + 4 + 1
        + SPENT_AUTHORIZATION_SLOTS
        + (SPENT_AUTHORIZATION_SLOTS * AUTHORIZATION_REF_WIDTH)
) (
    input logic clk,
    input logic rst_n,

    input logic recovery_begin,
    input logic restore_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] snapshot_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] snapshot_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] snapshot_checkpoint_commitment,
    input logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] snapshot_checkpoint_payload,
    // Trusted off-path verdict over the canonical v0.17 bytes, including all
    // architectural, causal and replay fields represented by the payload.
    input logic snapshot_commitment_verified,

    input logic current_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] current_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] current_anchor_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] current_anchor_commitment,
    input logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] current_anchor_payload,

    input logic checkpoint_prepare_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] candidate_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] candidate_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] candidate_checkpoint_commitment,
    input logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] candidate_checkpoint_payload,
    input logic candidate_commitment_verified,
    // Exact authoritative live record. Speculative state is excluded from the
    // canonical payload and therefore cannot enter checkpoint authority.
    input logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] committed_checkpoint_payload,
    input logic checkpoint_abort,

    input logic snapshot_persisted_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] persisted_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] persisted_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] persisted_checkpoint_commitment,
    input logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] persisted_checkpoint_payload,

    input logic anchor_commit_ack_valid,
    input logic ack_base_anchor_valid,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_base_anchor_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_base_anchor_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_base_anchor_commitment,
    input logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] ack_base_anchor_payload,
    input logic [CHECKPOINT_REF_WIDTH-1:0] ack_checkpoint_ref,
    input logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_checkpoint_epoch,
    input logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_checkpoint_commitment,
    input logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] ack_checkpoint_payload,

    output logic checkpoint_prepare_accept,
    output logic checkpoint_prepare_rejected,
    output logic checkpoint_candidate_pending,
    output logic candidate_payload_rejected,
    output logic checkpoint_snapshot_persist_accept,
    output logic checkpoint_snapshot_persist_rejected,
    output logic checkpoint_snapshot_durable,
    output logic checkpoint_anchor_commit_request,
    output logic checkpoint_anchor_commit_ack_accept,
    output logic checkpoint_anchor_commit_ack_rejected,
    output logic checkpoint_commit_event,

    output logic checkpoint_restore_accept,
    output logic checkpoint_restore_rejected,
    output logic checkpoint_restore_mismatch,
    output logic recovered_checkpoint_ready,
    output logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] recovered_checkpoint_payload,

    output logic checkpoint_request_base_anchor_valid,
    output logic [CHECKPOINT_REF_WIDTH-1:0] checkpoint_request_base_anchor_ref,
    output logic [CHECKPOINT_EPOCH_WIDTH-1:0] checkpoint_request_base_anchor_epoch,
    output logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] checkpoint_request_base_anchor_commitment,
    output logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] checkpoint_request_base_anchor_payload,
    output logic [CHECKPOINT_REF_WIDTH-1:0] checkpoint_request_ref,
    output logic [CHECKPOINT_EPOCH_WIDTH-1:0] checkpoint_request_epoch,
    output logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] checkpoint_request_commitment,
    output logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] checkpoint_request_payload
);

    localparam int EXPECTED_PAYLOAD_WIDTH = ARCH_EPOCH_WIDTH
        + PC_WIDTH + (4 * DATA_WIDTH) + 8
        + 1 + TRANSITION_ID_WIDTH + 4 + 1
        + SPENT_AUTHORIZATION_SLOTS
        + (SPENT_AUTHORIZATION_SLOTS * AUTHORIZATION_REF_WIDTH);

    logic pending_valid;
    logic durable;
    logic pending_base_valid;
    logic [CHECKPOINT_REF_WIDTH-1:0] pending_base_ref;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] pending_base_epoch;
    logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] pending_base_commitment;
    logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] pending_base_payload;
    logic [CHECKPOINT_REF_WIDTH-1:0] pending_ref;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] pending_epoch;
    logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] pending_commitment;
    logic [CHECKPOINT_PAYLOAD_WIDTH-1:0] pending_payload;

    logic anchor_epoch_exhausted;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] expected_candidate_epoch;
    logic candidate_exact_live_state;
    logic candidate_identity_valid;
    logic base_still_current;
    logic persisted_candidate_exact;
    logic ack_base_exact;
    logic ack_candidate_exact;
    logic anchored_snapshot_exact;

    initial begin
        if (CHECKPOINT_PAYLOAD_WIDTH != EXPECTED_PAYLOAD_WIDTH)
            $error("CaPU v0.17 CHECKPOINT_PAYLOAD_WIDTH must match the canonical field vector");
        if (SPENT_AUTHORIZATION_SLOTS < 1)
            $error("CaPU v0.17 requires at least one spent-authorization slot");
    end

    assign anchor_epoch_exhausted = current_anchor_valid && (&current_anchor_epoch);
    assign expected_candidate_epoch = current_anchor_valid
        ? current_anchor_epoch + {{(CHECKPOINT_EPOCH_WIDTH-1){1'b0}}, 1'b1}
        : {{(CHECKPOINT_EPOCH_WIDTH-1){1'b0}}, 1'b1};
    assign candidate_exact_live_state = candidate_checkpoint_payload == committed_checkpoint_payload;
    assign candidate_identity_valid = candidate_checkpoint_ref != '0
        && candidate_checkpoint_commitment != '0
        && candidate_checkpoint_epoch == expected_candidate_epoch;

    assign checkpoint_prepare_accept = checkpoint_prepare_valid
        && !recovery_begin
        && !restore_valid
        && !checkpoint_abort
        && !pending_valid
        && !anchor_epoch_exhausted
        && candidate_identity_valid
        && candidate_commitment_verified
        && candidate_exact_live_state;
    assign checkpoint_prepare_rejected = checkpoint_prepare_valid && !checkpoint_prepare_accept;
    assign candidate_payload_rejected = checkpoint_prepare_valid
        && (!candidate_commitment_verified || !candidate_exact_live_state);

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
        && !recovery_begin
        && !restore_valid
        && !checkpoint_abort
        && !checkpoint_commit_event
        && base_still_current
        && persisted_candidate_exact;
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
        && !recovery_begin
        && !restore_valid
        && !checkpoint_abort
        && checkpoint_anchor_commit_request
        && ack_base_exact
        && ack_candidate_exact;
    assign checkpoint_anchor_commit_ack_rejected = anchor_commit_ack_valid
        && !checkpoint_anchor_commit_ack_accept;
    assign checkpoint_commit_event = checkpoint_anchor_commit_ack_accept;

    assign anchored_snapshot_exact = current_anchor_valid
        && snapshot_commitment_verified
        && snapshot_checkpoint_ref == current_anchor_ref
        && snapshot_checkpoint_epoch == current_anchor_epoch
        && snapshot_checkpoint_commitment == current_anchor_commitment
        && snapshot_checkpoint_payload == current_anchor_payload;
    assign checkpoint_restore_accept = restore_valid
        && !recovery_begin
        && anchored_snapshot_exact;
    assign checkpoint_restore_rejected = restore_valid && !checkpoint_restore_accept;
    assign checkpoint_restore_mismatch = restore_valid && !anchored_snapshot_exact;

    assign checkpoint_request_base_anchor_valid = pending_base_valid;
    assign checkpoint_request_base_anchor_ref = pending_base_ref;
    assign checkpoint_request_base_anchor_epoch = pending_base_epoch;
    assign checkpoint_request_base_anchor_commitment = pending_base_commitment;
    assign checkpoint_request_base_anchor_payload = pending_base_payload;
    assign checkpoint_request_ref = pending_ref;
    assign checkpoint_request_epoch = pending_epoch;
    assign checkpoint_request_commitment = pending_commitment;
    assign checkpoint_request_payload = pending_payload;

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
            recovered_checkpoint_ready <= 1'b0;
            recovered_checkpoint_payload <= '0;
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
                recovered_checkpoint_ready <= 1'b0;
                recovered_checkpoint_payload <= '0;
            end else if (checkpoint_restore_accept) begin
                recovered_checkpoint_ready <= 1'b1;
                recovered_checkpoint_payload <= snapshot_checkpoint_payload;
            end
        end
    end

`ifdef CAPU_ASSERTIONS
    property p_prepare_binds_exact_live_payload;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_prepare_accept
            |-> (candidate_commitment_verified
                 && candidate_checkpoint_payload == committed_checkpoint_payload);
    endproperty
    assert property (p_prepare_binds_exact_live_payload);

    property p_persist_preserves_complete_payload;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_snapshot_persist_accept
            |-> (persisted_checkpoint_payload == checkpoint_request_payload
                 && persisted_checkpoint_commitment == checkpoint_request_commitment);
    endproperty
    assert property (p_persist_preserves_complete_payload);

    property p_authority_commit_preserves_complete_payload;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_commit_event
            |-> (ack_checkpoint_payload == checkpoint_request_payload
                 && ack_checkpoint_commitment == checkpoint_request_commitment
                 && (!checkpoint_request_base_anchor_valid
                     || ack_base_anchor_payload == checkpoint_request_base_anchor_payload));
    endproperty
    assert property (p_authority_commit_preserves_complete_payload);

    property p_restore_requires_exact_bound_snapshot;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_restore_accept |-> anchored_snapshot_exact;
    endproperty
    assert property (p_restore_requires_exact_bound_snapshot);

    property p_mixed_snapshot_fails_closed;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_restore_mismatch |-> !checkpoint_restore_accept;
    endproperty
    assert property (p_mixed_snapshot_fails_closed);

    property p_recovery_has_priority;
        @(posedge clk) disable iff (!rst_n)
            recovery_begin |-> (!checkpoint_restore_accept
                                && !checkpoint_prepare_accept
                                && !checkpoint_snapshot_persist_accept
                                && !checkpoint_commit_event);
    endproperty
    assert property (p_recovery_has_priority);

    property p_restore_is_authority_transition_barrier;
        @(posedge clk) disable iff (!rst_n)
            restore_valid |-> (!checkpoint_prepare_accept
                               && !checkpoint_snapshot_persist_accept
                               && !checkpoint_commit_event);
    endproperty
    assert property (p_restore_is_authority_transition_barrier);

    property p_recovery_or_restore_discards_pending_authority;
        @(posedge clk) disable iff (!rst_n)
            (recovery_begin || restore_valid)
            |=> (!checkpoint_candidate_pending && !checkpoint_snapshot_durable);
    endproperty
    assert property (p_recovery_or_restore_discards_pending_authority);

    property p_restore_loads_exact_snapshot;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_restore_accept
            |=> (recovered_checkpoint_ready
                 && recovered_checkpoint_payload == $past(snapshot_checkpoint_payload));
    endproperty
    assert property (p_restore_loads_exact_snapshot);
`endif

endmodule
