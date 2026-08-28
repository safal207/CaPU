module capu_checkpoint_full_state_binding_v14_formal;
    localparam int AUTH_W = 4;
    localparam int SLOTS = 2;
    localparam int REF_W = 3;
    localparam int EPOCH_W = 3;
    localparam int COMMIT_W = 4;
    localparam int TID_W = 4;

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
    (* anyseq *) reg snapshot_causal_head_valid;
    (* anyseq *) reg [TID_W-1:0] snapshot_causal_head_transition_id;
    (* anyseq *) reg [3:0] snapshot_causal_head_gen;
    (* anyseq *) reg snapshot_sealed_chain;

    (* anyseq *) reg current_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] current_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] current_anchor_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] current_anchor_commitment;
    (* anyseq *) reg current_anchor_causal_head_valid;
    (* anyseq *) reg [TID_W-1:0] current_anchor_causal_head_transition_id;
    (* anyseq *) reg [3:0] current_anchor_causal_head_gen;
    (* anyseq *) reg current_anchor_sealed_chain;

    (* anyseq *) reg checkpoint_prepare_valid;
    (* anyseq *) reg [REF_W-1:0] candidate_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] candidate_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] candidate_checkpoint_commitment;
    (* anyseq *) reg candidate_commitment_verified;
    (* anyseq *) reg candidate_causal_head_valid;
    (* anyseq *) reg [TID_W-1:0] candidate_causal_head_transition_id;
    (* anyseq *) reg [3:0] candidate_causal_head_gen;
    (* anyseq *) reg candidate_sealed_chain;
    (* anyseq *) reg committed_causal_head_valid;
    (* anyseq *) reg [TID_W-1:0] committed_causal_head_transition_id;
    (* anyseq *) reg [3:0] committed_causal_head_gen;
    (* anyseq *) reg committed_sealed_chain;
    (* anyseq *) reg checkpoint_abort;

    (* anyseq *) reg snapshot_persisted_valid;
    (* anyseq *) reg [REF_W-1:0] persisted_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] persisted_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] persisted_checkpoint_commitment;
    (* anyseq *) reg persisted_causal_head_valid;
    (* anyseq *) reg [TID_W-1:0] persisted_causal_head_transition_id;
    (* anyseq *) reg [3:0] persisted_causal_head_gen;
    (* anyseq *) reg persisted_sealed_chain;

    (* anyseq *) reg anchor_commit_ack_valid;
    (* anyseq *) reg ack_base_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] ack_base_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_base_anchor_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] ack_base_anchor_commitment;
    (* anyseq *) reg ack_base_causal_head_valid;
    (* anyseq *) reg [TID_W-1:0] ack_base_causal_head_transition_id;
    (* anyseq *) reg [3:0] ack_base_causal_head_gen;
    (* anyseq *) reg ack_base_sealed_chain;
    (* anyseq *) reg [REF_W-1:0] ack_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] ack_checkpoint_commitment;
    (* anyseq *) reg ack_causal_head_valid;
    (* anyseq *) reg [TID_W-1:0] ack_causal_head_transition_id;
    (* anyseq *) reg [3:0] ack_causal_head_gen;
    (* anyseq *) reg ack_sealed_chain;

    wire full_state_restore_accept;
    wire full_state_restore_rejected;
    wire full_state_restore_mismatch;
    wire candidate_causal_state_rejected;
    wire persisted_causal_state_rejected;
    wire ack_causal_state_rejected;
    wire recovered_causal_state_ready;
    wire recovered_causal_head_valid;
    wire [TID_W-1:0] recovered_causal_head_transition_id;
    wire [3:0] recovered_causal_head_gen;
    wire recovered_sealed_chain;
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
    wire checkpoint_request_base_causal_head_valid;
    wire [TID_W-1:0] checkpoint_request_base_causal_head_transition_id;
    wire [3:0] checkpoint_request_base_causal_head_gen;
    wire checkpoint_request_base_sealed_chain;
    wire [REF_W-1:0] checkpoint_request_ref;
    wire [EPOCH_W-1:0] checkpoint_request_epoch;
    wire [COMMIT_W-1:0] checkpoint_request_commitment;
    wire checkpoint_request_causal_head_valid;
    wire [TID_W-1:0] checkpoint_request_causal_head_transition_id;
    wire [3:0] checkpoint_request_causal_head_gen;
    wire checkpoint_request_sealed_chain;

    capu_checkpoint_full_state_binding_v14 #(
        .AUTHORIZATION_REF_WIDTH(AUTH_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS),
        .CHECKPOINT_REF_WIDTH(REF_W),
        .CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
        .CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W),
        .TRANSITION_ID_WIDTH(TID_W)
    ) dut (.*);

    reg seen_candidate_mismatch_reject = 1'b0;
    reg seen_persist_mismatch_reject = 1'b0;
    reg seen_ack_mismatch_reject = 1'b0;
    reg seen_commit_event = 1'b0;
    reg seen_anchored_restore_accept = 1'b0;
    reg seen_restore_causal_reject = 1'b0;
    reg seen_recovered_exact = 1'b0;

    reg expect_recovered = 1'b0;
    reg expected_head_valid = 1'b0;
    reg [TID_W-1:0] expected_head_id = '0;
    reg [3:0] expected_head_gen = '0;
    reg expected_seal = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            seen_candidate_mismatch_reject <= 1'b0;
            seen_persist_mismatch_reject <= 1'b0;
            seen_ack_mismatch_reject <= 1'b0;
            seen_commit_event <= 1'b0;
            seen_anchored_restore_accept <= 1'b0;
            seen_restore_causal_reject <= 1'b0;
            seen_recovered_exact <= 1'b0;
            expect_recovered <= 1'b0;
        end else begin
            if (expect_recovered) begin
                assert(recovered_causal_state_ready);
                assert(recovered_causal_head_valid == expected_head_valid);
                assert(recovered_causal_head_transition_id == expected_head_id);
                assert(recovered_causal_head_gen == expected_head_gen);
                assert(recovered_sealed_chain == expected_seal);
                seen_recovered_exact <= 1'b1;
                expect_recovered <= 1'b0;
            end

            if (checkpoint_prepare_accept) begin
                assert(checkpoint_prepare_valid);
                assert(candidate_commitment_verified);
                assert(candidate_checkpoint_commitment != '0);
                assert(candidate_causal_head_valid == committed_causal_head_valid);
                assert(candidate_causal_head_transition_id == committed_causal_head_transition_id);
                assert(candidate_causal_head_gen == committed_causal_head_gen);
                assert(candidate_sealed_chain == committed_sealed_chain);
            end

            if (checkpoint_prepare_valid && candidate_causal_state_rejected) begin
                assert(!checkpoint_prepare_accept);
                assert(checkpoint_prepare_rejected);
                seen_candidate_mismatch_reject <= 1'b1;
            end

            if (checkpoint_snapshot_persist_accept) begin
                assert(snapshot_persisted_valid);
                assert(persisted_causal_head_valid == checkpoint_request_causal_head_valid);
                assert(persisted_causal_head_transition_id == checkpoint_request_causal_head_transition_id);
                assert(persisted_causal_head_gen == checkpoint_request_causal_head_gen);
                assert(persisted_sealed_chain == checkpoint_request_sealed_chain);
                assert(persisted_checkpoint_commitment == checkpoint_request_commitment);
            end

            if (snapshot_persisted_valid && persisted_causal_state_rejected) begin
                assert(!checkpoint_snapshot_persist_accept);
                assert(checkpoint_snapshot_persist_rejected);
                seen_persist_mismatch_reject <= 1'b1;
            end

            if (checkpoint_anchor_commit_request) begin
                assert(checkpoint_candidate_pending);
                assert(checkpoint_snapshot_durable);
                assert(checkpoint_request_commitment != '0);
            end

            if (checkpoint_commit_event) begin
                assert(anchor_commit_ack_valid);
                assert(checkpoint_anchor_commit_ack_accept);
                assert(ack_causal_head_valid == checkpoint_request_causal_head_valid);
                assert(ack_causal_head_transition_id == checkpoint_request_causal_head_transition_id);
                assert(ack_causal_head_gen == checkpoint_request_causal_head_gen);
                assert(ack_sealed_chain == checkpoint_request_sealed_chain);
                assert(ack_base_causal_head_valid == checkpoint_request_base_causal_head_valid);
                assert(ack_base_causal_head_transition_id == checkpoint_request_base_causal_head_transition_id);
                assert(ack_base_causal_head_gen == checkpoint_request_base_causal_head_gen);
                assert(ack_base_sealed_chain == checkpoint_request_base_sealed_chain);
                seen_commit_event <= 1'b1;
            end

            if (anchor_commit_ack_valid && ack_causal_state_rejected) begin
                assert(!checkpoint_commit_event);
                assert(checkpoint_anchor_commit_ack_rejected);
                seen_ack_mismatch_reject <= 1'b1;
            end

            if (full_state_restore_accept && current_anchor_valid) begin
                assert(restore_valid);
                assert(snapshot_commitment_verified);
                assert(snapshot_checkpoint_commitment == current_anchor_commitment);
                assert(snapshot_causal_head_valid == current_anchor_causal_head_valid);
                assert(snapshot_causal_head_transition_id == current_anchor_causal_head_transition_id);
                assert(snapshot_causal_head_gen == current_anchor_causal_head_gen);
                assert(snapshot_sealed_chain == current_anchor_sealed_chain);
                seen_anchored_restore_accept <= 1'b1;
                expect_recovered <= 1'b1;
                expected_head_valid <= snapshot_causal_head_valid;
                expected_head_id <= snapshot_causal_head_transition_id;
                expected_head_gen <= snapshot_causal_head_gen;
                expected_seal <= snapshot_sealed_chain;
            end

            if (full_state_restore_mismatch) begin
                assert(!full_state_restore_accept);
                assert(full_state_restore_rejected);
                seen_restore_causal_reject <= 1'b1;
            end

            if (recovery_begin)
                assert(!full_state_restore_accept);

            cover(seen_candidate_mismatch_reject);
            cover(seen_persist_mismatch_reject);
            cover(seen_ack_mismatch_reject);
            cover(seen_commit_event);
            cover(seen_anchored_restore_accept);
            cover(seen_restore_causal_reject);
            cover(seen_recovered_exact);
        end
    end
endmodule
