`timescale 1ns/1ps

module capu_vcml_store_buffer_tb;
    localparam int ADDR_WIDTH = 16;
    localparam int DATA_WIDTH = 32;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic issue_valid, gate_allow, execute_ok;
    logic [ADDR_WIDTH-1:0] store_addr;
    logic [DATA_WIDTH-1:0] store_data;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [63:0] store_transition_id, store_parent_ref;
    logic explicit_new_cause;
    logic causal_valid, commit_request, flush;

    logic buffer_valid;
    logic [ADDR_WIDTH-1:0] buffered_addr;
    logic [DATA_WIDTH-1:0] buffered_data;
    logic [15:0] buffered_ctag;
    logic buffered_ctag_valid;
    logic [63:0] buffered_transition_id, buffered_parent_ref;
    logic memory_write_enable;
    logic [ADDR_WIDTH-1:0] memory_write_addr;
    logic [DATA_WIDTH-1:0] memory_write_data;
    logic vcml_event_valid;
    logic [15:0] retired_ctag;
    logic [63:0] retired_transition_id, retired_parent_ref;
    logic ctag_semantic_accept, sealed_chain, continuation_blocked, issue_rejected;

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
        .issue_rejected(issue_rejected)
    );

    always #5 clk = ~clk;

    task automatic step;
        begin @(posedge clk); #1; end
    endtask

    task automatic clear_inputs;
        begin
            issue_valid = 0; gate_allow = 0; execute_ok = 0;
            store_addr = '0; store_data = '0; store_ctag = '0; store_ctag_valid = 0;
            store_transition_id = '0; store_parent_ref = '0; explicit_new_cause = 0;
            causal_valid = 0; commit_request = 0; flush = 0;
        end
    endtask

    task automatic issue_store(
        input logic [15:0] tag,
        input logic [63:0] transition_id,
        input logic [63:0] parent_ref,
        input logic new_cause
    );
        begin
            clear_inputs();
            issue_valid = 1; gate_allow = 1; execute_ok = 1;
            store_addr = transition_id[15:0];
            store_data = 32'hCA00_0000 | transition_id[15:0];
            store_ctag = tag; store_ctag_valid = 1;
            store_transition_id = transition_id; store_parent_ref = parent_ref;
            explicit_new_cause = new_cause;
            step();
        end
    endtask

    task automatic commit_store;
        begin
            clear_inputs(); causal_valid = 1; commit_request = 1; step();
        end
    endtask

    initial begin
        clear_inputs();
        repeat (2) @(posedge clk);
        rst_n = 1;
        step();
        if (sealed_chain || buffer_valid || memory_write_enable)
            $fatal(1, "reset state invalid");
        $display("TRACE CAPU-V04 S0 reset sealed=0");

        // Invalid CTAG remains fail-closed under v0.4.
        issue_store(16'hF210, 64'h01, 64'h00, 0);
        if (!issue_rejected || buffer_valid)
            $fatal(1, "reserved DOM escaped validator");
        $display("TRACE CAPU-V04 S1 invalid_ctag rejected=1");

        // Unsealed commit keeps automatic continuation open.
        issue_store(16'h4210, 64'h10, 64'h00, 0); // USER/WRITE/GEN1/SEAL0
        if (!buffer_valid || sealed_chain)
            $fatal(1, "unsealed STORE admission failed");
        commit_store();
        if (!memory_write_enable || sealed_chain)
            $fatal(1, "unsealed commit unexpectedly sealed chain");
        $display("TRACE CAPU-V04 S2 unsealed_commit continuation_open=1");

        clear_inputs(); step();
        issue_store(16'h4220, 64'h11, 64'h10, 0);
        if (!buffer_valid || issue_rejected)
            $fatal(1, "automatic continuation after unsealed commit was blocked");
        $display("TRACE CAPU-V04 S3 unsealed_child admitted=1");
        clear_inputs(); flush = 1; step();
        if (buffer_valid || sealed_chain)
            $fatal(1, "flush of unsealed speculative child failed");

        // Commit a sealed transition. Current WRITE is valid and visible, then
        // the chain becomes closed for automatic continuation.
        issue_store(16'h4231, 64'h20, 64'h10, 0); // SEAL=1
        if (!buffer_valid)
            $fatal(1, "sealed STORE was not admitted");
        commit_store();
        if (!memory_write_enable || !sealed_chain)
            $fatal(1, "sealed commit did not close chain");
        $display("TRACE CAPU-V04 S4 sealed_commit sealed_chain=1");

        clear_inputs(); step();

        // Ordinary child after seal must fail before speculation.
        issue_store(16'h4240, 64'h21, 64'h20, 0);
        if (!issue_rejected || buffer_valid || memory_write_enable || vcml_event_valid)
            $fatal(1, "automatic child escaped sealed chain");
        if (!sealed_chain || !continuation_blocked)
            $fatal(1, "sealed continuation state not preserved");
        $display("TRACE CAPU-V04 S5 sealed_child rejected=1 memory_write=0");

        // Explicit new cause may speculate, but a flush must NOT clear the old
        // committed seal because no replacement cause committed.
        issue_store(16'h4240, 64'h30, 64'h00, 1);
        if (!buffer_valid || issue_rejected || !sealed_chain)
            $fatal(1, "explicit new cause was not admitted under sealed state");
        clear_inputs(); flush = 1; step();
        if (buffer_valid || !sealed_chain)
            $fatal(1, "flushed new cause incorrectly cleared committed seal");
        $display("TRACE CAPU-V04 S6 new_cause_flushed old_seal_preserved=1");

        // A committed explicit new cause/root replaces the old chain state.
        issue_store(16'h4250, 64'h31, 64'h00, 1); // SEAL=0
        if (!buffer_valid || !sealed_chain)
            $fatal(1, "new cause admission should not clear seal speculatively");
        commit_store();
        if (!memory_write_enable || sealed_chain)
            $fatal(1, "committed explicit new cause did not open fresh chain");
        if (retired_transition_id !== 64'h31 || retired_parent_ref !== 64'h00)
            $fatal(1, "new-cause retirement metadata mismatch");
        $display("TRACE CAPU-V04 S7 new_cause_committed sealed_chain=0 memory_write=1");

        clear_inputs(); step();
        issue_store(16'h4260, 64'h32, 64'h31, 0);
        if (!buffer_valid || issue_rejected)
            $fatal(1, "continuation after committed new cause was blocked");
        $display("TRACE CAPU-V04 S8 fresh_chain_child admitted=1");

        clear_inputs(); flush = 1; step();
        if (buffer_valid || memory_write_enable || vcml_event_valid)
            $fatal(1, "final flush failed closed");

        $display("CAPU_VCML_BRIDGE_V04_RTL_PASS");
        $finish;
    end
endmodule
