module capu_store_buffer #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  issue_valid,
    input  logic                  gate_allow,
    input  logic                  execute_ok,
    input  logic [ADDR_WIDTH-1:0] store_addr,
    input  logic [DATA_WIDTH-1:0] store_data,

    // Validation belongs to the currently buffered single entry.
    input  logic                  causal_valid,
    input  logic                  commit_request,

    // Interruption / squash before retirement. Flush dominates commit.
    input  logic                  flush,

    output logic                  buffer_valid,
    output logic [ADDR_WIDTH-1:0] buffered_addr,
    output logic [DATA_WIDTH-1:0] buffered_data,

    // The only externally visible memory-side-effect path in v0.1.
    // It is a one-cycle registered retirement pulse carrying stable payload.
    output logic                  memory_write_enable,
    output logic [ADDR_WIDTH-1:0] memory_write_addr,
    output logic [DATA_WIDTH-1:0] memory_write_data,

    output logic                  issue_rejected
);

    logic issue_allowed;
    logic commit_allowed;

    assign issue_allowed = issue_valid && gate_allow && execute_ok;

    assign commit_allowed = buffer_valid
                         && causal_valid
                         && commit_request
                         && !flush;

    assign issue_rejected = issue_valid && (!gate_allow || !execute_ok || buffer_valid);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_valid        <= 1'b0;
            buffered_addr       <= '0;
            buffered_data       <= '0;
            memory_write_enable <= 1'b0;
            memory_write_addr   <= '0;
            memory_write_data   <= '0;
        end else begin
            // Memory visibility is a retirement pulse, never a level inherited
            // from speculative state.
            memory_write_enable <= 1'b0;

            if (flush) begin
                // Recovery/squash dominates commit and discards speculation.
                buffer_valid  <= 1'b0;
                buffered_addr <= '0;
                buffered_data <= '0;
            end else if (commit_allowed) begin
                // Exactly here speculative state becomes externally visible.
                memory_write_enable <= 1'b1;
                memory_write_addr   <= buffered_addr;
                memory_write_data   <= buffered_data;

                buffer_valid  <= 1'b0;
                buffered_addr <= '0;
                buffered_data <= '0;
            end else if (issue_allowed && !buffer_valid) begin
                // Issue only creates speculative state. It cannot write memory.
                buffer_valid  <= 1'b1;
                buffered_addr <= store_addr;
                buffered_data <= store_data;
            end
        end
    end

`ifdef CAPU_ASSERTIONS
    // These properties describe the retirement boundary. A formal harness can
    // enable CAPU_ASSERTIONS with a tool that supports concurrent SVA.

    // INV-CAPU-STORE-001 — a visible memory write must correspond to a valid
    // causal commit decision in the immediately preceding sampling edge.
    property p_memory_write_requires_causal_commit;
        @(posedge clk) disable iff (!rst_n)
            memory_write_enable |-> $past(buffer_valid && causal_valid && commit_request && !flush);
    endproperty
    assert property (p_memory_write_requires_causal_commit);

    // INV-CAPU-STORE-002 — flush never creates a memory write pulse.
    property p_flush_blocks_memory_write;
        @(posedge clk) disable iff (!rst_n)
            flush |=> !memory_write_enable;
    endproperty
    assert property (p_flush_blocks_memory_write);
`endif

endmodule
