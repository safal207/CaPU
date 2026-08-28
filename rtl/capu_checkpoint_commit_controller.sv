module capu_checkpoint_commit_controller #(
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16,
    parameter int CHECKPOINT_STATE_TAG_WIDTH = 32
) (
    input  logic clk,
    input  logic rst_n,

    // Trusted view of the currently authoritative durable anchor.
    input  logic current_anchor_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] current_anchor_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] current_anchor_epoch,
    input  logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] current_anchor_state_tag,

    // Phase 1: prepare a candidate checkpoint against the current anchor.
    input  logic checkpoint_prepare_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] candidate_checkpoint_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] candidate_checkpoint_epoch,
    input  logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] candidate_checkpoint_state_tag,
    input  logic checkpoint_abort,

    // Phase 2: persistence acknowledgement for the exact prepared snapshot.
    input  logic snapshot_persisted_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] persisted_checkpoint_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] persisted_checkpoint_epoch,
    input  logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] persisted_checkpoint_state_tag,

    // Phase 3: acknowledgement from the external durable anchor store. The
    // acknowledgement is expected to represent an atomic compare-and-swap
    // against the base anchor echoed below. CaPU v0.12 does not implement the
    // durable store or cryptographic authentication of this acknowledgement.
    input  logic anchor_commit_ack_valid,
    input  logic ack_base_anchor_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] ack_base_anchor_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_base_anchor_epoch,
    input  logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] ack_base_anchor_state_tag,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] ack_checkpoint_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_checkpoint_epoch,
    input  logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] ack_checkpoint_state_tag,

    output logic prepare_accept,
    output logic prepare_rejected,
    output logic candidate_pending,
    output logic candidate_invalid,
    output logic epoch_exhausted,
    output logic stale_base_detected,

    output logic snapshot_persist_accept,
    output logic snapshot_persist_rejected,
    output logic snapshot_durable,

    output logic anchor_commit_request,
    output logic anchor_commit_ack_accept,
    output logic anchor_commit_ack_rejected,
    output logic checkpoint_commit_event,

    // Compare-and-swap request projected to the external durable anchor store.
    output logic request_base_anchor_valid,
    output logic [CHECKPOINT_REF_WIDTH-1:0] request_base_anchor_ref,
    output logic [CHECKPOINT_EPOCH_WIDTH-1:0] request_base_anchor_epoch,
    output logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] request_base_anchor_state_tag,
    output logic [CHECKPOINT_REF_WIDTH-1:0] request_checkpoint_ref,
    output logic [CHECKPOINT_EPOCH_WIDTH-1:0] request_checkpoint_epoch,
    output logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] request_checkpoint_state_tag
);

    localparam logic [CHECKPOINT_EPOCH_WIDTH-1:0] EPOCH_ONE = {{(CHECKPOINT_EPOCH_WIDTH-1){1'b0}}, 1'b1};
    localparam logic [CHECKPOINT_EPOCH_WIDTH-1:0] EPOCH_MAX = {CHECKPOINT_EPOCH_WIDTH{1'b1}};

    logic pending_base_anchor_valid;
    logic [CHECKPOINT_REF_WIDTH-1:0] pending_base_anchor_ref;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] pending_base_anchor_epoch;
    logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] pending_base_anchor_state_tag;

    logic [CHECKPOINT_REF_WIDTH-1:0] pending_checkpoint_ref;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] pending_checkpoint_epoch;
    logic [CHECKPOINT_STATE_TAG_WIDTH-1:0] pending_checkpoint_state_tag;

    logic current_anchor_well_formed;
    logic expected_epoch_valid;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] expected_candidate_epoch;
    logic base_still_current;
    logic persisted_candidate_exact;
    logic ack_base_exact;
    logic ack_candidate_exact;

    initial begin
        if (CHECKPOINT_REF_WIDTH < 1)
            $error("CaPU v0.12 requires CHECKPOINT_REF_WIDTH >= 1");
        if (CHECKPOINT_EPOCH_WIDTH < 1)
            $error("CaPU v0.12 requires CHECKPOINT_EPOCH_WIDTH >= 1");
        if (CHECKPOINT_STATE_TAG_WIDTH < 1)
            $error("CaPU v0.12 requires CHECKPOINT_STATE_TAG_WIDTH >= 1");
    end

    assign current_anchor_well_formed = !current_anchor_valid
                                      || (current_anchor_ref != '0
                                          && current_anchor_epoch != '0
                                          && current_anchor_state_tag != '0);

    assign epoch_exhausted = current_anchor_valid
                           && current_anchor_epoch == EPOCH_MAX;

    assign expected_epoch_valid = current_anchor_well_formed && !epoch_exhausted;
    assign expected_candidate_epoch = current_anchor_valid
                                    ? current_anchor_epoch + EPOCH_ONE
                                    : EPOCH_ONE;

    assign candidate_invalid = candidate_checkpoint_ref == '0
                            || candidate_checkpoint_state_tag == '0
                            || !expected_epoch_valid
                            || candidate_checkpoint_epoch != expected_candidate_epoch;

    assign prepare_accept = checkpoint_prepare_valid
                         && !checkpoint_abort
                         && !candidate_pending
                         && !candidate_invalid;

    assign prepare_rejected = checkpoint_prepare_valid && !prepare_accept;

    assign base_still_current = candidate_pending
                             && (current_anchor_valid == pending_base_anchor_valid)
                             && (!pending_base_anchor_valid
                                 || (current_anchor_ref == pending_base_anchor_ref
                                     && current_anchor_epoch == pending_base_anchor_epoch
                                     && current_anchor_state_tag == pending_base_anchor_state_tag));

    assign stale_base_detected = candidate_pending && !base_still_current;

    assign persisted_candidate_exact = candidate_pending
                                    && persisted_checkpoint_ref == pending_checkpoint_ref
                                    && persisted_checkpoint_epoch == pending_checkpoint_epoch
                                    && persisted_checkpoint_state_tag == pending_checkpoint_state_tag;

    assign snapshot_persist_accept = snapshot_persisted_valid
                                  && !checkpoint_abort
                                  && candidate_pending
                                  && !snapshot_durable
                                  && base_still_current
                                  && persisted_candidate_exact;

    assign snapshot_persist_rejected = snapshot_persisted_valid
                                    && !snapshot_persist_accept;

    assign request_base_anchor_valid = pending_base_anchor_valid;
    assign request_base_anchor_ref = pending_base_anchor_ref;
    assign request_base_anchor_epoch = pending_base_anchor_epoch;
    assign request_base_anchor_state_tag = pending_base_anchor_state_tag;
    assign request_checkpoint_ref = pending_checkpoint_ref;
    assign request_checkpoint_epoch = pending_checkpoint_epoch;
    assign request_checkpoint_state_tag = pending_checkpoint_state_tag;

    assign anchor_commit_request = candidate_pending
                                && snapshot_durable
                                && base_still_current
                                && !checkpoint_abort;

    assign ack_base_exact = anchor_commit_ack_valid
                         && ack_base_anchor_valid == pending_base_anchor_valid
                         && (!pending_base_anchor_valid
                             ? (ack_base_anchor_ref == '0
                                && ack_base_anchor_epoch == '0
                                && ack_base_anchor_state_tag == '0)
                             : (ack_base_anchor_ref == pending_base_anchor_ref
                                && ack_base_anchor_epoch == pending_base_anchor_epoch
                                && ack_base_anchor_state_tag == pending_base_anchor_state_tag));

    assign ack_candidate_exact = anchor_commit_ack_valid
                              && ack_checkpoint_ref == pending_checkpoint_ref
                              && ack_checkpoint_epoch == pending_checkpoint_epoch
                              && ack_checkpoint_state_tag == pending_checkpoint_state_tag;

    assign anchor_commit_ack_accept = anchor_commit_ack_valid
                                   && anchor_commit_request
                                   && ack_base_exact
                                   && ack_candidate_exact;

    assign anchor_commit_ack_rejected = anchor_commit_ack_valid
                                     && !anchor_commit_ack_accept;

    assign checkpoint_commit_event = anchor_commit_ack_accept;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            candidate_pending <= 1'b0;
            snapshot_durable <= 1'b0;
            pending_base_anchor_valid <= 1'b0;
            pending_base_anchor_ref <= '0;
            pending_base_anchor_epoch <= '0;
            pending_base_anchor_state_tag <= '0;
            pending_checkpoint_ref <= '0;
            pending_checkpoint_epoch <= '0;
            pending_checkpoint_state_tag <= '0;
        end else if (checkpoint_abort || stale_base_detected || anchor_commit_ack_accept) begin
            candidate_pending <= 1'b0;
            snapshot_durable <= 1'b0;
            pending_base_anchor_valid <= 1'b0;
            pending_base_anchor_ref <= '0;
            pending_base_anchor_epoch <= '0;
            pending_base_anchor_state_tag <= '0;
            pending_checkpoint_ref <= '0;
            pending_checkpoint_epoch <= '0;
            pending_checkpoint_state_tag <= '0;
        end else begin
            if (prepare_accept) begin
                candidate_pending <= 1'b1;
                snapshot_durable <= 1'b0;
                pending_base_anchor_valid <= current_anchor_valid;
                pending_base_anchor_ref <= current_anchor_valid ? current_anchor_ref : '0;
                pending_base_anchor_epoch <= current_anchor_valid ? current_anchor_epoch : '0;
                pending_base_anchor_state_tag <= current_anchor_valid ? current_anchor_state_tag : '0;
                pending_checkpoint_ref <= candidate_checkpoint_ref;
                pending_checkpoint_epoch <= candidate_checkpoint_epoch;
                pending_checkpoint_state_tag <= candidate_checkpoint_state_tag;
            end

            if (snapshot_persist_accept)
                snapshot_durable <= 1'b1;
        end
    end

`ifdef CAPU_ASSERTIONS
    property p_commit_requires_durable_snapshot;
        @(posedge clk) disable iff (!rst_n)
            anchor_commit_request |-> (candidate_pending && snapshot_durable && base_still_current);
    endproperty
    assert property (p_commit_requires_durable_snapshot);

    property p_stale_base_blocks_commit;
        @(posedge clk) disable iff (!rst_n)
            stale_base_detected |-> !anchor_commit_request;
    endproperty
    assert property (p_stale_base_blocks_commit);

    property p_commit_event_exact_ack;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_commit_event |-> (anchor_commit_request && ack_base_exact && ack_candidate_exact);
    endproperty
    assert property (p_commit_event_exact_ack);

    property p_invalid_prepare_fails_closed;
        @(posedge clk) disable iff (!rst_n)
            (checkpoint_prepare_valid && candidate_invalid) |-> !prepare_accept;
    endproperty
    assert property (p_invalid_prepare_fails_closed);
`endif

endmodule
