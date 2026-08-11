`timescale 1ns/1ps

module capu_vcml_store_buffer_tb;
    logic clk = 1'b0, rst_n = 1'b0;
    logic issue_valid, gate_allow, execute_ok;
    logic [15:0] store_addr;
    logic [31:0] store_data;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [63:0] store_transition_id, store_parent_ref;
    logic explicit_new_cause, causal_valid, commit_request, flush;

    logic buffer_valid, memory_write_enable, vcml_event_valid;
    logic [15:0] buffered_addr, buffered_ctag, memory_write_addr, retired_ctag;
    logic [31:0] buffered_data, memory_write_data;
    logic buffered_ctag_valid;
    logic [63:0] buffered_transition_id, buffered_parent_ref;
    logic [63:0] retired_transition_id, retired_parent_ref;
    logic ctag_semantic_accept, sealed_chain, continuation_blocked;
    logic causal_head_valid, parent_policy_accept, issue_rejected;
    logic [63:0] causal_head_transition_id;

    capu_vcml_store_buffer dut (
        .clk(clk), .rst_n(rst_n),
        .issue_valid(issue_valid), .gate_allow(gate_allow), .execute_ok(execute_ok),
        .store_addr(store_addr), .store_data(store_data),
        .store_ctag(store_ctag), .store_ctag_valid(store_ctag_valid),
        .store_transition_id(store_transition_id), .store_parent_ref(store_parent_ref),
        .explicit_new_cause(explicit_new_cause),
        .causal_valid(causal_valid), .commit_request(commit_request), .flush(flush),
        .buffer_valid(buffer_valid), .buffered_addr(buffered_addr), .buffered_data(buffered_data),
        .buffered_ctag(buffered_ctag), .buffered_ctag_valid(buffered_ctag_valid),
        .buffered_transition_id(buffered_transition_id), .buffered_parent_ref(buffered_parent_ref),
        .memory_write_enable(memory_write_enable), .memory_write_addr(memory_write_addr),
        .memory_write_data(memory_write_data), .vcml_event_valid(vcml_event_valid),
        .retired_ctag(retired_ctag), .retired_transition_id(retired_transition_id),
        .retired_parent_ref(retired_parent_ref), .ctag_semantic_accept(ctag_semantic_accept),
        .sealed_chain(sealed_chain), .continuation_blocked(continuation_blocked),
        .causal_head_valid(causal_head_valid), .causal_head_transition_id(causal_head_transition_id),
        .parent_policy_accept(parent_policy_accept), .issue_rejected(issue_rejected)
    );

    always #5 clk = ~clk;
    task automatic step; begin @(posedge clk); #1; end endtask
    task automatic clear_inputs; begin
        issue_valid=0; gate_allow=0; execute_ok=0; store_addr='0; store_data='0;
        store_ctag='0; store_ctag_valid=0; store_transition_id='0; store_parent_ref='0;
        explicit_new_cause=0; causal_valid=0; commit_request=0; flush=0;
    end endtask
    task automatic issue_store(input [15:0] tag,input [63:0] tid,input [63:0] parent,input bit root); begin
        clear_inputs(); issue_valid=1; gate_allow=1; execute_ok=1;
        store_addr=tid[15:0]; store_data=32'hCA00_0000|tid[15:0]; store_ctag=tag; store_ctag_valid=1;
        store_transition_id=tid; store_parent_ref=parent; explicit_new_cause=root; step();
    end endtask
    task automatic commit_store; begin clear_inputs(); causal_valid=1; commit_request=1; step(); end endtask

    initial begin
        clear_inputs(); repeat(2) @(posedge clk); rst_n=1; step();
        if (causal_head_valid || sealed_chain || buffer_valid) $fatal(1,"reset state invalid");
        $display("TRACE CAPU-V05 S0 reset head_valid=0 sealed=0");

        // No committed head: ordinary continuation must fail closed.
        issue_store(16'h4210,64'h01,64'h00,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"headless continuation admitted");
        $display("TRACE CAPU-V05 S1 headless_child rejected=1");

        // Invalid CTAG remains rejected even on root path.
        issue_store(16'hF210,64'h02,64'h00,1);
        if (!issue_rejected || buffer_valid) $fatal(1,"invalid CTAG root admitted");
        $display("TRACE CAPU-V05 S2 invalid_ctag rejected=1");

        // Explicit roots require parent_ref==0.
        issue_store(16'h4210,64'h03,64'h99,1);
        if (!issue_rejected || buffer_valid) $fatal(1,"nonzero-parent root admitted");
        $display("TRACE CAPU-V05 S3 malformed_root rejected=1");

        // First explicit root creates committed causal head.
        issue_store(16'h4210,64'h10,64'h00,1);
        if (!buffer_valid || !parent_policy_accept) $fatal(1,"explicit root admission failed");
        commit_store();
        if (!memory_write_enable || !causal_head_valid || causal_head_transition_id!==64'h10)
            $fatal(1,"root commit did not establish head");
        if (sealed_chain) $fatal(1,"unsealed root closed chain");
        $display("TRACE CAPU-V05 S4 root_committed head=10 sealed=0");

        clear_inputs(); step();
        // Exact parent continuation accepted.
        issue_store(16'h4220,64'h11,64'h10,0);
        if (!buffer_valid || !parent_policy_accept) $fatal(1,"valid parent continuation blocked");
        $display("TRACE CAPU-V05 S5 valid_parent admitted=1");
        clear_inputs(); flush=1; step();
        if (causal_head_transition_id!==64'h10 || !causal_head_valid) $fatal(1,"flush mutated committed head");

        // Wrong parent rejected before speculation.
        issue_store(16'h4220,64'h12,64'h09,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"wrong parent admitted");
        $display("TRACE CAPU-V05 S6 wrong_parent rejected=1 head=10");

        // Commit a sealed child with exact parent.
        issue_store(16'h4231,64'h20,64'h10,0);
        if (!buffer_valid) $fatal(1,"sealed exact-parent child not admitted");
        commit_store();
        if (!memory_write_enable || !sealed_chain || causal_head_transition_id!==64'h20)
            $fatal(1,"sealed child did not commit head+seal");
        $display("TRACE CAPU-V05 S7 sealed_commit head=20 sealed=1");

        clear_inputs(); step();
        // Even exact parent cannot auto-continue a sealed chain.
        issue_store(16'h4240,64'h21,64'h20,0);
        if (!issue_rejected || buffer_valid || !continuation_blocked)
            $fatal(1,"sealed exact-parent child escaped");
        $display("TRACE CAPU-V05 S8 sealed_correct_parent rejected=1");

        // Explicit new root may speculate, but flush preserves old committed head+seal.
        issue_store(16'h4240,64'h30,64'h00,1);
        if (!buffer_valid || !sealed_chain) $fatal(1,"new root under seal not admitted");
        clear_inputs(); flush=1; step();
        if (!sealed_chain || causal_head_transition_id!==64'h20)
            $fatal(1,"flush weakened committed head/seal");
        $display("TRACE CAPU-V05 S9 root_flushed old_head=20 old_seal=1");

        // Committed explicit root replaces head and opens fresh chain because SEAL=0.
        issue_store(16'h4250,64'h31,64'h00,1);
        if (!buffer_valid) $fatal(1,"replacement root not admitted");
        commit_store();
        if (!memory_write_enable || sealed_chain || causal_head_transition_id!==64'h31)
            $fatal(1,"replacement root did not establish fresh head");
        if (retired_transition_id!==64'h31 || retired_parent_ref!==64'h00)
            $fatal(1,"replacement root retirement metadata mismatch");
        $display("TRACE CAPU-V05 S10 root_committed head=31 sealed=0");

        clear_inputs(); step();
        issue_store(16'h4260,64'h32,64'h31,0);
        if (!buffer_valid) $fatal(1,"fresh exact-parent continuation blocked");
        $display("TRACE CAPU-V05 S11 fresh_child admitted=1");
        clear_inputs(); flush=1; step();

        $display("CAPU_VCML_BRIDGE_V05_RTL_PASS");
        $finish;
    end
endmodule
