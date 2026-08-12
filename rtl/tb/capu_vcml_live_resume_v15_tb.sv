`timescale 1ns/1ps

module capu_vcml_live_resume_v15_tb;
    localparam int ADDR_W = 8;
    localparam int DATA_W = 16;
    localparam int TID_W = 16;
    localparam int AUTH_W = 16;
    localparam int POLICY_W = 8;
    localparam int SLOTS = 2;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic recovery_begin;
    logic restore_valid;
    logic [SLOTS-1:0] restore_spent_valid;
    logic [(SLOTS*AUTH_W)-1:0] restore_spent_refs;
    logic restore_causal_head_valid;
    logic [TID_W-1:0] restore_causal_head_transition_id;
    logic [3:0] restore_causal_head_gen;
    logic restore_sealed_chain;

    logic issue_valid;
    logic gate_allow;
    logic execute_ok;
    logic [ADDR_W-1:0] store_addr;
    logic [DATA_W-1:0] store_data;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [TID_W-1:0] store_transition_id;
    logic [TID_W-1:0] store_parent_ref;
    logic explicit_new_cause;
    logic root_authorized;
    logic [AUTH_W-1:0] root_authorization_ref;
    logic [POLICY_W-1:0] root_policy_epoch;
    logic causal_valid;
    logic commit_request;
    logic flush;

    logic buffer_valid;
    logic memory_write_enable;
    logic [ADDR_W-1:0] memory_write_addr;
    logic [DATA_W-1:0] memory_write_data;
    logic vcml_event_valid;
    logic [TID_W-1:0] retired_transition_id;
    logic [TID_W-1:0] retired_parent_ref;
    logic retired_root_authorized;
    logic [AUTH_W-1:0] retired_root_authorization_ref;
    logic [POLICY_W-1:0] retired_root_policy_epoch;
    logic issue_rejected;

    logic live_causal_state_ready;
    logic live_causal_head_valid;
    logic [TID_W-1:0] live_causal_head_transition_id;
    logic [3:0] live_causal_head_gen;
    logic live_sealed_chain;
    logic live_generation_exhausted;
    logic causal_restore_snapshot_well_formed;
    logic causal_restore_accept;
    logic causal_restore_rejected;
    logic replay_recovery_ready;
    logic replay_restore_snapshot_well_formed;
    logic replay_restore_accept;
    logic replay_restore_rejected;
    logic replay_authorization_accept;
    logic replay_authorization_ref_fresh;
    logic replay_detected;
    logic replay_capacity_exhausted;
    logic [$clog2(SLOTS+1)-1:0] replay_spent_count;
    logic replay_retirement_fault;
    logic replay_retirement_without_recovery_fault;

    capu_vcml_store_buffer_v15 #(
        .ADDR_WIDTH(ADDR_W),
        .DATA_WIDTH(DATA_W),
        .TRANSITION_ID_WIDTH(TID_W),
        .PARENT_REF_WIDTH(TID_W),
        .AUTHORIZATION_REF_WIDTH(AUTH_W),
        .POLICY_EPOCH_WIDTH(POLICY_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS)
    ) dut (.*);

    always #5 clk = ~clk;

    function automatic [15:0] write_ctag(input [3:0] gen, input logic seal);
        write_ctag = {4'h1, 4'h2, gen, 3'b000, seal};
    endfunction

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic clear_issue;
        begin
            issue_valid = 1'b0;
            causal_valid = 1'b0;
            commit_request = 1'b0;
            flush = 1'b0;
            explicit_new_cause = 1'b0;
            root_authorized = 1'b0;
            root_authorization_ref = '0;
            root_policy_epoch = '0;
        end
    endtask

    task automatic begin_recovery;
        begin
            recovery_begin = 1'b1;
            tick();
            recovery_begin = 1'b0;
            if (live_causal_state_ready)
                $fatal(1, "runtime must fail closed after recovery_begin");
        end
    endtask

    task automatic restore_state(
        input logic head_valid,
        input logic [TID_W-1:0] head_id,
        input logic [3:0] head_gen,
        input logic seal,
        input logic [SLOTS-1:0] spent_valid,
        input logic [(SLOTS*AUTH_W)-1:0] spent_refs
    );
        begin
            restore_causal_head_valid = head_valid;
            restore_causal_head_transition_id = head_id;
            restore_causal_head_gen = head_gen;
            restore_sealed_chain = seal;
            restore_spent_valid = spent_valid;
            restore_spent_refs = spent_refs;
            restore_valid = 1'b1;
            #1;
            if (!causal_restore_snapshot_well_formed || !causal_restore_accept)
                $fatal(1, "expected structurally valid runtime restore acceptance");
            tick();
            restore_valid = 1'b0;
            #1;
            if (!live_causal_state_ready || !replay_recovery_ready)
                $fatal(1, "runtime not ready after accepted restore");
            if (live_causal_head_valid !== head_valid
                || live_causal_head_transition_id !== head_id
                || live_causal_head_gen !== head_gen
                || live_sealed_chain !== seal)
                $fatal(1, "restored live causal state mismatch");
        end
    endtask

    task automatic try_issue(
        input logic [TID_W-1:0] parent_id,
        input logic [TID_W-1:0] transition_id,
        input logic [3:0] gen,
        input logic seal,
        input logic is_root,
        input logic root_auth,
        input logic [AUTH_W-1:0] auth_ref,
        input logic expect_reject
    );
        begin
            store_parent_ref = parent_id;
            store_transition_id = transition_id;
            store_ctag = write_ctag(gen, seal);
            store_ctag_valid = 1'b1;
            explicit_new_cause = is_root;
            root_authorized = root_auth;
            root_authorization_ref = auth_ref;
            root_policy_epoch = 8'h2A;
            issue_valid = 1'b1;
            #1;
            if (issue_rejected !== expect_reject)
                $fatal(1, "unexpected issue decision parent=%h id=%h gen=%h reject=%b expected=%b",
                       parent_id, transition_id, gen, issue_rejected, expect_reject);
            tick();
            issue_valid = 1'b0;
            #1;
            if (expect_reject && buffer_valid)
                $fatal(1, "rejected candidate reached speculative buffer");
            if (!expect_reject && !buffer_valid)
                $fatal(1, "accepted candidate did not enter speculative buffer");
        end
    endtask

    task automatic retire_candidate(
        input logic [TID_W-1:0] expected_head,
        input logic [3:0] expected_gen,
        input logic expected_seal
    );
        begin
            causal_valid = 1'b1;
            commit_request = 1'b1;
            tick();
            if (!memory_write_enable || !vcml_event_valid)
                $fatal(1, "accepted candidate did not retire visibly");
            if (live_causal_head_transition_id !== expected_head
                || live_causal_head_gen !== expected_gen
                || live_sealed_chain !== expected_seal)
                $fatal(1, "live causal state did not advance on retirement");
            causal_valid = 1'b0;
            commit_request = 1'b0;
            tick();
            if (memory_write_enable)
                $fatal(1, "memory write pulse duplicated");
        end
    endtask

    initial begin
        recovery_begin = 1'b0;
        restore_valid = 1'b0;
        restore_spent_valid = '0;
        restore_spent_refs = '0;
        restore_causal_head_valid = 1'b0;
        restore_causal_head_transition_id = '0;
        restore_causal_head_gen = 4'h0;
        restore_sealed_chain = 1'b0;
        gate_allow = 1'b1;
        execute_ok = 1'b1;
        store_addr = 8'h40;
        store_data = 16'hCA15;
        store_ctag = write_ctag(4'h0, 1'b0);
        store_ctag_valid = 1'b1;
        store_transition_id = '0;
        store_parent_ref = '0;
        clear_issue();

        repeat (2) tick();
        rst_n = 1'b1;
        tick();

        // R1: exact recovered continuation resumes the pre-failure chain.
        begin_recovery();
        restore_state(1'b1, 16'h2201, 4'h6, 1'b0,
                      2'b01, {16'h0000, 16'hA110});
        if (replay_spent_count != 1)
            $fatal(1, "restored spent authorization count mismatch");

        // A pre-reset authorization remains spent after recovery.
        try_issue('0, 16'h9000, 4'h0, 1'b0, 1'b1, 1'b1, 16'hA110, 1'b1);
        if (!replay_detected)
            $fatal(1, "restored root authorization replay not detected");

        // Wrong predecessor and wrong generation are both fail-closed.
        try_issue(16'h2200, 16'h2202, 4'h7, 1'b0, 1'b0, 1'b0, '0, 1'b1);
        try_issue(16'h2201, 16'h2202, 4'h8, 1'b0, 1'b0, 1'b0, '0, 1'b1);

        // Exact parent + next GEN resumes and advances the live head.
        try_issue(16'h2201, 16'h2202, 4'h7, 1'b0, 1'b0, 1'b0, '0, 1'b0);
        retire_candidate(16'h2202, 4'h7, 1'b0);

        // R2: recovery_begin blocks execution immediately, then a sealed
        // recovered chain rejects even the exact automatic continuation.
        issue_valid = 1'b1;
        store_parent_ref = 16'h2202;
        store_transition_id = 16'h2203;
        store_ctag = write_ctag(4'h8, 1'b0);
        recovery_begin = 1'b1;
        #1;
        if (!issue_rejected)
            $fatal(1, "recovery_begin failed to close live admission");
        tick();
        recovery_begin = 1'b0;
        issue_valid = 1'b0;
        restore_state(1'b1, 16'h3301, 4'h4, 1'b1, 2'b00, '0);
        try_issue(16'h3301, 16'h3302, 4'h5, 1'b0, 1'b0, 1'b0, '0, 1'b1);

        // A fresh explicit root may legitimately start a new unsealed chain.
        try_issue('0, 16'h4400, 4'h0, 1'b0, 1'b1, 1'b1, 16'hB220, 1'b0);
        retire_candidate(16'h4400, 4'h0, 1'b0);

        // R3: GEN=F recovery preserves the anti-wrap barrier.
        begin_recovery();
        restore_state(1'b1, 16'h5501, 4'hF, 1'b0, 2'b00, '0);
        if (!live_generation_exhausted)
            $fatal(1, "restored GEN=F did not expose exhaustion");
        try_issue(16'h5501, 16'h5502, 4'h0, 1'b0, 1'b0, 1'b0, '0, 1'b1);

        $display("CAPU_VCML_LIVE_RESUME_V15_PASS head=%h gen=%h sealed=%0d",
                 live_causal_head_transition_id, live_causal_head_gen, live_sealed_chain);
        $finish;
    end
endmodule
