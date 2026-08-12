`timescale 1ns/1ps

module capu_vcml_recovery_v11_tb;
    localparam int ADDR_W = 16;
    localparam int DATA_W = 32;
    localparam int TID_W = 16;
    localparam int PARENT_W = 16;
    localparam int AUTH_W = 16;
    localparam int POLICY_W = 8;
    localparam int SLOTS = 4;
    localparam int CP_REF_W = 16;
    localparam int CP_EPOCH_W = 8;

    logic clk = 0;
    always #5 clk = ~clk;

    logic rst_n = 0;
    logic recovery_begin, restore_valid;
    logic [SLOTS-1:0] restore_spent_valid;
    logic [(SLOTS*AUTH_W)-1:0] restore_spent_refs;
    logic checkpoint_trusted, cold_start_authorized;
    logic [CP_REF_W-1:0] snapshot_checkpoint_ref, anchor_checkpoint_ref;
    logic [CP_EPOCH_W-1:0] snapshot_checkpoint_epoch, anchor_checkpoint_epoch;
    logic anchor_valid;

    logic issue_valid, gate_allow, execute_ok;
    logic [ADDR_W-1:0] store_addr;
    logic [DATA_W-1:0] store_data;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [TID_W-1:0] store_transition_id;
    logic [PARENT_W-1:0] store_parent_ref;
    logic explicit_new_cause, root_authorized;
    logic [AUTH_W-1:0] root_authorization_ref;
    logic [POLICY_W-1:0] root_policy_epoch;
    logic causal_valid, commit_request, flush;

    wire buffer_valid, memory_write_enable, vcml_event_valid, issue_rejected;
    wire [ADDR_W-1:0] memory_write_addr;
    wire [DATA_W-1:0] memory_write_data;
    wire [TID_W-1:0] retired_transition_id;
    wire [PARENT_W-1:0] retired_parent_ref;
    wire retired_root_authorized;
    wire [AUTH_W-1:0] retired_root_authorization_ref;
    wire [POLICY_W-1:0] retired_root_policy_epoch;

    wire checkpoint_restore_accept, checkpoint_restore_rejected;
    wire checkpoint_rollback_detected, checkpoint_anchor_mismatch;
    wire checkpoint_cold_start_accept;
    wire replay_recovery_ready, replay_restore_snapshot_well_formed;
    wire replay_restore_accept, replay_restore_rejected;
    wire replay_authorization_accept, replay_authorization_ref_fresh;
    wire replay_detected, replay_capacity_exhausted;
    wire [$clog2(SLOTS+1)-1:0] replay_spent_count;
    wire replay_retirement_fault, replay_retirement_without_recovery_fault;

    capu_vcml_store_buffer_v11 #(
        .ADDR_WIDTH(ADDR_W), .DATA_WIDTH(DATA_W),
        .TRANSITION_ID_WIDTH(TID_W), .PARENT_REF_WIDTH(PARENT_W),
        .AUTHORIZATION_REF_WIDTH(AUTH_W), .POLICY_EPOCH_WIDTH(POLICY_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS),
        .CHECKPOINT_REF_WIDTH(CP_REF_W), .CHECKPOINT_EPOCH_WIDTH(CP_EPOCH_W)
    ) dut (.*);

    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task check_cond(input logic cond, input [255:0] msg);
        begin
            if (!cond) begin
                $display("FAIL %0s", msg);
                $fatal(1);
            end
        end
    endtask

    task clear_issue;
        begin
            issue_valid = 0;
            explicit_new_cause = 0;
            root_authorized = 0;
            root_authorization_ref = 0;
            root_policy_epoch = 0;
            causal_valid = 0;
            commit_request = 0;
            flush = 0;
        end
    endtask

    initial begin
        recovery_begin = 0;
        restore_valid = 0;
        restore_spent_valid = 0;
        restore_spent_refs = 0;
        checkpoint_trusted = 0;
        cold_start_authorized = 0;
        snapshot_checkpoint_ref = 0;
        snapshot_checkpoint_epoch = 0;
        anchor_valid = 0;
        anchor_checkpoint_ref = 0;
        anchor_checkpoint_epoch = 0;
        gate_allow = 1;
        execute_ok = 1;
        store_addr = 16'h0042;
        store_data = 32'hCAFE_0042;
        store_ctag = 16'h4200;
        store_ctag_valid = 1;
        store_transition_id = 16'h0100;
        store_parent_ref = 0;
        clear_issue();

        repeat (2) tick();
        rst_n = 1;
        tick();
        check_cond(!replay_recovery_ready, "reset must start recovery fail-closed");

        anchor_valid = 1;
        anchor_checkpoint_ref = 16'hC001;
        anchor_checkpoint_epoch = 8;
        restore_spent_valid = 4'b0001;
        restore_spent_refs[0 +: AUTH_W] = 16'hA110;
        checkpoint_trusted = 1;
        restore_valid = 1;

        snapshot_checkpoint_ref = 16'hC000;
        snapshot_checkpoint_epoch = 7;
        #1;
        check_cond(checkpoint_rollback_detected, "older checkpoint epoch must flag rollback");
        check_cond(!checkpoint_restore_accept, "older checkpoint must not restore");
        tick();
        check_cond(!replay_recovery_ready, "rollback must not open replay recovery");
        $display("TRACE V11 stale_checkpoint rollback=1 ready=0");

        snapshot_checkpoint_ref = 16'hC002;
        snapshot_checkpoint_epoch = 8;
        #1;
        check_cond(checkpoint_anchor_mismatch, "wrong checkpoint ref must mismatch anchor");
        check_cond(!checkpoint_restore_accept, "wrong checkpoint ref must reject");
        tick();
        $display("TRACE V11 wrong_ref rejected=1");

        snapshot_checkpoint_ref = 16'hC001;
        checkpoint_trusted = 0;
        #1;
        check_cond(!checkpoint_restore_accept, "untrusted exact checkpoint must reject");
        tick();
        $display("TRACE V11 untrusted_exact rejected=1");

        checkpoint_trusted = 1;
        #1;
        check_cond(checkpoint_restore_accept, "exact trusted checkpoint must pass freshness gate");
        check_cond(replay_restore_accept, "exact trusted checkpoint must reach replay restore");
        tick();
        restore_valid = 0;
        #1;
        check_cond(replay_recovery_ready, "accepted checkpoint must restore replay state");
        check_cond(replay_spent_count == 1, "restored spent set must contain A110");
        $display("TRACE V11 exact_anchor restored=1 spent=1");

        issue_valid = 1;
        explicit_new_cause = 1;
        root_authorized = 1;
        root_authorization_ref = 16'hA110;
        root_policy_epoch = 8'h22;
        #1;
        check_cond(replay_detected, "restored A110 must be detected as replay");
        check_cond(issue_rejected, "restored A110 must not enter STORE buffer");
        tick();
        clear_issue();
        $display("TRACE V11 restored_replay_A110 rejected=1");

        issue_valid = 1;
        explicit_new_cause = 1;
        root_authorized = 1;
        root_authorization_ref = 16'hA120;
        root_policy_epoch = 8'h23;
        store_transition_id = 16'h0101;
        #1;
        check_cond(replay_authorization_accept, "fresh ref must pass recovered replay guard");
        tick();
        issue_valid = 0;
        explicit_new_cause = 0;
        root_authorized = 0;
        root_authorization_ref = 0;
        causal_valid = 1;
        commit_request = 1;
        tick();
        check_cond(memory_write_enable && vcml_event_valid, "fresh root commit must publish STORE + vCML event");
        check_cond(retired_root_authorization_ref == 16'hA120, "retired auth ref must bind exactly");
        clear_issue();
        tick();
        check_cond(replay_spent_count == 2, "fresh committed A120 must join spent set");
        $display("TRACE V11 fresh_after_restore ref=A120 spent=2");

        recovery_begin = 1;
        tick();
        recovery_begin = 0;
        anchor_checkpoint_ref = 16'hC002;
        anchor_checkpoint_epoch = 9;
        restore_spent_valid = 4'b0011;
        restore_spent_refs[0 +: AUTH_W] = 16'hA110;
        restore_spent_refs[AUTH_W +: AUTH_W] = 16'hA120;
        restore_valid = 1;
        checkpoint_trusted = 1;
        snapshot_checkpoint_ref = 16'hC001;
        snapshot_checkpoint_epoch = 8;
        #1;
        check_cond(checkpoint_rollback_detected, "old checkpoint after anchor advance must rollback-reject");
        tick();
        check_cond(!replay_recovery_ready, "old checkpoint must leave recovery closed");
        $display("TRACE V11 anchor_advanced old_checkpoint_rejected=1");

        snapshot_checkpoint_ref = 16'hC002;
        snapshot_checkpoint_epoch = 9;
        #1;
        check_cond(checkpoint_restore_accept && replay_restore_accept, "new exact anchor must restore");
        tick();
        restore_valid = 0;
        check_cond(replay_recovery_ready && replay_spent_count == 2, "new anchor snapshot must restore both refs");
        $display("TRACE V11 new_anchor restored=1 spent=2");

        rst_n = 0;
        tick();
        rst_n = 1;
        anchor_valid = 0;
        restore_spent_valid = 0;
        restore_spent_refs = 0;
        snapshot_checkpoint_ref = 0;
        snapshot_checkpoint_epoch = 0;
        checkpoint_trusted = 0;
        restore_valid = 1;
        cold_start_authorized = 0;
        #1;
        check_cond(!checkpoint_restore_accept, "cold start without explicit authorization must reject");
        tick();
        cold_start_authorized = 1;
        #1;
        check_cond(checkpoint_cold_start_accept, "explicit empty cold start must be reachable");
        check_cond(replay_restore_accept, "authorized cold start must reach replay restore");
        tick();
        restore_valid = 0;
        check_cond(replay_recovery_ready && replay_spent_count == 0, "cold start opens empty replay window explicitly");
        $display("TRACE V11 explicit_cold_start ready=1 spent=0");

        $display("CAPU_VCML_BRIDGE_V11_CHECKPOINT_PASS");
        $finish;
    end
endmodule
