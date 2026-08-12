module capu_checkpoint_content_binding_v13_formal;
    localparam int AUTH_W = 4;
    localparam int SLOTS = 2;
    localparam int REF_W = 3;
    localparam int EPOCH_W = 3;
    localparam int COMMIT_W = 4;

    (* gclk *) reg clk;
    reg rst_n = 1'b0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg recovery_begin;
    (* anyseq *) reg restore_valid;
    (* anyseq *) reg [SLOTS-1:0] restore_spent_valid;
    (* anyseq *) reg [(SLOTS*AUTH_W)-1:0] restore_spent_refs;
    (* anyseq *) reg cold_start_authorized;
    (* anyseq *) reg [REF_W-1:0] snapshot_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] snapshot_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] snapshot_checkpoint_commitment;
    (* anyseq *) reg snapshot_commitment_verified;

    (* anyseq *) reg current_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] current_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] current_anchor_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] current_anchor_commitment;

    (* anyseq *) reg checkpoint_prepare_valid;
    (* anyseq *) reg [REF_W-1:0] candidate_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] candidate_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] candidate_checkpoint_commitment;
    (* anyseq *) reg candidate_commitment_verified;
    (* anyseq *) reg checkpoint_abort;

    (* anyseq *) reg snapshot_persisted_valid;
    (* anyseq *) reg [REF_W-1:0] persisted_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] persisted_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] persisted_checkpoint_commitment;

    (* anyseq *) reg anchor_commit_ack_valid;
    (* anyseq *) reg ack_base_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] ack_base_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_base_anchor_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] ack_base_anchor_commitment;
    (* anyseq *) reg [REF_W-1:0] ack_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] ack_checkpoint_commitment;

    wire derived_commitment_trusted;
    wire restore_commitment_mismatch;
    wire restore_commitment_unverified;
    wire candidate_commitment_rejected;
    wire checkpoint_restore_accept;
    wire checkpoint_restore_rejected;
    wire checkpoint_rollback_detected;
    wire checkpoint_anchor_mismatch;
    wire checkpoint_cold_start_accept;
    wire replay_recovery_ready;
    wire replay_restore_accept;
    wire replay_restore_rejected;
    wire [$clog2(SLOTS+1)-1:0] replay_spent_count;
    wire checkpoint_prepare_accept;
    wire checkpoint_prepare_rejected;
    wire checkpoint_candidate_pending;
    wire checkpoint_snapshot_persist_accept;
    wire checkpoint_snapshot_persist_rejected;
    wire checkpoint_snapshot_durable;
    wire checkpoint_anchor_commit_request;
    wire checkpoint_anchor_commit_ack_accept;
    wire checkpoint_anchor_commit_ack_rejected;
    wire checkpoint_commit_event;
    wire checkpoint_stale_base_detected;
    wire checkpoint_request_base_anchor_valid;
    wire [REF_W-1:0] checkpoint_request_base_anchor_ref;
    wire [EPOCH_W-1:0] checkpoint_request_base_anchor_epoch;
    wire [COMMIT_W-1:0] checkpoint_request_base_anchor_commitment;
    wire [REF_W-1:0] checkpoint_request_ref;
    wire [EPOCH_W-1:0] checkpoint_request_epoch;
    wire [COMMIT_W-1:0] checkpoint_request_commitment;

    capu_checkpoint_content_binding_v13 #(
        .AUTHORIZATION_REF_WIDTH(AUTH_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS),
        .CHECKPOINT_REF_WIDTH(REF_W),
        .CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
        .CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W)
    ) dut (.*);

    reg seen_unverified_prepare_reject = 1'b0;
    reg seen_persist_commitment_reject = 1'b0;
    reg seen_commit_event = 1'b0;
    reg seen_anchored_restore_accept = 1'b0;
    reg seen_restore_commitment_reject = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            seen_unverified_prepare_reject <= 1'b0;
            seen_persist_commitment_reject <= 1'b0;
            seen_commit_event <= 1'b0;
            seen_anchored_restore_accept <= 1'b0;
            seen_restore_commitment_reject <= 1'b0;
        end else begin
            if (checkpoint_prepare_accept) begin
                assert(checkpoint_prepare_valid);
                assert(candidate_commitment_verified);
                assert(candidate_checkpoint_commitment != '0);
            end

            if (checkpoint_prepare_valid
                && (!candidate_commitment_verified || candidate_checkpoint_commitment == '0)) begin
                assert(candidate_commitment_rejected);
                assert(checkpoint_prepare_rejected);
                assert(!checkpoint_prepare_accept);
                seen_unverified_prepare_reject <= 1'b1;
            end

            if (checkpoint_snapshot_persist_accept) begin
                assert(snapshot_persisted_valid);
                assert(persisted_checkpoint_commitment == checkpoint_request_commitment);
                assert(checkpoint_request_commitment != '0);
            end

            if (snapshot_persisted_valid
                && checkpoint_candidate_pending
                && persisted_checkpoint_commitment != checkpoint_request_commitment) begin
                assert(!checkpoint_snapshot_persist_accept);
                assert(checkpoint_snapshot_persist_rejected);
                seen_persist_commitment_reject <= 1'b1;
            end

            if (checkpoint_anchor_commit_request) begin
                assert(checkpoint_candidate_pending);
                assert(checkpoint_snapshot_durable);
                assert(checkpoint_request_commitment != '0);
                if (current_anchor_valid) begin
                    assert(checkpoint_request_base_anchor_valid);
                    assert(checkpoint_request_base_anchor_commitment == current_anchor_commitment);
                end else begin
                    assert(!checkpoint_request_base_anchor_valid);
                    assert(checkpoint_request_base_anchor_commitment == '0);
                end
            end

            if (checkpoint_commit_event) begin
                assert(anchor_commit_ack_valid);
                assert(checkpoint_anchor_commit_ack_accept);
                assert(ack_checkpoint_commitment == checkpoint_request_commitment);
                assert(ack_base_anchor_commitment == checkpoint_request_base_anchor_commitment);
                seen_commit_event <= 1'b1;
            end

            if (checkpoint_restore_accept && current_anchor_valid) begin
                assert(restore_valid);
                assert(snapshot_commitment_verified);
                assert(snapshot_checkpoint_commitment != '0);
                assert(current_anchor_commitment != '0);
                assert(snapshot_checkpoint_commitment == current_anchor_commitment);
                assert(derived_commitment_trusted);
                seen_anchored_restore_accept <= 1'b1;
            end

            if (restore_valid && current_anchor_valid
                && (!snapshot_commitment_verified
                    || snapshot_checkpoint_commitment != current_anchor_commitment)) begin
                assert(!checkpoint_restore_accept);
                assert(checkpoint_restore_rejected);
                seen_restore_commitment_reject <= 1'b1;
            end

            if (restore_commitment_mismatch)
                assert(!checkpoint_restore_accept);
            if (restore_commitment_unverified)
                assert(!checkpoint_restore_accept);

            cover(seen_unverified_prepare_reject);
            cover(seen_persist_commitment_reject);
            cover(seen_commit_event);
            cover(seen_anchored_restore_accept);
            cover(seen_restore_commitment_reject);
        end
    end
endmodule
