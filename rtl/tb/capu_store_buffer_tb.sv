`timescale 1ns/1ps

module capu_store_buffer_tb;
    localparam int ADDR_WIDTH = 16;
    localparam int DATA_WIDTH = 32;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic                  issue_valid;
    logic                  gate_allow;
    logic                  execute_ok;
    logic [ADDR_WIDTH-1:0] store_addr;
    logic [DATA_WIDTH-1:0] store_data;
    logic                  causal_valid;
    logic                  commit_request;
    logic                  flush;

    logic                  buffer_valid;
    logic [ADDR_WIDTH-1:0] buffered_addr;
    logic [DATA_WIDTH-1:0] buffered_data;
    logic                  memory_write_enable;
    logic [ADDR_WIDTH-1:0] memory_write_addr;
    logic [DATA_WIDTH-1:0] memory_write_data;
    logic                  issue_rejected;

    capu_store_buffer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .issue_valid(issue_valid),
        .gate_allow(gate_allow),
        .execute_ok(execute_ok),
        .store_addr(store_addr),
        .store_data(store_data),
        .causal_valid(causal_valid),
        .commit_request(commit_request),
        .flush(flush),
        .buffer_valid(buffer_valid),
        .buffered_addr(buffered_addr),
        .buffered_data(buffered_data),
        .memory_write_enable(memory_write_enable),
        .memory_write_addr(memory_write_addr),
        .memory_write_data(memory_write_data),
        .issue_rejected(issue_rejected)
    );

    always #5 clk = ~clk;

    task automatic step(
        input logic                  t_issue_valid,
        input logic                  t_gate_allow,
        input logic                  t_execute_ok,
        input logic [ADDR_WIDTH-1:0] t_store_addr,
        input logic [DATA_WIDTH-1:0] t_store_data,
        input logic                  t_causal_valid,
        input logic                  t_commit_request,
        input logic                  t_flush
    );
        begin
            issue_valid   = t_issue_valid;
            gate_allow    = t_gate_allow;
            execute_ok    = t_execute_ok;
            store_addr    = t_store_addr;
            store_data    = t_store_data;
            causal_valid  = t_causal_valid;
            commit_request = t_commit_request;
            flush         = t_flush;
            @(posedge clk);
            #1;
        end
    endtask

    task automatic expect_no_write(input string label);
        begin
            if (memory_write_enable !== 1'b0)
                $fatal(1, "%s: unexpected memory-visible write", label);
        end
    endtask

    initial begin
        issue_valid = 1'b0;
        gate_allow = 1'b0;
        execute_ok = 1'b0;
        store_addr = '0;
        store_data = '0;
        causal_valid = 1'b0;
        commit_request = 1'b0;
        flush = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        if (buffer_valid !== 1'b0 || memory_write_enable !== 1'b0)
            $fatal(1, "reset did not produce empty/no-write state");
        $display("TRACE CAPU-STORE S0 reset buffer=0 memory_write=0");

        // 1. Gate rejection cannot even enter speculative storage.
        step(1'b1, 1'b0, 1'b1, 16'h0010, 32'hAAAA_0010, 1'b1, 1'b1, 1'b0);
        if (buffer_valid !== 1'b0)
            $fatal(1, "gate-rejected STORE entered speculative buffer");
        expect_no_write("gate rejection");
        $display("TRACE CAPU-STORE S1 gate_rejected buffer=0 memory_write=0");

        // 2. A valid issue creates only speculative state.
        step(1'b1, 1'b1, 1'b1, 16'h0020, 32'hBBBB_0020, 1'b0, 1'b0, 1'b0);
        if (buffer_valid !== 1'b1 || buffered_addr !== 16'h0020 || buffered_data !== 32'hBBBB_0020)
            $fatal(1, "valid STORE was not buffered correctly");
        expect_no_write("speculative issue");
        $display("TRACE CAPU-STORE S2 speculative addr=0020 data=BBBB0020 memory_write=0");

        // 3. Commit request without causal validation is not enough.
        step(1'b0, 1'b0, 1'b0, '0, '0, 1'b0, 1'b1, 1'b0);
        if (buffer_valid !== 1'b1)
            $fatal(1, "causal-invalid STORE was incorrectly retired/discarded");
        expect_no_write("causal validation absent");
        $display("TRACE CAPU-STORE S3 causal_invalid buffer=1 memory_write=0");

        // 4. Flush dominates even a simultaneous would-be valid commit.
        step(1'b0, 1'b0, 1'b0, '0, '0, 1'b1, 1'b1, 1'b1);
        if (buffer_valid !== 1'b0)
            $fatal(1, "flush did not discard speculative STORE");
        expect_no_write("flush dominates commit");
        $display("TRACE CAPU-STORE S4 flushed buffer=0 memory_write=0");

        // 5. Buffer another STORE, then perform a valid causal commit.
        step(1'b1, 1'b1, 1'b1, 16'h0042, 32'hCAFE_0042, 1'b0, 1'b0, 1'b0);
        if (buffer_valid !== 1'b1)
            $fatal(1, "second valid STORE did not enter buffer");
        expect_no_write("second speculative issue");

        step(1'b0, 1'b0, 1'b0, '0, '0, 1'b1, 1'b1, 1'b0);
        if (memory_write_enable !== 1'b1)
            $fatal(1, "valid causal commit produced no memory write pulse");
        if (memory_write_addr !== 16'h0042 || memory_write_data !== 32'hCAFE_0042)
            $fatal(1, "committed memory payload mismatch");
        if (buffer_valid !== 1'b0)
            $fatal(1, "committed STORE remained speculative");
        $display("TRACE CAPU-STORE S5 committed addr=0042 data=CAFE0042 memory_write=1");

        // 6. The write pulse must be exactly one cycle.
        step(1'b0, 1'b0, 1'b0, '0, '0, 1'b0, 1'b1, 1'b0);
        expect_no_write("one-commit one-write");
        $display("TRACE CAPU-STORE S6 retired buffer=0 memory_write=0");

        // 7. Execute failure cannot enter the speculative buffer.
        step(1'b1, 1'b1, 1'b0, 16'h0055, 32'hBAD0_0055, 1'b1, 1'b1, 1'b0);
        if (buffer_valid !== 1'b0)
            $fatal(1, "execute-failed STORE entered speculative buffer");
        expect_no_write("execute failure");
        $display("TRACE CAPU-STORE S7 execute_failed buffer=0 memory_write=0");

        $display("CAPU_CORE_V01_STORE_PASS");
        $finish;
    end
endmodule
