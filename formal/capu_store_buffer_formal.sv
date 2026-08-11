module capu_store_buffer_formal;
    localparam int ADDR_WIDTH = 4;
    localparam int DATA_WIDTH = 8;

    // SBY global formal timestep used directly as the DUT clock.
    (* gclk *) reg clk;

    // Hold reset low for the first clock edge, then release it permanently.
    reg rst_n = 1'b0;
    reg past_valid = 1'b0;

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

    always @(posedge clk) begin
        past_valid <= 1'b1;
        rst_n <= 1'b1;

        if (past_valid && rst_n) begin
            // FORMAL-INV-001: every visible memory write must be the retirement
            // of a previously buffered entry with causal validation, explicit
            // commit, and no flush.
            if (memory_write_enable) begin
                assert($past(buffer_valid));
                assert($past(causal_valid));
                assert($past(commit_request));
                assert(!$past(flush));
                assert(memory_write_addr == $past(buffered_addr));
                assert(memory_write_data == $past(buffered_data));
            end

            // FORMAL-INV-002: a flush at the retirement edge cannot create a
            // visible memory write in the following architectural cycle.
            if ($past(flush))
                assert(!memory_write_enable);

            // FORMAL-INV-003: an empty speculative buffer cannot retire a STORE.
            if (!$past(buffer_valid))
                assert(!memory_write_enable);

            // FORMAL-INV-004: causal validation is necessary for visibility.
            if ($past(buffer_valid) && $past(commit_request) && !$past(causal_valid))
                assert(!memory_write_enable);

            // FORMAL-INV-005: one buffered commit cannot create consecutive
            // write pulses. A new STORE must be issued and buffered first.
            if ($past(memory_write_enable))
                assert(!memory_write_enable);
        end
    end
endmodule
