`timescale 1ns/1ps

module capu_arch_checkpoint_binding_v17_tb;
    localparam int REF_W = 8;
    localparam int EPOCH_W = 8;
    localparam int COMMIT_W = 16;
    localparam int ARCH_EPOCH_W = 8;
    localparam int PC_W = 16;
    localparam int DATA_W = 16;
    localparam int TID_W = 16;
    localparam int AUTH_W = 16;
    localparam int SLOTS = 2;
    localparam int PAYLOAD_W = ARCH_EPOCH_W + PC_W + (4*DATA_W) + 8
        + 1 + TID_W + 4 + 1 + SLOTS + (SLOTS*AUTH_W);

    logic clk = 0;
    logic rst_n = 0;
    always #5 clk = ~clk;

    logic recovery_begin;
    logic restore_valid;
    logic [REF_W-1:0] snapshot_checkpoint_ref;
    logic [EPOCH_W-1:0] snapshot_checkpoint_epoch;
    logic [COMMIT_W-1:0] snapshot_checkpoint_commitment;
    logic [PAYLOAD_W-1:0] snapshot_checkpoint_payload;
    logic snapshot_commitment_verified;
    logic current_anchor_valid;
    logic [REF_W-1:0] current_anchor_ref;
    logic [EPOCH_W-1:0] current_anchor_epoch;
    logic [COMMIT_W-1:0] current_anchor_commitment;
    logic [PAYLOAD_W-1:0] current_anchor_payload;
    logic checkpoint_prepare_valid;
    logic [REF_W-1:0] candidate_checkpoint_ref;
    logic [EPOCH_W-1:0] candidate_checkpoint_epoch;
    logic [COMMIT_W-1:0] candidate_checkpoint_commitment;
    logic [PAYLOAD_W-1:0] candidate_checkpoint_payload;
    logic candidate_commitment_verified;
    logic [PAYLOAD_W-1:0] committed_checkpoint_payload;
    logic checkpoint_abort;
    logic snapshot_persisted_valid;
    logic [REF_W-1:0] persisted_checkpoint_ref;
    logic [EPOCH_W-1:0] persisted_checkpoint_epoch;
    logic [COMMIT_W-1:0] persisted_checkpoint_commitment;
    logic [PAYLOAD_W-1:0] persisted_checkpoint_payload;
    logic anchor_commit_ack_valid;
    logic ack_base_anchor_valid;
    logic [REF_W-1:0] ack_base_anchor_ref;
    logic [EPOCH_W-1:0] ack_base_anchor_epoch;
    logic [COMMIT_W-1:0] ack_base_anchor_commitment;
    logic [PAYLOAD_W-1:0] ack_base_anchor_payload;
    logic [REF_W-1:0] ack_checkpoint_ref;
    logic [EPOCH_W-1:0] ack_checkpoint_epoch;
    logic [COMMIT_W-1:0] ack_checkpoint_commitment;
    logic [PAYLOAD_W-1:0] ack_checkpoint_payload;

    wire checkpoint_prepare_accept;
    wire checkpoint_prepare_rejected;
    wire checkpoint_candidate_pending;
    wire candidate_payload_rejected;
    wire checkpoint_snapshot_persist_accept;
    wire checkpoint_snapshot_persist_rejected;
    wire checkpoint_snapshot_durable;
    wire checkpoint_anchor_commit_request;
    wire checkpoint_anchor_commit_ack_accept;
    wire checkpoint_anchor_commit_ack_rejected;
    wire checkpoint_commit_event;
    wire checkpoint_restore_accept;
    wire checkpoint_restore_rejected;
    wire checkpoint_restore_mismatch;
    wire recovered_checkpoint_ready;
    wire [PAYLOAD_W-1:0] recovered_checkpoint_payload;
    wire checkpoint_request_base_anchor_valid;
    wire [REF_W-1:0] checkpoint_request_base_anchor_ref;
    wire [EPOCH_W-1:0] checkpoint_request_base_anchor_epoch;
    wire [COMMIT_W-1:0] checkpoint_request_base_anchor_commitment;
    wire [PAYLOAD_W-1:0] checkpoint_request_base_anchor_payload;
    wire [REF_W-1:0] checkpoint_request_ref;
    wire [EPOCH_W-1:0] checkpoint_request_epoch;
    wire [COMMIT_W-1:0] checkpoint_request_commitment;
    wire [PAYLOAD_W-1:0] checkpoint_request_payload;

    function automatic logic [PAYLOAD_W-1:0] payload(
        input logic [ARCH_EPOCH_W-1:0] recovery_epoch,
        input logic [PC_W-1:0] pc,
        input logic [DATA_W-1:0] gpr0,
        input logic [DATA_W-1:0] gpr1,
        input logic [DATA_W-1:0] gpr2,
        input logic [DATA_W-1:0] gpr3,
        input logic [7:0] status,
        input logic causal_head_valid,
        input logic [TID_W-1:0] causal_head,
        input logic [3:0] gen,
        input logic seal,
        input logic [SLOTS-1:0] spent_valid,
        input logic [(SLOTS*AUTH_W)-1:0] spent_refs
    );
        payload = {recovery_epoch, pc, gpr0, gpr1, gpr2, gpr3, status,
                   causal_head_valid, causal_head, gen, seal,
                   spent_valid, spent_refs};
    endfunction

    localparam logic [COMMIT_W-1:0] K1 = 16'hC017;
    logic [PAYLOAD_W-1:0] BOUND;
    logic [PAYLOAD_W-1:0] MUTATED_PC;
    logic [PAYLOAD_W-1:0] MUTATED_GPR;

    capu_arch_checkpoint_binding_v17 #(
        .CHECKPOINT_REF_WIDTH(REF_W),
        .CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
        .CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W),
        .ARCH_EPOCH_WIDTH(ARCH_EPOCH_W),
        .PC_WIDTH(PC_W),
        .DATA_WIDTH(DATA_W),
        .TRANSITION_ID_WIDTH(TID_W),
        .AUTHORIZATION_REF_WIDTH(AUTH_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS),
        .CHECKPOINT_PAYLOAD_WIDTH(PAYLOAD_W)
    ) dut (.*);

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            $display("FAIL V17: %s", message);
            $fatal(1);
        end
    endtask

    task automatic clear_pulses;
        recovery_begin = 0;
        restore_valid = 0;
        checkpoint_prepare_valid = 0;
        checkpoint_abort = 0;
        snapshot_persisted_valid = 0;
        anchor_commit_ack_valid = 0;
    endtask

    initial begin
        BOUND = payload(8'h21, 16'h0040, 16'h0000, 16'h0080,
                        16'h0055, 16'h0000, 8'hA5, 1'b1,
                        16'h2201, 4'd6, 1'b0, 2'b01,
                        {16'h0000,16'hA110});
        MUTATED_PC = payload(8'h21, 16'h0099, 16'h0000, 16'h0080,
                             16'h0055, 16'h0000, 8'hA5, 1'b1,
                             16'h2201, 4'd6, 1'b0, 2'b01,
                             {16'h0000,16'hA110});
        MUTATED_GPR = payload(8'h21, 16'h0040, 16'h0000, 16'h0013,
                              16'h00DE, 16'h0000, 8'hA5, 1'b1,
                              16'h2201, 4'd6, 1'b0, 2'b01,
                              {16'h0000,16'hA110});

        clear_pulses();
        snapshot_checkpoint_ref = 8'h41;
        snapshot_checkpoint_epoch = 8'd1;
        snapshot_checkpoint_commitment = K1;
        snapshot_checkpoint_payload = BOUND;
        snapshot_commitment_verified = 1;
        current_anchor_valid = 0;
        current_anchor_ref = 0;
        current_anchor_epoch = 0;
        current_anchor_commitment = 0;
        current_anchor_payload = 0;
        candidate_checkpoint_ref = 8'h41;
        candidate_checkpoint_epoch = 8'd1;
        candidate_checkpoint_commitment = K1;
        candidate_checkpoint_payload = BOUND;
        candidate_commitment_verified = 1;
        committed_checkpoint_payload = BOUND;
        persisted_checkpoint_ref = 8'h41;
        persisted_checkpoint_epoch = 8'd1;
        persisted_checkpoint_commitment = K1;
        persisted_checkpoint_payload = BOUND;
        ack_base_anchor_valid = 0;
        ack_base_anchor_ref = 0;
        ack_base_anchor_epoch = 0;
        ack_base_anchor_commitment = 0;
        ack_base_anchor_payload = 0;
        ack_checkpoint_ref = 8'h41;
        ack_checkpoint_epoch = 8'd1;
        ack_checkpoint_commitment = K1;
        ack_checkpoint_payload = BOUND;

        repeat (2) @(posedge clk);
        rst_n = 1;
        @(negedge clk);

        // A digest verdict cannot authorize bytes other than the exact live
        // canonical record supplied at PREPARE.
        candidate_checkpoint_payload = MUTATED_PC;
        checkpoint_prepare_valid = 1;
        #1;
        check(candidate_payload_rejected && checkpoint_prepare_rejected,
              "mutated architectural state must not prepare");
        @(posedge clk); #1;
        check(!checkpoint_candidate_pending, "rejected mixed candidate must not latch");
        @(negedge clk);
        candidate_checkpoint_payload = BOUND;
        #1;
        check(checkpoint_prepare_accept, "exact full payload must prepare");
        @(posedge clk); #1;
        check(checkpoint_candidate_pending && checkpoint_request_payload == BOUND,
              "prepare must latch exact bound payload");
        @(negedge clk); checkpoint_prepare_valid = 0;
        $display("TRACE V17 prepare_arch_mutation rejected=1 exact=1");

        snapshot_persisted_valid = 1;
        persisted_checkpoint_payload = MUTATED_GPR;
        #1;
        check(checkpoint_snapshot_persist_rejected,
              "persistence cannot swap GPR bytes under the digest");
        @(posedge clk); #1;
        check(!checkpoint_snapshot_durable, "mixed persistence must not become durable");
        @(negedge clk);
        persisted_checkpoint_payload = BOUND;
        #1;
        check(checkpoint_snapshot_persist_accept, "exact persistence must accept");
        @(posedge clk); #1;
        check(checkpoint_snapshot_durable && checkpoint_anchor_commit_request,
              "exact durable payload must request authority");
        @(negedge clk); snapshot_persisted_valid = 0;
        $display("TRACE V17 persistence_arch_mutation rejected=1 exact=1");

        anchor_commit_ack_valid = 1;
        ack_checkpoint_payload = MUTATED_PC;
        #1;
        check(checkpoint_anchor_commit_ack_rejected && !checkpoint_commit_event,
              "anchor ACK cannot mix architectural bytes");
        @(posedge clk); #1;
        check(checkpoint_candidate_pending, "bad ACK must leave candidate pending");
        @(negedge clk);
        ack_checkpoint_payload = BOUND;
        #1;
        check(checkpoint_anchor_commit_ack_accept && checkpoint_commit_event,
              "exact full payload must commit authority");
        @(posedge clk); #1;
        check(!checkpoint_candidate_pending, "commit must clear candidate");
        @(negedge clk); anchor_commit_ack_valid = 0;
        $display("TRACE V17 anchor_arch_mutation rejected=1 committed=1");

        current_anchor_valid = 1;
        current_anchor_ref = 8'h41;
        current_anchor_epoch = 8'd1;
        current_anchor_commitment = K1;
        current_anchor_payload = BOUND;

        recovery_begin = 1;
        @(posedge clk); #1;
        check(!recovered_checkpoint_ready, "recovery must close restored authority");
        @(negedge clk); recovery_begin = 0;

        // Same valid causal suffix and same supplied commitment cannot make a
        // foreign PC/GPR context acceptable.
        snapshot_checkpoint_payload = MUTATED_PC;
        restore_valid = 1;
        #1;
        check(checkpoint_restore_mismatch && checkpoint_restore_rejected,
              "mixed architectural snapshot must fail closed");
        @(posedge clk); #1;
        check(!recovered_checkpoint_ready,
              "mixed snapshot must not become recovery authority");
        @(negedge clk);
        snapshot_checkpoint_payload = BOUND;
        #1;
        check(checkpoint_restore_accept, "exact complete snapshot must restore");
        @(posedge clk); #1;
        check(recovered_checkpoint_ready && recovered_checkpoint_payload == BOUND,
              "restore must load the exact anchored payload");
        @(negedge clk); restore_valid = 0;
        $display("TRACE V17 mixed_snapshot rejected=1 restored_pc=0040 head=2201 gen=6");

        recovery_begin = 1;
        restore_valid = 1;
        #1;
        check(!checkpoint_restore_accept && checkpoint_restore_rejected,
              "recovery must have priority over exact restore");
        @(posedge clk); #1;
        check(!recovered_checkpoint_ready, "priority boundary must remain closed");
        @(negedge clk); clear_pulses();
        $display("TRACE V17 recovery_priority enforced=1");

        $display("CAPU_VCML_ARCH_CHECKPOINT_V17_PASS");
        $finish;
    end
endmodule
