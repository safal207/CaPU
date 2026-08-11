module capu_store_buffer #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Candidate STORE enters the speculative domain only when gate and
    // execution checks already permit it to be buffered.
    input  logic                  issue_valid,
    input  logic                  gate_allow,
    input  logic                  execute_ok,
    input  logic [ADDR_WIDTH-1:0] store_addr,
    input  logic [DATA_WIDTH-1:0] store_data,

    // Causal validation and commit are deliberately separated from issue.
    // With one buffered entry there is no ambiguity about which transition
    // causal_valid refers to.
    input  logic                  causal_valid,
    input  logic                  commit_request,

    // flush models interruption / squash / recovery before commit.
    // It dominates commit: a flushed speculative STORE must never escape.
    input  logic                  flush,

    output logic                  buffer_valid,
    output logic [ADDR_WIDTH-1:0] buffered_addr,
    output logic [DATA_WIDTH-1:0] buffered_data,

    // This is the only externally visible memory-side-effect path in v0.1.
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

    // Externally visible memory mutation has exactly one path.
    assign memory_write_enable = commit_allowed;
    assign memory_write_addr   = buffered_addr;
    assign memory_write_data   = buffered_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_valid  <= 1'b0;
            buffered_addr <= '0;
            buffered_data <= '0;
        end else if (flush) begin
            // Recovery/squash dominates commit and discards speculative state.
            buffer_valid  <= 1'b0;
            buffered_addr <= '0;
            buffered_data <= '0;
        end else if (commit_allowed) begin
            // The memory write is visible combinationally for this commit
            // decision; the speculative entry retires on the clock edge.
            buffer_valid  <= 1'b0;
            buffered_addr <= '0;
            buffered_data <= '0;
        end else if (issue_allowed && !buffer_valid) begin
            buffer_valid  <= 1'b1;
            buffered_addr <= store_addr;
            buffered_data <= store_data;
        end
    end

`ifdef CAPU_ASSERTIONS
    // INV-CAPU-STORE-001 — memory-visible write implies valid causal commit.
    property p_memory_write_requires_causal_commit;
        @(posedge clk) disable iff (!rst_n)
            memory_write_enable |-> (buffer_valid && causal_valid && commit_request && !flush);
    endproperty
    assert property (p_memory_write_requires_causal_commit);

    // INV-CAPU-STORE-002 — flush dominates all externally visible writes.
    property p_flush_blocks_memory_write;
        @(posedge clk) disable iff (!rst_n)
            flush |-> !memory_write_enable;
    endproperty
    assert property (p_flush_blocks_memory_write);

    // INV-CAPU-STORE-003 — no buffered transition means no memory write.
    property p_empty_buffer_cannot_write;
        @(posedge clk) disable iff (!rst_n)
            !buffer_valid |-> !memory_write_enable;
    endproperty
    assert property (p_empty_buffer_cannot_write);
`endif

endmodule
