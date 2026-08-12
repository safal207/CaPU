`timescale 1ns/1ps

module capu_checkpoint_content_binding_v13_tb;
    localparam int AUTH_W = 16;
    localparam int SLOTS = 4;
    localparam int REF_W = 16;
    localparam int EPOCH_W = 8;
    localparam int COMMIT_W = 32;

    logic clk = 0;
    logic rst_n = 0;
    always #5 clk = ~clk;

    logic recovery_begin;
    logic restore_valid;
    logic [SLOTS-1:0] restore_spent_valid;
    logic [(SLOTS*AUTH_W)-1:0] restore_spent_refs;
    logic cold_start_authorized;
    logic [REF_W-1:0] snapshot_checkpoint_ref;
    logic [EPOCH_W-1:0] snapshot_checkpoint_epoch;
    logic [COMMIT_W-1:0] snapshot_checkpoint_commitment;
    logic snapshot_commitment_verified;

    logic current_anchor_valid;
    logic [REF_W-1:0] current_anchor_ref;
    logic [EPOCH_W-1:0] current_anchor_epoch;
    logic [COMMIT_W-1:0] current_anchor_commitment;

    logic checkpoint_prepare_valid;
    logic [REF_W-1:0] candidate_checkpoint_ref;
    logic [EPOCH_W-1:0] candidate_checkpoint_epoch;
    logic [COMMIT_W-1:0] candidate_checkpoint_commitment;
    logic candidate_commitment_verified;
    logic checkpoint_abort;

    logic snapshot_persisted_valid;
    logic [REF_W-1:0] persisted_checkpoint_ref;
    logic [EPOCH_W-1:0] persisted_checkpoint_epoch;
    logic [COMMIT_W-1:0] persisted_checkpoint_commitment;

    logic anchor_commit_ack_valid;
    logic ack_base_anchor_valid;
    logic [REF_W-1:0] ack_base_anchor_ref;
    logic [EPOCH_W-1:0] ack_base_anchor_epoch;
    logic [COMMIT_W-1:0] ack_base_anchor_commitment;
    logic [REF_W-1:0] ack_checkpoint_ref;
    logic [EPOCH_W-1:0] ack_checkpoint_epoch;
    logic [COMMIT_W-1:0] ack_checkpoint_commitment;

    logic derived_commitment_trusted;
    logic restore_commitment_mismatch;
    logic restore_commitment_unverified;
    logic candidate_commitment_rejected;
    logic checkpoint_restore_accept;
    logic checkpoint_restore_rejected;
    logic checkpoint_rollback_detected;
    logic checkpoint_anchor_mismatch;
    logic checkpoint_cold_start_accept;
    logic replay_recovery_ready;
    logic replay_restore_accept;
    logic replay_restore_rejected;
    logic [$clog2(SLOTS+1)-1:0] replay_spent_count;
    logic checkpoint_prepare_accept;
    logic checkpoint_prepare_rejected;
    logic checkpoint_candidate_pending;
    logic checkpoint_snapshot_persist_accept;
    logic checkpoint_snapshot_persist_rejected;
    logic checkpoint_snapshot_durable;
    logic checkpoint_anchor_commit_request;
    logic checkpoint_anchor_commit_ack_accept;
    logic checkpoint_anchor_commit_ack_rejected;
    logic checkpoint_commit_event;
    logic checkpoint_stale_base_detected;
    logic checkpoint_request_base_anchor_valid;
    logic [REF_W-1:0] checkpoint_request_base_anchor_ref;
    logic [EPOCH_W-1:0] checkpoint_request_base_anchor_epoch;
    logic [COMMIT_W-1:0] checkpoint_request_base_anchor_commitment;
    logic [REF_W-1:0] checkpoint_request_ref;
    logic [EPOCH_W-1:0] checkpoint_request_epoch;
    logic [COMMIT_W-1:0] checkpoint_request_commitment;

    localparam logic [COMMIT_W-1:0] K1 = 32'h6A31C001;
    localparam logic [COMMIT_W-1:0] K2 = 32'h7B42C002;

    capu_checkpoint_content_binding_v13 #(
        .AUTHORIZATION_REF_WIDTH(AUTH_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS),
        .CHECKPOINT_REF_WIDTH(REF_W),
        .CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
        .CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W)
    ) dut (.*);

    task automatic check_cond(input logic cond, input [8*96-1:0] msg);
        if (!cond) begin
            $display("FAIL %0s", msg);
            $fatal(1);
        end
    endtask

    task automatic clear_pulses;
        begin
            recovery_begin = 0;
            restore_valid = 0;
            checkpoint_prepare_valid = 0;
            checkpoint_abort = 0;
            snapshot_persisted_valid = 0;
            anchor_commit_ack_valid = 0;
        end
    endtask

    initial begin
        restore_spent_valid = '0;
        restore_spent_refs = '0;
        cold_start_authorized = 0;
        snapshot_checkpoint_ref = '0;
        snapshot_checkpoint_epoch = '0;
        snapshot_checkpoint_commitment = '0;
        snapshot_commitment_verified = 0;
        current_anchor_valid = 0;
        current_anchor_ref = '0;
        current_anchor_epoch = '0;
        current_anchor_commitment = '0;
        candidate_checkpoint_ref = '0;
        candidate_checkpoint_epoch = '0;
        candidate_checkpoint_commitment = '0;
        candidate_commitment_verified = 0;
        persisted_checkpoint_ref = '0;
        persisted_checkpoint_epoch = '0;
        persisted_checkpoint_commitment = '0;
        ack_base_anchor_valid = 0;
        ack_base_anchor_ref = '0;
        ack_base_anchor_epoch = '0;
        ack_base_anchor_commitment = '0;
        ack_checkpoint_ref = '0;
        ack_checkpoint_epoch = '0;
        ack_checkpoint_commitment = '0;
        clear_pulses();

        repeat (2) @(posedge clk);
        rst_n = 1;
        @(negedge clk);

        // Unverified candidate content cannot enter the v0.12 commit protocol.
        checkpoint_prepare_valid = 1;
        candidate_checkpoint_ref = 16'hC001;
        candidate_checkpoint_epoch = 8'd1;
        candidate_checkpoint_commitment = K1;
        candidate_commitment_verified = 0;
        #1;
        check_cond(candidate_commitment_rejected && checkpoint_prepare_rejected,
                   "unverified candidate commitment must be rejected");
        @(posedge clk); #1;
        check_cond(!checkpoint_candidate_pending, "unverified candidate must not become pending");
        @(negedge clk); checkpoint_prepare_valid = 0;
        $display("TRACE V13 unverified_candidate rejected=1");

        // Verified candidate becomes the exact commitment carried by the request.
        checkpoint_prepare_valid = 1;
        candidate_commitment_verified = 1;
        #1;
        check_cond(checkpoint_prepare_accept, "verified first checkpoint must prepare");
        @(posedge clk); #1;
        check_cond(checkpoint_candidate_pending, "candidate should latch after prepare");
        check_cond(checkpoint_request_commitment == K1, "candidate commitment must latch exactly");
        @(negedge clk); checkpoint_prepare_valid = 0;
        $display("TRACE V13 prepared commitment=%h", checkpoint_request_commitment);

        // Persistence acknowledgement with the wrong content commitment fails closed.
        snapshot_persisted_valid = 1;
        persisted_checkpoint_ref = 16'hC001;
        persisted_checkpoint_epoch = 8'd1;
        persisted_checkpoint_commitment = K2;
        #1;
        check_cond(checkpoint_snapshot_persist_rejected && !checkpoint_snapshot_persist_accept,
                   "wrong persisted commitment must reject");
        @(posedge clk); #1;
        check_cond(!checkpoint_snapshot_durable, "wrong commitment must not mark snapshot durable");
        @(negedge clk);
        persisted_checkpoint_commitment = K1;
        #1;
        check_cond(checkpoint_snapshot_persist_accept, "exact persisted commitment must accept");
        @(posedge clk); #1;
        check_cond(checkpoint_snapshot_durable && checkpoint_anchor_commit_request,
                   "durable exact snapshot should open anchor commit request");
        @(negedge clk); snapshot_persisted_valid = 0;
        $display("TRACE V13 persistence_exact commitment=%h", checkpoint_request_commitment);

        // Wrong commitment in durable-anchor acknowledgement cannot create authority.
        anchor_commit_ack_valid = 1;
        ack_base_anchor_valid = 0;
        ack_base_anchor_ref = '0;
        ack_base_anchor_epoch = '0;
        ack_base_anchor_commitment = '0;
        ack_checkpoint_ref = 16'hC001;
        ack_checkpoint_epoch = 8'd1;
        ack_checkpoint_commitment = K2;
        #1;
        check_cond(checkpoint_anchor_commit_ack_rejected && !checkpoint_commit_event,
                   "wrong anchor acknowledgement commitment must reject");
        @(posedge clk); #1;
        check_cond(checkpoint_candidate_pending, "wrong ack must leave candidate pending");
        @(negedge clk);
        ack_checkpoint_commitment = K1;
        #1;
        check_cond(checkpoint_anchor_commit_ack_accept && checkpoint_commit_event,
                   "exact anchor acknowledgement commitment must commit");
        @(posedge clk); #1;
        check_cond(!checkpoint_candidate_pending, "commit should clear candidate");
        @(negedge clk); anchor_commit_ack_valid = 0;
        $display("TRACE V13 checkpoint_committed ref=C001 epoch=1 commitment=%h", K1);

        // External durable anchor now reflects the committed checkpoint.
        current_anchor_valid = 1;
        current_anchor_ref = 16'hC001;
        current_anchor_epoch = 8'd1;
        current_anchor_commitment = K1;

        // Reset/recovery: unverified or mismatched content commitment cannot restore.
        recovery_begin = 1;
        @(posedge clk); #1;
        @(negedge clk); recovery_begin = 0;
        restore_spent_valid = 4'b0001;
        restore_spent_refs = {{(SLOTS-1)*AUTH_W{1'b0}}, 16'hA110};
        snapshot_checkpoint_ref = 16'hC001;
        snapshot_checkpoint_epoch = 8'd1;
        snapshot_checkpoint_commitment = K1;
        snapshot_commitment_verified = 0;
        restore_valid = 1;
        #1;
        check_cond(restore_commitment_unverified && checkpoint_restore_rejected,
                   "unverified anchored snapshot must reject");
        @(posedge clk); #1;
        check_cond(!replay_recovery_ready, "unverified content must not reopen recovery");
        @(negedge clk);
        snapshot_commitment_verified = 1;
        snapshot_checkpoint_commitment = K2;
        #1;
        check_cond(restore_commitment_mismatch && checkpoint_restore_rejected,
                   "mismatched anchored commitment must reject");
        @(posedge clk); #1;
        check_cond(!replay_recovery_ready, "mismatched content must not reopen recovery");
        @(negedge clk);
        snapshot_checkpoint_commitment = K1;
        #1;
        check_cond(derived_commitment_trusted && checkpoint_restore_accept,
                   "verified exact anchored commitment must restore");
        @(posedge clk); #1;
        check_cond(replay_recovery_ready && replay_spent_count == 1,
                   "exact content-bound restore should recover replay state");
        @(negedge clk); restore_valid = 0;
        $display("TRACE V13 anchored_restore commitment=%h spent=%0d", K1, replay_spent_count);

        // Tampered replay bytes are expected to fail in the off-path verifier;
        // hardware consumes that verdict and remains fail-closed.
        recovery_begin = 1;
        @(posedge clk); #1;
        @(negedge clk); recovery_begin = 0;
        restore_spent_refs = {{(SLOTS-1)*AUTH_W{1'b0}}, 16'hA120};
        snapshot_checkpoint_commitment = K1;
        snapshot_commitment_verified = 0;
        restore_valid = 1;
        #1;
        check_cond(checkpoint_restore_rejected && !checkpoint_restore_accept,
                   "tampered bytes with failed commitment verification must reject");
        @(posedge clk); #1;
        check_cond(!replay_recovery_ready, "tampered snapshot must stay fail closed");
        @(negedge clk); restore_valid = 0;
        $display("TRACE V13 tampered_snapshot verifier_rejected=1");

        // A second checkpoint must bind the old commitment as CAS base and the
        // new commitment as the candidate authority.
        checkpoint_prepare_valid = 1;
        candidate_checkpoint_ref = 16'hC002;
        candidate_checkpoint_epoch = 8'd2;
        candidate_checkpoint_commitment = K2;
        candidate_commitment_verified = 1;
        #1;
        check_cond(checkpoint_prepare_accept, "second verified checkpoint must prepare");
        @(posedge clk); #1;
        check_cond(checkpoint_request_base_anchor_commitment == K1,
                   "CAS base must bind current anchor commitment");
        check_cond(checkpoint_request_commitment == K2,
                   "CAS candidate must bind new commitment");
        @(negedge clk); checkpoint_prepare_valid = 0;

        snapshot_persisted_valid = 1;
        persisted_checkpoint_ref = 16'hC002;
        persisted_checkpoint_epoch = 8'd2;
        persisted_checkpoint_commitment = K2;
        #1; check_cond(checkpoint_snapshot_persist_accept, "second snapshot persistence must bind K2");
        @(posedge clk); #1;
        @(negedge clk); snapshot_persisted_valid = 0;

        anchor_commit_ack_valid = 1;
        ack_base_anchor_valid = 1;
        ack_base_anchor_ref = 16'hC001;
        ack_base_anchor_epoch = 8'd1;
        ack_base_anchor_commitment = K1;
        ack_checkpoint_ref = 16'hC002;
        ack_checkpoint_epoch = 8'd2;
        ack_checkpoint_commitment = K2;
        #1; check_cond(checkpoint_commit_event, "second exact commitment transition must commit");
        @(posedge clk); #1;
        @(negedge clk); anchor_commit_ack_valid = 0;
        $display("TRACE V13 commitment_transition base=%h candidate=%h", K1, K2);

        $display("CAPU_VCML_CHECKPOINT_CONTENT_V13_PASS");
        $finish;
    end
endmodule
