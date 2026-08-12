`timescale 1ns/1ps

module capu_vcml_recovery_v10_tb;
    localparam int SLOTS = 4;
    localparam int AUTH_W = 16;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic recovery_begin, restore_valid;
    logic [SLOTS-1:0] restore_spent_valid;
    logic [(SLOTS*AUTH_W)-1:0] restore_spent_refs;

    logic issue_valid, gate_allow, execute_ok;
    logic [15:0] store_addr;
    logic [31:0] store_data;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [63:0] store_transition_id, store_parent_ref;
    logic explicit_new_cause, root_authorized;
    logic [AUTH_W-1:0] root_authorization_ref;
    logic [7:0] root_policy_epoch;
    logic causal_valid, commit_request, flush;

    logic buffer_valid, memory_write_enable, vcml_event_valid, issue_rejected;
    logic [15:0] memory_write_addr;
    logic [31:0] memory_write_data;
    logic [63:0] retired_transition_id, retired_parent_ref;
    logic retired_root_authorized;
    logic [AUTH_W-1:0] retired_root_authorization_ref;
    logic [7:0] retired_root_policy_epoch;

    logic replay_recovery_ready, replay_restore_snapshot_well_formed;
    logic replay_restore_accept, replay_restore_rejected;
    logic replay_authorization_accept, replay_authorization_ref_fresh;
    logic replay_detected, replay_capacity_exhausted;
    logic [2:0] replay_spent_count;
    logic replay_retirement_fault, replay_retirement_without_recovery_fault;

    capu_vcml_store_buffer_v10 #(
        .SPENT_AUTHORIZATION_SLOTS(SLOTS),
        .AUTHORIZATION_REF_WIDTH(AUTH_W)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .recovery_begin(recovery_begin),
        .restore_valid(restore_valid),
        .restore_spent_valid(restore_spent_valid),
        .restore_spent_refs(restore_spent_refs),
        .issue_valid(issue_valid), .gate_allow(gate_allow), .execute_ok(execute_ok),
        .store_addr(store_addr), .store_data(store_data),
        .store_ctag(store_ctag), .store_ctag_valid(store_ctag_valid),
        .store_transition_id(store_transition_id), .store_parent_ref(store_parent_ref),
        .explicit_new_cause(explicit_new_cause), .root_authorized(root_authorized),
        .root_authorization_ref(root_authorization_ref), .root_policy_epoch(root_policy_epoch),
        .causal_valid(causal_valid), .commit_request(commit_request), .flush(flush),
        .buffer_valid(buffer_valid),
        .memory_write_enable(memory_write_enable),
        .memory_write_addr(memory_write_addr), .memory_write_data(memory_write_data),
        .vcml_event_valid(vcml_event_valid),
        .retired_transition_id(retired_transition_id), .retired_parent_ref(retired_parent_ref),
        .retired_root_authorized(retired_root_authorized),
        .retired_root_authorization_ref(retired_root_authorization_ref),
        .retired_root_policy_epoch(retired_root_policy_epoch),
        .issue_rejected(issue_rejected),
        .replay_recovery_ready(replay_recovery_ready),
        .replay_restore_snapshot_well_formed(replay_restore_snapshot_well_formed),
        .replay_restore_accept(replay_restore_accept),
        .replay_restore_rejected(replay_restore_rejected),
        .replay_authorization_accept(replay_authorization_accept),
        .replay_authorization_ref_fresh(replay_authorization_ref_fresh),
        .replay_detected(replay_detected),
        .replay_capacity_exhausted(replay_capacity_exhausted),
        .replay_spent_count(replay_spent_count),
        .replay_retirement_fault(replay_retirement_fault),
        .replay_retirement_without_recovery_fault(replay_retirement_without_recovery_fault)
    );

    always #5 clk = ~clk;

    function automatic [15:0] root_ctag;
        begin
            root_ctag = {4'h4, 4'h2, 4'h0, 3'b000, 1'b0};
        end
    endfunction

    task automatic step; begin @(posedge clk); #1; end endtask

    task automatic clear_inputs; begin
        recovery_begin=0; restore_valid=0; restore_spent_valid='0; restore_spent_refs='0;
        issue_valid=0; gate_allow=0; execute_ok=0; store_addr='0; store_data='0;
        store_ctag='0; store_ctag_valid=0; store_transition_id='0; store_parent_ref='0;
        explicit_new_cause=0; root_authorized=0; root_authorization_ref='0; root_policy_epoch='0;
        causal_valid=0; commit_request=0; flush=0;
    end endtask

    task automatic restore_empty; begin
        clear_inputs(); restore_valid=1; restore_spent_valid='0; restore_spent_refs='0; step();
    end endtask

    task automatic restore_one(input [AUTH_W-1:0] ref0); begin
        clear_inputs(); restore_valid=1; restore_spent_valid=4'b0001;
        restore_spent_refs='0; restore_spent_refs[0 +: AUTH_W]=ref0; step();
    end endtask

    task automatic restore_two(input [AUTH_W-1:0] ref0, input [AUTH_W-1:0] ref1); begin
        clear_inputs(); restore_valid=1; restore_spent_valid=4'b0011;
        restore_spent_refs='0;
        restore_spent_refs[0 +: AUTH_W]=ref0;
        restore_spent_refs[AUTH_W +: AUTH_W]=ref1;
        step();
    end endtask

    task automatic issue_root(input [63:0] tid, input [AUTH_W-1:0] auth_ref, input [7:0] epoch); begin
        clear_inputs(); issue_valid=1; gate_allow=1; execute_ok=1;
        store_addr=tid[15:0]; store_data=32'hCA10_0000 | tid[15:0];
        store_ctag=root_ctag(); store_ctag_valid=1;
        store_transition_id=tid; store_parent_ref='0;
        explicit_new_cause=1; root_authorized=1;
        root_authorization_ref=auth_ref; root_policy_epoch=epoch; step();
    end endtask

    task automatic commit_store; begin
        clear_inputs(); causal_valid=1; commit_request=1; step();
    end endtask

    initial begin
        clear_inputs(); repeat(2) @(posedge clk); rst_n=1; step();

        if (replay_recovery_ready || replay_spent_count != 0)
            $fatal(1,"reset must start recovery fail-closed");
        $display("TRACE CAPU-V10 R0 reset recovery_ready=0 spent=0");

        // No root may enter before a recovery snapshot (empty snapshot is an
        // explicit trusted cold-start decision).
        issue_root(64'h10,16'hA110,8'h01);
        if (!issue_rejected || buffer_valid || replay_authorization_accept)
            $fatal(1,"root escaped before replay-state restore");
        $display("TRACE CAPU-V10 R1 pre_restore_root rejected=1");

        restore_empty();
        if (!replay_restore_accept || !replay_recovery_ready || replay_spent_count != 0)
            $fatal(1,"empty cold-start snapshot not accepted");
        $display("TRACE CAPU-V10 R2 empty_restore accepted=1 ready=1 spent=0");

        clear_inputs(); step();
        issue_root(64'h11,16'hA110,8'h02);
        if (!buffer_valid || !replay_authorization_accept || !replay_authorization_ref_fresh)
            $fatal(1,"fresh root A110 not admitted after cold-start restore");
        commit_store();
        if (!memory_write_enable || !vcml_event_valid || replay_spent_count != 1
            || retired_root_authorization_ref !== 16'hA110)
            $fatal(1,"root A110 retirement did not consume replay state");
        $display("TRACE CAPU-V10 R3 root_committed ref=A110 spent=1");

        // Real hardware reset clears local RAM. v0.10 must fail closed until a
        // replay snapshot is restored.
        clear_inputs(); rst_n=0; #2;
        if (replay_recovery_ready || replay_spent_count != 0)
            $fatal(1,"asynchronous reset did not clear local recovery state");
        rst_n=1; step();
        $display("TRACE CAPU-V10 R4 reset_again recovery_ready=0 spent=0");

        issue_root(64'h12,16'hA110,8'h03);
        if (!issue_rejected || buffer_valid || replay_authorization_accept)
            $fatal(1,"old ref escaped during recovery gap");
        $display("TRACE CAPU-V10 R5 recovery_gap_old_ref rejected=1");

        restore_one(16'hA110);
        if (!replay_restore_accept || !replay_recovery_ready || replay_spent_count != 1)
            $fatal(1,"snapshot(A110) restore failed");
        $display("TRACE CAPU-V10 R6 snapshot_restored ref=A110 spent=1");

        clear_inputs(); step();
        issue_root(64'h13,16'hA110,8'hFF);
        if (!issue_rejected || buffer_valid || replay_authorization_accept
            || !replay_detected || replay_authorization_ref_fresh)
            $fatal(1,"restored spent ref A110 replay admitted");
        $display("TRACE CAPU-V10 R7 restored_replay_A110 rejected=1");

        issue_root(64'h20,16'hA120,8'h04);
        if (!buffer_valid || !replay_authorization_accept)
            $fatal(1,"fresh A120 root blocked after restore");
        commit_store();
        if (!memory_write_enable || replay_spent_count != 2
            || retired_root_authorization_ref !== 16'hA120)
            $fatal(1,"fresh A120 retirement not added to recovered set");
        $display("TRACE CAPU-V10 R8 fresh_after_restore ref=A120 spent=2");

        // Warm recovery begins fail-closed. A duplicate snapshot is malformed
        // and must not reopen the gate.
        clear_inputs(); recovery_begin=1; step();
        if (replay_recovery_ready || replay_spent_count != 0)
            $fatal(1,"recovery_begin did not close/clear local replay gate");

        restore_two(16'hA110,16'hA110);
        if (replay_restore_snapshot_well_formed || !replay_restore_rejected
            || replay_restore_accept || replay_recovery_ready)
            $fatal(1,"duplicate-ref snapshot reopened recovery gate");
        $display("TRACE CAPU-V10 R9 malformed_duplicate_snapshot rejected=1 ready=0");

        issue_root(64'h21,16'hA121,8'h05);
        if (!issue_rejected || buffer_valid)
            $fatal(1,"root escaped after rejected recovery snapshot");

        restore_two(16'hA110,16'hA120);
        if (!replay_restore_accept || !replay_recovery_ready || replay_spent_count != 2)
            $fatal(1,"valid A110/A120 recovery snapshot failed");
        $display("TRACE CAPU-V10 R10 valid_snapshot_restored spent=2");

        clear_inputs(); step();
        issue_root(64'h22,16'hA120,8'h06);
        if (!issue_rejected || !replay_detected || buffer_valid)
            $fatal(1,"restored A120 replay admitted");
        $display("TRACE CAPU-V10 R11 restored_replay_A120 rejected=1");

        // Once live, a second restore cannot overwrite/erase the recovered set.
        clear_inputs(); restore_valid=1; restore_spent_valid='0; restore_spent_refs='0; step();
        if (!replay_restore_rejected || replay_restore_accept
            || !replay_recovery_ready || replay_spent_count != 2)
            $fatal(1,"live replay state was overwriteable by restore");
        $display("TRACE CAPU-V10 R12 live_restore_overwrite rejected=1 spent=2");

        if (replay_retirement_fault || replay_retirement_without_recovery_fault)
            $fatal(1,"unexpected retirement recovery fault");

        $display("CAPU_VCML_BRIDGE_V10_RECOVERY_PASS");
        $finish;
    end
endmodule
