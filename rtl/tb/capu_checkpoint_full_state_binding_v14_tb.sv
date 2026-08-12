`timescale 1ns/1ps

module capu_checkpoint_full_state_binding_v14_tb;
    localparam int AUTH_W = 16;
    localparam int SLOTS = 4;
    localparam int REF_W = 16;
    localparam int EPOCH_W = 8;
    localparam int COMMIT_W = 32;
    localparam int TID_W = 16;

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
    logic snapshot_causal_head_valid;
    logic [TID_W-1:0] snapshot_causal_head_transition_id;
    logic [3:0] snapshot_causal_head_gen;
    logic snapshot_sealed_chain;

    logic current_anchor_valid;
    logic [REF_W-1:0] current_anchor_ref;
    logic [EPOCH_W-1:0] current_anchor_epoch;
    logic [COMMIT_W-1:0] current_anchor_commitment;
    logic current_anchor_causal_head_valid;
    logic [TID_W-1:0] current_anchor_causal_head_transition_id;
    logic [3:0] current_anchor_causal_head_gen;
    logic current_anchor_sealed_chain;

    logic checkpoint_prepare_valid;
    logic [REF_W-1:0] candidate_checkpoint_ref;
    logic [EPOCH_W-1:0] candidate_checkpoint_epoch;
    logic [COMMIT_W-1:0] candidate_checkpoint_commitment;
    logic candidate_commitment_verified;
    logic candidate_causal_head_valid;
    logic [TID_W-1:0] candidate_causal_head_transition_id;
    logic [3:0] candidate_causal_head_gen;
    logic candidate_sealed_chain;
    logic committed_causal_head_valid;
    logic [TID_W-1:0] committed_causal_head_transition_id;
    logic [3:0] committed_causal_head_gen;
    logic committed_sealed_chain;
    logic checkpoint_abort;

    logic snapshot_persisted_valid;
    logic [REF_W-1:0] persisted_checkpoint_ref;
    logic [EPOCH_W-1:0] persisted_checkpoint_epoch;
    logic [COMMIT_W-1:0] persisted_checkpoint_commitment;
    logic persisted_causal_head_valid;
    logic [TID_W-1:0] persisted_causal_head_transition_id;
    logic [3:0] persisted_causal_head_gen;
    logic persisted_sealed_chain;

    logic anchor_commit_ack_valid;
    logic ack_base_anchor_valid;
    logic [REF_W-1:0] ack_base_anchor_ref;
    logic [EPOCH_W-1:0] ack_base_anchor_epoch;
    logic [COMMIT_W-1:0] ack_base_anchor_commitment;
    logic ack_base_causal_head_valid;
    logic [TID_W-1:0] ack_base_causal_head_transition_id;
    logic [3:0] ack_base_causal_head_gen;
    logic ack_base_sealed_chain;
    logic [REF_W-1:0] ack_checkpoint_ref;
    logic [EPOCH_W-1:0] ack_checkpoint_epoch;
    logic [COMMIT_W-1:0] ack_checkpoint_commitment;
    logic ack_causal_head_valid;
    logic [TID_W-1:0] ack_causal_head_transition_id;
    logic [3:0] ack_causal_head_gen;
    logic ack_sealed_chain;

    logic full_state_restore_accept;
    logic full_state_restore_rejected;
    logic full_state_restore_mismatch;
    logic candidate_causal_state_rejected;
    logic persisted_causal_state_rejected;
    logic ack_causal_state_rejected;
    logic recovered_causal_state_ready;
    logic recovered_causal_head_valid;
    logic [TID_W-1:0] recovered_causal_head_transition_id;
    logic [3:0] recovered_causal_head_gen;
    logic recovered_sealed_chain;
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
    logic checkpoint_request_base_causal_head_valid;
    logic [TID_W-1:0] checkpoint_request_base_causal_head_transition_id;
    logic [3:0] checkpoint_request_base_causal_head_gen;
    logic checkpoint_request_base_sealed_chain;
    logic [REF_W-1:0] checkpoint_request_ref;
    logic [EPOCH_W-1:0] checkpoint_request_epoch;
    logic [COMMIT_W-1:0] checkpoint_request_commitment;
    logic checkpoint_request_causal_head_valid;
    logic [TID_W-1:0] checkpoint_request_causal_head_transition_id;
    logic [3:0] checkpoint_request_causal_head_gen;
    logic checkpoint_request_sealed_chain;

    localparam logic [COMMIT_W-1:0] K1 = 32'h8C14A001;
    localparam logic [TID_W-1:0] H1 = 16'h2201;

    capu_checkpoint_full_state_binding_v14 #(
        .AUTHORIZATION_REF_WIDTH(AUTH_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS),
        .CHECKPOINT_REF_WIDTH(REF_W),
        .CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
        .CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W),
        .TRANSITION_ID_WIDTH(TID_W)
    ) dut (.*);

    task automatic check_cond(input logic cond, input [8*112-1:0] msg);
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
        snapshot_causal_head_valid = 0;
        snapshot_causal_head_transition_id = '0;
        snapshot_causal_head_gen = 0;
        snapshot_sealed_chain = 0;

        current_anchor_valid = 0;
        current_anchor_ref = '0;
        current_anchor_epoch = '0;
        current_anchor_commitment = '0;
        current_anchor_causal_head_valid = 0;
        current_anchor_causal_head_transition_id = '0;
        current_anchor_causal_head_gen = 0;
        current_anchor_sealed_chain = 0;

        candidate_checkpoint_ref = 16'hC101;
        candidate_checkpoint_epoch = 8'd1;
        candidate_checkpoint_commitment = K1;
        candidate_commitment_verified = 1;
        candidate_causal_head_valid = 1;
        candidate_causal_head_transition_id = H1;
        candidate_causal_head_gen = 4'd6;
        candidate_sealed_chain = 0;

        committed_causal_head_valid = 1;
        committed_causal_head_transition_id = H1;
        committed_causal_head_gen = 4'd6;
        committed_sealed_chain = 0;

        persisted_checkpoint_ref = 16'hC101;
        persisted_checkpoint_epoch = 8'd1;
        persisted_checkpoint_commitment = K1;
        persisted_causal_head_valid = 1;
        persisted_causal_head_transition_id = H1;
        persisted_causal_head_gen = 4'd6;
        persisted_sealed_chain = 0;

        ack_base_anchor_valid = 0;
        ack_base_anchor_ref = '0;
        ack_base_anchor_epoch = '0;
        ack_base_anchor_commitment = '0;
        ack_base_causal_head_valid = 0;
        ack_base_causal_head_transition_id = '0;
        ack_base_causal_head_gen = 0;
        ack_base_sealed_chain = 0;
        ack_checkpoint_ref = 16'hC101;
        ack_checkpoint_epoch = 8'd1;
        ack_checkpoint_commitment = K1;
        ack_causal_head_valid = 1;
        ack_causal_head_transition_id = H1;
        ack_causal_head_gen = 4'd6;
        ack_sealed_chain = 0;
        clear_pulses();

        repeat (2) @(posedge clk);
        rst_n = 1;
        @(negedge clk);

        // PREPARE must describe the current committed causal state exactly.
        candidate_causal_head_transition_id = 16'h2202;
        checkpoint_prepare_valid = 1;
        #1;
        check_cond(candidate_causal_state_rejected && checkpoint_prepare_rejected,
                   "candidate with wrong committed head must reject");
        @(posedge clk); #1;
        check_cond(!checkpoint_candidate_pending, "wrong-head candidate must not become pending");
        @(negedge clk);
        candidate_causal_head_transition_id = H1;
        #1;
        check_cond(checkpoint_prepare_accept, "exact committed causal state must prepare");
        @(posedge clk); #1;
        check_cond(checkpoint_candidate_pending, "exact candidate should latch");
        check_cond(checkpoint_request_causal_head_transition_id == H1
                   && checkpoint_request_causal_head_gen == 4'd6
                   && !checkpoint_request_sealed_chain,
                   "request must carry exact committed causal state");
        @(negedge clk); checkpoint_prepare_valid = 0;
        $display("TRACE V14 candidate_mismatch rejected=1 prepared_head=%h gen=%0d seal=%0d",
                 checkpoint_request_causal_head_transition_id,
                 checkpoint_request_causal_head_gen,
                 checkpoint_request_sealed_chain);

        // Persistence cannot alter the causal state even if the commitment/ref match.
        snapshot_persisted_valid = 1;
        persisted_causal_head_gen = 4'd7;
        #1;
        check_cond(persisted_causal_state_rejected && checkpoint_snapshot_persist_rejected,
                   "persistence with changed GEN must reject");
        @(posedge clk); #1;
        check_cond(!checkpoint_snapshot_durable, "wrong causal persistence must not become durable");
        @(negedge clk);
        persisted_causal_head_gen = 4'd6;
        #1;
        check_cond(checkpoint_snapshot_persist_accept, "exact causal persistence must accept");
        @(posedge clk); #1;
        check_cond(checkpoint_snapshot_durable && checkpoint_anchor_commit_request,
                   "exact durable snapshot must open anchor request");
        @(negedge clk); snapshot_persisted_valid = 0;
        $display("TRACE V14 persistence_causal_mismatch rejected=1 exact=1");

        // Anchor ACK cannot alter SEAL or base causal metadata.
        anchor_commit_ack_valid = 1;
        ack_sealed_chain = 1;
        #1;
        check_cond(ack_causal_state_rejected && checkpoint_anchor_commit_ack_rejected,
                   "anchor ACK with changed SEAL must reject");
        @(posedge clk); #1;
        check_cond(checkpoint_candidate_pending, "bad causal ACK must leave candidate pending");
        @(negedge clk);
        ack_sealed_chain = 0;
        #1;
        check_cond(checkpoint_anchor_commit_ack_accept && checkpoint_commit_event,
                   "exact causal ACK must commit authority");
        @(posedge clk); #1;
        check_cond(!checkpoint_candidate_pending, "commit must clear candidate");
        @(negedge clk); anchor_commit_ack_valid = 0;
        $display("TRACE V14 anchor_ack_causal_mismatch rejected=1 committed=1");

        // External anchor now carries the same explicit causal state sideband.
        current_anchor_valid = 1;
        current_anchor_ref = 16'hC101;
        current_anchor_epoch = 8'd1;
        current_anchor_commitment = K1;
        current_anchor_causal_head_valid = 1;
        current_anchor_causal_head_transition_id = H1;
        current_anchor_causal_head_gen = 4'd6;
        current_anchor_sealed_chain = 0;

        // Recovery begins fail-closed.
        recovery_begin = 1;
        @(posedge clk); #1;
        @(negedge clk); recovery_begin = 0;

        restore_spent_valid = 4'b0001;
        restore_spent_refs = {{(SLOTS-1)*AUTH_W{1'b0}}, 16'hA110};
        snapshot_checkpoint_ref = 16'hC101;
        snapshot_checkpoint_epoch = 8'd1;
        snapshot_checkpoint_commitment = K1;
        snapshot_commitment_verified = 1;
        snapshot_causal_head_valid = 1;
        snapshot_causal_head_transition_id = H1;
        snapshot_causal_head_gen = 4'd7;
        snapshot_sealed_chain = 0;
        restore_valid = 1;
        #1;
        check_cond(full_state_restore_mismatch && full_state_restore_rejected,
                   "restore with changed GEN must reject before replay recovery");
        @(posedge clk); #1;
        check_cond(!replay_recovery_ready && !recovered_causal_state_ready,
                   "causal mismatch must stay fail closed");
        @(negedge clk);
        snapshot_causal_head_gen = 4'd6;
        #1;
        check_cond(full_state_restore_accept, "exact full causal snapshot must restore");
        @(posedge clk); #1;
        check_cond(replay_recovery_ready && replay_spent_count == 1,
                   "exact restore must recover spent replay state");
        check_cond(recovered_causal_state_ready
                   && recovered_causal_head_valid
                   && recovered_causal_head_transition_id == H1
                   && recovered_causal_head_gen == 4'd6
                   && !recovered_sealed_chain,
                   "exact restore must recover head GEN and SEAL");
        @(negedge clk); restore_valid = 0;
        $display("TRACE V14 restored head=%h gen=%0d seal=%0d spent=%0d",
                 recovered_causal_head_transition_id,
                 recovered_causal_head_gen,
                 recovered_sealed_chain,
                 replay_spent_count);

        // A second recovery attempt with the same commitment but wrong head
        // proves commitment verification alone is insufficient for this RTL ABI.
        recovery_begin = 1;
        @(posedge clk); #1;
        @(negedge clk); recovery_begin = 0;
        snapshot_causal_head_transition_id = 16'h2299;
        restore_valid = 1;
        #1;
        check_cond(full_state_restore_mismatch && full_state_restore_rejected,
                   "same commitment with wrong causal head must reject");
        @(posedge clk); #1;
        check_cond(!replay_recovery_ready && !recovered_causal_state_ready,
                   "wrong head must not restore either state layer");
        @(negedge clk); restore_valid = 0;
        $display("TRACE V14 recovery_mismatch rejected=1");

        $display("CAPU_VCML_CHECKPOINT_FULL_STATE_V14_PASS");
        $finish;
    end
endmodule
