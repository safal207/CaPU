`timescale 1ns/1ps

module capu_vcml_store_buffer_tb;
    localparam int ADDR_WIDTH = 16;
    localparam int DATA_WIDTH = 32;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic issue_valid;
    logic gate_allow;
    logic execute_ok;
    logic [ADDR_WIDTH-1:0] store_addr;
    logic [DATA_WIDTH-1:0] store_data;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [63:0] store_transition_id;
    logic [63:0] store_parent_ref;
    logic causal_valid;
    logic commit_request;
    logic flush;

    logic buffer_valid;
    logic [ADDR_WIDTH-1:0] buffered_addr;
    logic [DATA_WIDTH-1:0] buffered_data;
    logic [15:0] buffered_ctag;
    logic buffered_ctag_valid;
    logic [63:0] buffered_transition_id;
    logic [63:0] buffered_parent_ref;
    logic memory_write_enable;
    logic [ADDR_WIDTH-1:0] memory_write_addr;
    logic [DATA_WIDTH-1:0] memory_write_data;
    logic vcml_event_valid;
    logic [15:0] retired_ctag;
    logic [63:0] retired_transition_id;
    logic [63:0] retired_parent_ref;
    logic ctag_semantic_accept;
    logic issue_rejected;

    capu_vcml_store_buffer dut (
        .clk(clk),
        .rst_n(rst_n),
        .issue_valid(issue_valid),
        .gate_allow(gate_allow),
        .execute_ok(execute_ok),
        .store_addr(store_addr),
        .store_data(store_data),
        .store_ctag(store_ctag),
        .store_ctag_valid(store_ctag_valid),
        .store_transition_id(store_transition_id),
        .store_parent_ref(store_parent_ref),
        .causal_valid(causal_valid),
        .commit_request(commit_request),
        .flush(flush),
        .buffer_valid(buffer_valid),
        .buffered_addr(buffered_addr),
        .buffered_data(buffered_data),
        .buffered_ctag(buffered_ctag),
        .buffered_ctag_valid(buffered_ctag_valid),
        .buffered_transition_id(buffered_transition_id),
        .buffered_parent_ref(buffered_parent_ref),
        .memory_write_enable(memory_write_enable),
        .memory_write_addr(memory_write_addr),
        .memory_write_data(memory_write_data),
        .vcml_event_valid(vcml_event_valid),
        .retired_ctag(retired_ctag),
        .retired_transition_id(retired_transition_id),
        .retired_parent_ref(retired_parent_ref),
        .ctag_semantic_accept(ctag_semantic_accept),
        .issue_rejected(issue_rejected)
    );

    always #5 clk = ~clk;

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic clear_inputs;
        begin
            issue_valid = 1'b0;
            gate_allow = 1'b0;
            execute_ok = 1'b0;
            store_addr = '0;
            store_data = '0;
            store_ctag = '0;
            store_ctag_valid = 1'b0;
            store_transition_id = '0;
            store_parent_ref = '0;
            causal_valid = 1'b0;
            commit_request = 1'b0;
            flush = 1'b0;
        end
    endtask

    task automatic try_rejected_ctag(input logic [15:0] tag, input string label);
        begin
            clear_inputs();
            issue_valid = 1'b1;
            gate_allow = 1'b1;
            execute_ok = 1'b1;
            store_addr = 16'h0010;
            store_data = 32'hAAAA_0010;
            store_ctag = tag;
            store_ctag_valid = 1'b1;
            store_transition_id = 64'h10;
            store_parent_ref = 64'h01;
            #1;
            if (ctag_semantic_accept)
                $fatal(1, "%s: invalid CTAG was semantically accepted", label);
            step();
            if (!issue_rejected || buffer_valid || memory_write_enable || vcml_event_valid)
                $fatal(1, "%s: invalid CTAG did not fail closed", label);
        end
    endtask

    initial begin
        clear_inputs();
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        step();

        if (buffer_valid || memory_write_enable || vcml_event_valid)
            $fatal(1, "reset did not produce empty/no-effect state");
        $display("TRACE CAPU-VCML S0 reset buffer=0 memory_write=0 event=0");

        // Missing metadata fails closed before local CTAG semantics are trusted.
        issue_valid = 1'b1;
        gate_allow = 1'b1;
        execute_ok = 1'b1;
        store_addr = 16'h0010;
        store_data = 32'hAAAA_0010;
        store_ctag = 16'h4210; // USER / WRITE / GEN=1
        store_ctag_valid = 1'b0;
        store_transition_id = 64'h10;
        store_parent_ref = 64'h01;
        #1;
        if (ctag_semantic_accept)
            $fatal(1, "missing CTAG metadata was accepted");
        step();
        if (!issue_rejected || buffer_valid || memory_write_enable || vcml_event_valid)
            $fatal(1, "missing CTAG metadata did not fail closed");
        $display("TRACE CAPU-VCML S1 missing_metadata rejected=1 memory_write=0");

        // v0.3 local semantic rejection cases.
        try_rejected_ctag(16'hF210, "reserved DOM"); // RESERVED / WRITE
        $display("TRACE CAPU-VCML S2 reserved_dom rejected=1");
        try_rejected_ctag(16'h4010, "CLASS NONE");   // USER / NONE
        $display("TRACE CAPU-VCML S3 class_none rejected=1");
        try_rejected_ctag(16'h4110, "non-WRITE class"); // USER / READ
        $display("TRACE CAPU-VCML S4 non_write rejected=1");

        // Canonical normal STORE: DOM=USER(4), CLASS=WRITE(2), GEN=1.
        clear_inputs();
        issue_valid = 1'b1;
        gate_allow = 1'b1;
        execute_ok = 1'b1;
        store_addr = 16'h0042;
        store_data = 32'hCAFE_0042;
        store_ctag = 16'h4210;
        store_ctag_valid = 1'b1;
        store_transition_id = 64'h42;
        store_parent_ref = 64'h11;
        #1;
        if (!ctag_semantic_accept)
            $fatal(1, "canonical WRITE CTAG was rejected");
        step();

        if (!buffer_valid || !buffered_ctag_valid)
            $fatal(1, "valid CTAG STORE did not enter speculative buffer");
        if (buffered_ctag !== 16'h4210
            || buffered_transition_id !== 64'h42
            || buffered_parent_ref !== 64'h11)
            $fatal(1, "causal metadata was not buffered exactly");
        if (memory_write_enable || vcml_event_valid)
            $fatal(1, "speculative issue became externally visible");
        $display("TRACE CAPU-VCML S5 speculative ctag=4210 transition=42 parent=11");

        // Commit request alone remains insufficient without causal validation.
        clear_inputs();
        commit_request = 1'b1;
        causal_valid = 1'b0;
        step();
        if (!buffer_valid || memory_write_enable || vcml_event_valid)
            $fatal(1, "causal-invalid STORE retired");
        $display("TRACE CAPU-VCML S6 causal_invalid memory_write=0 event=0");

        // A valid causal commit retires the STORE and emits the same metadata.
        causal_valid = 1'b1;
        commit_request = 1'b1;
        step();
        if (!memory_write_enable || !vcml_event_valid)
            $fatal(1, "valid causal commit produced no bridge event");
        if (memory_write_addr !== 16'h0042 || memory_write_data !== 32'hCAFE_0042)
            $fatal(1, "retired memory payload mismatch");
        if (retired_ctag !== 16'h4210
            || retired_transition_id !== 64'h42
            || retired_parent_ref !== 64'h11)
            $fatal(1, "retired causal metadata mismatch");
        if (buffer_valid)
            $fatal(1, "retired STORE remained speculative");
        $display("TRACE CAPU-VCML S7 committed ctag=4210 transition=42 parent=11 memory_write=1 event=1");

        // Event/write pulse is exactly one cycle.
        clear_inputs();
        step();
        if (memory_write_enable || vcml_event_valid)
            $fatal(1, "retirement event was not a one-cycle pulse");

        // SEAL=1 controls continuation semantics but does not reject the current
        // valid WRITE at this boundary. The bit must be preserved exactly.
        issue_valid = 1'b1;
        gate_allow = 1'b1;
        execute_ok = 1'b1;
        store_addr = 16'h0055;
        store_data = 32'hBEEF_0055;
        store_ctag = 16'h4211; // same valid WRITE, SEAL=1
        store_ctag_valid = 1'b1;
        store_transition_id = 64'h55;
        store_parent_ref = 64'h42;
        #1;
        if (!ctag_semantic_accept)
            $fatal(1, "SEALed valid WRITE CTAG was incorrectly rejected");
        step();
        if (!buffer_valid || buffered_ctag !== 16'h4211)
            $fatal(1, "SEALed CTAG was not preserved in speculation");

        // Flush destroys speculative metadata and cannot emit an event.
        clear_inputs();
        flush = 1'b1;
        causal_valid = 1'b1;
        commit_request = 1'b1;
        step();
        if (buffer_valid || buffered_ctag_valid || memory_write_enable || vcml_event_valid)
            $fatal(1, "flush did not discard causal STORE metadata fail-closed");
        $display("TRACE CAPU-VCML S8 sealed_then_flushed memory_write=0 event=0");

        $display("CAPU_VCML_BRIDGE_V03_RTL_PASS");
        $finish;
    end
endmodule
