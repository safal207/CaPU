module capu_vcml_store_buffer_formal;
    localparam int ADDR_WIDTH = 4;
    localparam int DATA_WIDTH = 8;
    localparam int TRANSITION_ID_WIDTH = 8;
    localparam int PARENT_REF_WIDTH = 8;

    // The formal global clock is the processor clock for this harness.
    // This avoids a derived multiclock state space while preserving the ghost
    // witness discipline used by the verified v0.1 STORE proof.
    (* gclk *) reg clk;

    // First formal CPU edge is reset; all following edges exercise the DUT.
    reg rst_n = 1'b0;
    always @(posedge clk)
        rst_n <= 1'b1;

    // Arbitrary bounded environment sampled at each processor edge.
    (* anyseq *) reg                           issue_valid;
    (* anyseq *) reg                           gate_allow;
    (* anyseq *) reg                           execute_ok;
    (* anyseq *) reg [ADDR_WIDTH-1:0]          store_addr;
    (* anyseq *) reg [DATA_WIDTH-1:0]          store_data;
    (* anyseq *) reg [15:0]                    store_ctag;
    (* anyseq *) reg                           store_ctag_valid;
    (* anyseq *) reg [TRANSITION_ID_WIDTH-1:0] store_transition_id;
    (* anyseq *) reg [PARENT_REF_WIDTH-1:0]    store_parent_ref;
    (* anyseq *) reg                           causal_valid;
    (* anyseq *) reg                           commit_request;
    (* anyseq *) reg                           flush;

    wire                           buffer_valid;
    wire [ADDR_WIDTH-1:0]          buffered_addr;
    wire [DATA_WIDTH-1:0]          buffered_data;
    wire [15:0]                    buffered_ctag;
    wire                           buffered_ctag_valid;
    wire [TRANSITION_ID_WIDTH-1:0] buffered_transition_id;
    wire [PARENT_REF_WIDTH-1:0]    buffered_parent_ref;
    wire                           memory_write_enable;
    wire [ADDR_WIDTH-1:0]          memory_write_addr;
    wire [DATA_WIDTH-1:0]          memory_write_data;
    wire                           vcml_event_valid;
    wire [15:0]                    retired_ctag;
    wire [TRANSITION_ID_WIDTH-1:0] retired_transition_id;
    wire [PARENT_REF_WIDTH-1:0]    retired_parent_ref;
    wire                           issue_rejected;

    capu_vcml_store_buffer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TRANSITION_ID_WIDTH(TRANSITION_ID_WIDTH),
        .PARENT_REF_WIDTH(PARENT_REF_WIDTH)
    ) dut (
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
        .issue_rejected(issue_rejected)
    );

    // Ghost witness for the exact STORE + causal metadata authorized at the
    // prior processor edge. It is independent of $past/multiclock semantics.
    reg                           ghost_commit = 1'b0;
    reg [ADDR_WIDTH-1:0]          ghost_addr = '0;
    reg [DATA_WIDTH-1:0]          ghost_data = '0;
    reg [15:0]                    ghost_ctag = '0;
    reg                           ghost_ctag_valid = 1'b0;
    reg [TRANSITION_ID_WIDTH-1:0] ghost_transition_id = '0;
    reg [PARENT_REF_WIDTH-1:0]    ghost_parent_ref = '0;

    always @(posedge clk) begin
        if (!rst_n) begin
            ghost_commit        <= 1'b0;
            ghost_addr          <= '0;
            ghost_data          <= '0;
            ghost_ctag          <= '0;
            ghost_ctag_valid    <= 1'b0;
            ghost_transition_id <= '0;
            ghost_parent_ref    <= '0;
        end else begin
            // FORMAL-CML-001: a visible write exists iff the previous sampled
            // state authorized a causal commit over accepted CTAG metadata.
            assert(memory_write_enable == ghost_commit);

            // FORMAL-CML-002: hardware vCML event and memory visibility are one
            // retirement boundary.
            assert(vcml_event_valid == memory_write_enable);

            // FORMAL-CML-003/004: the visible side effect and causal event carry
            // the exact payload and metadata of the committed speculative entry.
            if (memory_write_enable) begin
                assert(ghost_ctag_valid);
                assert(memory_write_addr == ghost_addr);
                assert(memory_write_data == ghost_data);
                assert(retired_ctag == ghost_ctag);
                assert(retired_transition_id == ghost_transition_id);
                assert(retired_parent_ref == ghost_parent_ref);
                assert(!buffer_valid);
            end

            // FORMAL-CML-COVER-001: prove the authorization path is not vacuous.
            // A valid CTAG-bearing causal commit must be reachable and produce
            // both the external STORE pulse and the paired hardware vCML event.
            cover(memory_write_enable && vcml_event_valid && ghost_ctag_valid);

            // Capture current authorization for observation at the next edge.
            // Flush is included explicitly, so recovery/squash dominates commit.
            ghost_commit <= buffer_valid
                         && causal_valid
                         && buffered_ctag_valid
                         && commit_request
                         && !flush;
            ghost_addr          <= buffered_addr;
            ghost_data          <= buffered_data;
            ghost_ctag          <= buffered_ctag;
            ghost_ctag_valid    <= buffered_ctag_valid;
            ghost_transition_id <= buffered_transition_id;
            ghost_parent_ref    <= buffered_parent_ref;
        end
    end
endmodule
