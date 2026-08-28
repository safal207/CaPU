module capu_store_buffer_formal;
    localparam int ADDR_WIDTH = 4;
    localparam int DATA_WIDTH = 8;

    // Formal time and processor time are intentionally distinct.
    // SBY advances gclk every formal timestep; clk toggles deterministically,
    // so every second formal timestep is one architectural posedge.
    (* gclk *) reg gclk;
    reg clk = 1'b0;

    // Deterministic reset: the first CPU posedge occurs while reset is low.
    // Reset is released on the following global half-cycle.
    reg rst_n = 1'b0;
    reg [1:0] reset_phase = 2'd0;

    always @(posedge gclk) begin
        clk <= !clk;

        if (reset_phase != 2'd3)
            reset_phase <= reset_phase + 1'b1;

        if (reset_phase >= 2'd1)
            rst_n <= 1'b1;
    end

    // Arbitrary environment. These values may vary each formal timestep; the
    // DUT samples them only on processor clock edges.
    (* anyseq *) reg                  issue_valid;
    (* anyseq *) reg                  gate_allow;
    (* anyseq *) reg                  execute_ok;
    (* anyseq *) reg [ADDR_WIDTH-1:0] store_addr;
    (* anyseq *) reg [DATA_WIDTH-1:0] store_data;
    (* anyseq *) reg                  causal_valid;
    (* anyseq *) reg                  commit_request;
    (* anyseq *) reg                  flush;

    wire                  buffer_valid;
    wire [ADDR_WIDTH-1:0] buffered_addr;
    wire [DATA_WIDTH-1:0] buffered_data;
    wire                  memory_write_enable;
    wire [ADDR_WIDTH-1:0] memory_write_addr;
    wire [DATA_WIDTH-1:0] memory_write_data;
    wire                  issue_rejected;

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

    // Ghost state records the exact retirement decision sampled at the prior
    // processor posedge. Because DUT and ghost registers update together with
    // nonblocking semantics, the observed memory_write_* values at a posedge
    // must equal this witness from the preceding posedge.
    reg                  ghost_commit = 1'b0;
    reg [ADDR_WIDTH-1:0] ghost_addr = '0;
    reg [DATA_WIDTH-1:0] ghost_data = '0;

    always @(posedge clk) begin
        if (!rst_n) begin
            ghost_commit <= 1'b0;
            ghost_addr   <= '0;
            ghost_data   <= '0;
        end else begin
            // FORMAL-INV-001: visibility is exactly the prior authorized
            // causal retirement decision. No authorization -> no write.
            assert(memory_write_enable == ghost_commit);

            // FORMAL-INV-002: a visible write carries the exact buffered
            // payload that was authorized for retirement.
            if (memory_write_enable) begin
                assert(memory_write_addr == ghost_addr);
                assert(memory_write_data == ghost_data);
            end

            // FORMAL-INV-003: a retired entry was removed from speculation;
            // therefore a write pulse cannot simultaneously be backed by the
            // same still-valid buffered entry.
            if (memory_write_enable)
                assert(!buffer_valid);

            // Capture the current decision for verification at the next CPU
            // posedge. Flush is inside the witness, so it dominates commit.
            ghost_commit <= buffer_valid
                         && causal_valid
                         && commit_request
                         && !flush;
            ghost_addr <= buffered_addr;
            ghost_data <= buffered_data;
        end
    end
endmodule
