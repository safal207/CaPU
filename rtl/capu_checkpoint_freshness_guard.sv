module capu_checkpoint_freshness_guard #(
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16
) (
    input  logic clk,
    input  logic rst_n,

    input  logic recovery_begin,
    input  logic restore_valid,

    // Trusted upstream decision that the presented checkpoint metadata is
    // bound to the replay snapshot being restored. This is NOT cryptographic
    // verification inside this RTL block.
    input  logic checkpoint_trusted,
    input  logic cold_start_authorized,

    input  logic [CHECKPOINT_REF_WIDTH-1:0] snapshot_checkpoint_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] snapshot_checkpoint_epoch,

    // External monotonic anchor. v0.11 assumes this survives/reset outside the
    // volatile CaPU block; monotonic persistence is not implemented here.
    input  logic anchor_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] anchor_checkpoint_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] anchor_checkpoint_epoch,

    output logic checkpoint_restore_accept,
    output logic checkpoint_restore_rejected,
    output logic checkpoint_rollback_detected,
    output logic checkpoint_anchor_mismatch,
    output logic checkpoint_cold_start_accept
);

    logic anchored_exact_match;
    logic anchored_candidate;
    logic cold_start_candidate;

    initial begin
        if (CHECKPOINT_REF_WIDTH < 1)
            $error("CaPU v0.11 requires CHECKPOINT_REF_WIDTH >= 1");
        if (CHECKPOINT_EPOCH_WIDTH < 1)
            $error("CaPU v0.11 requires CHECKPOINT_EPOCH_WIDTH >= 1");
    end

    assign anchored_candidate = restore_valid
                              && !recovery_begin
                              && anchor_valid
                              && checkpoint_trusted;

    assign anchored_exact_match = anchored_candidate
                                && snapshot_checkpoint_ref != '0
                                && anchor_checkpoint_ref != '0
                                && snapshot_checkpoint_ref == anchor_checkpoint_ref
                                && snapshot_checkpoint_epoch == anchor_checkpoint_epoch;

    assign cold_start_candidate = restore_valid
                                && !recovery_begin
                                && !anchor_valid
                                && cold_start_authorized
                                && snapshot_checkpoint_ref == '0
                                && snapshot_checkpoint_epoch == '0;

    assign checkpoint_cold_start_accept = cold_start_candidate;

    assign checkpoint_restore_accept = anchored_exact_match
                                     || cold_start_candidate;

    assign checkpoint_rollback_detected = anchored_candidate
                                        && snapshot_checkpoint_epoch
                                           < anchor_checkpoint_epoch;

    assign checkpoint_anchor_mismatch = anchored_candidate
                                      && !anchored_exact_match;

    assign checkpoint_restore_rejected = restore_valid
                                       && !checkpoint_restore_accept;

`ifdef CAPU_ASSERTIONS
    property p_recovery_begin_fail_closed;
        @(posedge clk) disable iff (!rst_n)
            recovery_begin |-> !checkpoint_restore_accept;
    endproperty
    assert property (p_recovery_begin_fail_closed);

    property p_rollback_rejected;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_rollback_detected |-> !checkpoint_restore_accept;
    endproperty
    assert property (p_rollback_rejected);

    property p_anchored_restore_exact;
        @(posedge clk) disable iff (!rst_n)
            (checkpoint_restore_accept && anchor_valid)
            |-> (checkpoint_trusted
                 && snapshot_checkpoint_ref != '0
                 && snapshot_checkpoint_ref == anchor_checkpoint_ref
                 && snapshot_checkpoint_epoch == anchor_checkpoint_epoch);
    endproperty
    assert property (p_anchored_restore_exact);

    property p_cold_start_explicit;
        @(posedge clk) disable iff (!rst_n)
            checkpoint_cold_start_accept
            |-> (!anchor_valid
                 && cold_start_authorized
                 && snapshot_checkpoint_ref == '0
                 && snapshot_checkpoint_epoch == '0);
    endproperty
    assert property (p_cold_start_explicit);
`endif

endmodule
