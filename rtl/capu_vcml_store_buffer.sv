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

    // Compact CML projection carried with the speculative STORE.
    // store_ctag_valid means metadata is present/upstream-accepted; the local
    // validator below independently checks the CTAG's STORE semantics.
    input  logic [15:0]                    store_ctag,
    input  logic                           store_ctag_valid,
    input  logic [TRANSITION_ID_WIDTH-1:0] store_transition_id,
    input  logic [PARENT_REF_WIDTH-1:0]    store_parent_ref,

    // Causal validation belongs to the currently buffered entry.
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

    // Hardware retirement event consumed by the software vCML bridge.
    output logic                           vcml_event_valid,
    output logic [15:0]                    retired_ctag,
    output logic [TRANSITION_ID_WIDTH-1:0] retired_transition_id,
    output logic [PARENT_REF_WIDTH-1:0]    retired_parent_ref,

    // v0.3 local CTAG semantic decision for the current issue candidate.
    output logic                           ctag_semantic_accept,
    output logic                           issue_rejected
);

    logic base_issue_rejected;
    logic metadata_issue_allowed;
    logic retire_allowed;

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

    assign metadata_issue_allowed = issue_valid
                                 && gate_allow
                                 && execute_ok
                                 && ctag_semantic_accept
                                 && !buffer_valid;

    // Missing metadata or locally invalid CTAG semantics fail closed before
    // speculative admission. LHINT is not authenticated here; SEAL does not
    // invalidate the current STORE and is only continuation-control metadata.
    assign issue_rejected = issue_valid
                         && (!gate_allow
                             || !execute_ok
                             || !ctag_semantic_accept
                             || buffer_valid);

    assign retire_allowed = buffer_valid
                         && causal_valid
                         && buffered_ctag_valid
                         && commit_request
                         && !flush;

    // A vCML bridge event is exactly the memory-visible retirement pulse.
    assign vcml_event_valid = memory_write_enable;

    capu_store_buffer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) store_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .issue_valid(issue_valid && ctag_semantic_accept),
        .gate_allow(gate_allow),
        .execute_ok(execute_ok),
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
        .issue_rejected(base_issue_rejected)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffered_ctag          <= '0;
            buffered_ctag_valid    <= 1'b0;
            buffered_transition_id <= '0;
            buffered_parent_ref    <= '0;
            retired_ctag           <= '0;
            retired_transition_id  <= '0;
            retired_parent_ref     <= '0;
        end else begin
            if (flush) begin
                buffered_ctag          <= '0;
                buffered_ctag_valid    <= 1'b0;
                buffered_transition_id <= '0;
                buffered_parent_ref    <= '0;
            end else if (retire_allowed) begin
                // Capture the exact metadata associated with the STORE that
                // becomes externally visible at this edge.
                retired_ctag          <= buffered_ctag;
                retired_transition_id <= buffered_transition_id;
                retired_parent_ref    <= buffered_parent_ref;

                buffered_ctag          <= '0;
                buffered_ctag_valid    <= 1'b0;
                buffered_transition_id <= '0;
                buffered_parent_ref    <= '0;
            end else if (metadata_issue_allowed) begin
                buffered_ctag          <= store_ctag;
                buffered_ctag_valid    <= 1'b1;
                buffered_transition_id <= store_transition_id;
                buffered_parent_ref    <= store_parent_ref;
            end
        end
    end

`ifdef CAPU_ASSERTIONS
    property p_memory_write_requires_ctagged_causal_commit;
        @(posedge clk) disable iff (!rst_n)
            memory_write_enable |-> $past(
                buffer_valid
                && causal_valid
                && buffered_ctag_valid
                && commit_request
                && !flush
            );
    endproperty
    assert property (p_memory_write_requires_ctagged_causal_commit);

    property p_vcml_event_matches_memory_visibility;
        @(posedge clk) disable iff (!rst_n)
            vcml_event_valid == memory_write_enable;
    endproperty
    assert property (p_vcml_event_matches_memory_visibility);
`endif

endmodule
