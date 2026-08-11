module capu_vcml_store_buffer #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int TRANSITION_ID_WIDTH = 64,
    parameter int PARENT_REF_WIDTH = 64,
    parameter bit REQUIRE_WRITE_CLASS = 1'b1
) (
    input  logic                           clk,
    input  logic                           rst_n,

    input  logic                           issue_valid,
    input  logic                           gate_allow,
    input  logic                           execute_ok,
    input  logic [ADDR_WIDTH-1:0]          store_addr,
    input  logic [DATA_WIDTH-1:0]          store_data,

    input  logic [15:0]                    store_ctag,
    input  logic                           store_ctag_valid,
    input  logic [TRANSITION_ID_WIDTH-1:0] store_transition_id,
    input  logic [PARENT_REF_WIDTH-1:0]    store_parent_ref,
    input  logic                           explicit_new_cause,

    input  logic                           causal_valid,
    input  logic                           commit_request,
    input  logic                           flush,

    output logic                           buffer_valid,
    output logic [ADDR_WIDTH-1:0]          buffered_addr,
    output logic [DATA_WIDTH-1:0]          buffered_data,
    output logic [15:0]                    buffered_ctag,
    output logic                           buffered_ctag_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] buffered_transition_id,
    output logic [PARENT_REF_WIDTH-1:0]    buffered_parent_ref,

    output logic                           memory_write_enable,
    output logic [ADDR_WIDTH-1:0]          memory_write_addr,
    output logic [DATA_WIDTH-1:0]          memory_write_data,

    output logic                           vcml_event_valid,
    output logic [15:0]                    retired_ctag,
    output logic [TRANSITION_ID_WIDTH-1:0] retired_transition_id,
    output logic [PARENT_REF_WIDTH-1:0]    retired_parent_ref,

    output logic                           ctag_semantic_accept,
    output logic                           sealed_chain,
    output logic                           continuation_blocked,
    output logic                           issue_rejected
);

    logic metadata_issue_allowed;
    logic retire_allowed;
    logic automatic_continuation_allowed;
    logic buffered_explicit_new_cause;

    logic [3:0] decoded_dom;
    logic [3:0] decoded_class;
    logic [3:0] decoded_gen;
    logic [2:0] decoded_lhint;
    logic       decoded_seal;

    capu_ctag_validator #(
        .REQUIRE_WRITE_CLASS(REQUIRE_WRITE_CLASS)
    ) ctag_validator (
        .ctag(store_ctag),
        .metadata_valid(store_ctag_valid),
        .ctag_accept(ctag_semantic_accept),
        .ctag_dom(decoded_dom),
        .ctag_class(decoded_class),
        .ctag_gen(decoded_gen),
        .ctag_lhint(decoded_lhint),
        .ctag_seal(decoded_seal)
    );

    assign continuation_blocked = sealed_chain && !explicit_new_cause;

    assign metadata_issue_allowed = issue_valid
                                 && gate_allow
                                 && execute_ok
                                 && ctag_semantic_accept
                                 && !buffer_valid
                                 && (automatic_continuation_allowed || explicit_new_cause);

    assign issue_rejected = issue_valid
                         && (!gate_allow
                             || !execute_ok
                             || !ctag_semantic_accept
                             || buffer_valid
                             || continuation_blocked);

    assign retire_allowed = buffer_valid
                         && causal_valid
                         && buffered_ctag_valid
                         && commit_request
                         && !flush;

    assign vcml_event_valid = memory_write_enable;

    capu_seal_controller seal_controller (
        .clk(clk),
        .rst_n(rst_n),
        .committed_event(retire_allowed),
        .committed_seal(buffered_ctag[0]),
        .committed_explicit_new_cause(buffered_explicit_new_cause),
        .sealed_chain(sealed_chain),
        .automatic_continuation_allowed(automatic_continuation_allowed)
    );

    capu_store_buffer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) store_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .issue_valid(metadata_issue_allowed),
        .gate_allow(1'b1),
        .execute_ok(1'b1),
        .store_addr(store_addr),
        .store_data(store_data),
        .causal_valid(causal_valid && buffered_ctag_valid),
        .commit_request(commit_request),
        .flush(flush),
        .buffer_valid(buffer_valid),
        .buffered_addr(buffered_addr),
        .buffered_data(buffered_data),
        .memory_write_enable(memory_write_enable),
        .memory_write_addr(memory_write_addr),
        .memory_write_data(memory_write_data),
        .issue_rejected()
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffered_ctag               <= '0;
            buffered_ctag_valid         <= 1'b0;
            buffered_transition_id      <= '0;
            buffered_parent_ref         <= '0;
            buffered_explicit_new_cause <= 1'b0;
            retired_ctag                <= '0;
            retired_transition_id       <= '0;
            retired_parent_ref          <= '0;
        end else begin
            if (flush) begin
                buffered_ctag               <= '0;
                buffered_ctag_valid         <= 1'b0;
                buffered_transition_id      <= '0;
                buffered_parent_ref         <= '0;
                buffered_explicit_new_cause <= 1'b0;
            end else if (retire_allowed) begin
                retired_ctag          <= buffered_ctag;
                retired_transition_id <= buffered_transition_id;
                retired_parent_ref    <= buffered_parent_ref;

                buffered_ctag               <= '0;
                buffered_ctag_valid         <= 1'b0;
                buffered_transition_id      <= '0;
                buffered_parent_ref         <= '0;
                buffered_explicit_new_cause <= 1'b0;
            end else if (metadata_issue_allowed) begin
                buffered_ctag               <= store_ctag;
                buffered_ctag_valid         <= 1'b1;
                buffered_transition_id      <= store_transition_id;
                buffered_parent_ref         <= store_parent_ref;
                buffered_explicit_new_cause <= explicit_new_cause;
            end
        end
    end

`ifdef CAPU_ASSERTIONS
    property p_vcml_event_matches_memory_visibility;
        @(posedge clk) disable iff (!rst_n)
            vcml_event_valid == memory_write_enable;
    endproperty
    assert property (p_vcml_event_matches_memory_visibility);

    property p_sealed_chain_blocks_automatic_issue;
        @(posedge clk) disable iff (!rst_n)
            (sealed_chain && issue_valid && !explicit_new_cause) |-> issue_rejected;
    endproperty
    assert property (p_sealed_chain_blocks_automatic_issue);
`endif

endmodule
