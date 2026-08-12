module capu_checkpoint_freshness_guard_formal;
    localparam int REF_W = 4;
    localparam int EPOCH_W = 4;

    (* gclk *) reg clk;
    reg rst_n = 1'b0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg recovery_begin;
    (* anyseq *) reg restore_valid;
    (* anyseq *) reg checkpoint_trusted;
    (* anyseq *) reg cold_start_authorized;
    (* anyseq *) reg [REF_W-1:0] snapshot_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] snapshot_checkpoint_epoch;
    (* anyseq *) reg anchor_valid;
    (* anyseq *) reg [REF_W-1:0] anchor_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] anchor_checkpoint_epoch;

    wire checkpoint_restore_accept;
    wire checkpoint_restore_rejected;
    wire checkpoint_rollback_detected;
    wire checkpoint_anchor_mismatch;
    wire checkpoint_cold_start_accept;

    capu_checkpoint_freshness_guard #(
        .CHECKPOINT_REF_WIDTH(REF_W),
        .CHECKPOINT_EPOCH_WIDTH(EPOCH_W)
    ) dut (
        .clk(clk), .rst_n(rst_n),
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

    reg seen_exact_anchor_accept = 1'b0;
    reg seen_rollback_reject = 1'b0;
    reg seen_wrong_ref_reject = 1'b0;
    reg seen_untrusted_reject = 1'b0;
    reg seen_cold_start_accept = 1'b0;
    reg seen_unauthorized_cold_start_reject = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            seen_exact_anchor_accept <= 1'b0;
            seen_rollback_reject <= 1'b0;
            seen_wrong_ref_reject <= 1'b0;
            seen_untrusted_reject <= 1'b0;
            seen_cold_start_accept <= 1'b0;
            seen_unauthorized_cold_start_reject <= 1'b0;
        end else begin
            if (checkpoint_restore_accept && anchor_valid) begin
                assert(restore_valid);
                assert(!recovery_begin);
                assert(checkpoint_trusted);
                assert(snapshot_checkpoint_ref != '0);
                assert(anchor_checkpoint_ref != '0);
                assert(snapshot_checkpoint_ref == anchor_checkpoint_ref);
                assert(snapshot_checkpoint_epoch == anchor_checkpoint_epoch);
                seen_exact_anchor_accept <= 1'b1;
            end

            if (checkpoint_restore_accept && !anchor_valid) begin
                assert(cold_start_authorized);
                assert(snapshot_checkpoint_ref == '0);
                assert(snapshot_checkpoint_epoch == '0);
                seen_cold_start_accept <= 1'b1;
            end

            if (recovery_begin)
                assert(!checkpoint_restore_accept);

            if (checkpoint_rollback_detected) begin
                assert(anchor_valid);
                assert(checkpoint_trusted);
                assert(snapshot_checkpoint_epoch < anchor_checkpoint_epoch);
                assert(!checkpoint_restore_accept);
                assert(checkpoint_restore_rejected);
                seen_rollback_reject <= 1'b1;
            end

            if (restore_valid && !recovery_begin && anchor_valid
                && checkpoint_trusted
                && snapshot_checkpoint_epoch == anchor_checkpoint_epoch
                && snapshot_checkpoint_ref != anchor_checkpoint_ref) begin
                assert(checkpoint_anchor_mismatch);
                assert(!checkpoint_restore_accept);
                seen_wrong_ref_reject <= 1'b1;
            end

            if (restore_valid && !recovery_begin && anchor_valid
                && !checkpoint_trusted) begin
                assert(!checkpoint_restore_accept);
                assert(checkpoint_restore_rejected);
                seen_untrusted_reject <= 1'b1;
            end

            if (restore_valid && !recovery_begin && !anchor_valid
                && !cold_start_authorized
                && snapshot_checkpoint_ref == '0
                && snapshot_checkpoint_epoch == '0) begin
                assert(!checkpoint_restore_accept);
                seen_unauthorized_cold_start_reject <= 1'b1;
            end

            if (checkpoint_restore_rejected)
                assert(restore_valid);

            cover(seen_exact_anchor_accept);
            cover(seen_rollback_reject);
            cover(seen_wrong_ref_reject);
            cover(seen_untrusted_reject);
            cover(seen_cold_start_accept);
            cover(seen_unauthorized_cold_start_reject);
        end
    end
endmodule
