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
    input  logic                           root_authorized,

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
    output logic                           buffered_root_authorized,

    output logic                           memory_write_enable,
    output logic [ADDR_WIDTH-1:0]          memory_write_addr,
    output logic [DATA_WIDTH-1:0]          memory_write_data,

    output logic                           vcml_event_valid,
    output logic [15:0]                    retired_ctag,
    output logic [TRANSITION_ID_WIDTH-1:0] retired_transition_id,
    output logic [PARENT_REF_WIDTH-1:0]    retired_parent_ref,
    output logic                           retired_root_authorized,

    output logic                           ctag_semantic_accept,
    output logic                           sealed_chain,
    output logic                           continuation_blocked,
    output logic                           causal_head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] causal_head_transition_id,
    output logic [3:0]                     causal_head_gen,
    output logic                           generation_policy_accept,
    output logic                           generation_exhausted,
    output logic                           root_authorization_accept,
    output logic                           parent_policy_accept,
    output logic                           issue_rejected
);

    logic metadata_issue_allowed;
    logic retire_allowed;
    logic automatic_continuation_allowed;
    logic buffered_explicit_new_cause;
    logic root_policy_accept;
    logic continuation_parent_accept;
    logic continuation_generation_accept;

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

    // Exact parent comparison is fail-closed; no implicit truncation/extension.
    initial begin
        if (TRANSITION_ID_WIDTH != PARENT_REF_WIDTH)
            $error("CaPU v0.7 requires TRANSITION_ID_WIDTH == PARENT_REF_WIDTH");
    end

    // v0.7 adds an explicit upstream trust boundary for fresh roots. This
    // signal is intentionally not called cryptographic authentication: it is a
    // trusted authorization decision supplied to the hardware admission path.
    assign root_authorization_accept = explicit_new_cause && root_authorized;

    // Fresh roots still use the v0.6 structural convention parent=0, GEN=0,
    // but that structure is no longer sufficient without root authorization.
    assign root_policy_accept = root_authorization_accept
                             && (store_parent_ref == '0)
                             && (decoded_gen == 4'h0);

    assign generation_exhausted = causal_head_valid
                                && (causal_head_gen == 4'hF);

    assign continuation_parent_accept = !explicit_new_cause
                                      && causal_head_valid
                                      && (store_parent_ref == causal_head_transition_id);

    // Automatic continuation must advance exactly one generation and never
    // wrap F -> 0. GEN exhaustion requires a new authorized explicit root.
    assign continuation_generation_accept = !explicit_new_cause
                                          && causal_head_valid
                                          && !generation_exhausted
                                          && (decoded_gen == (causal_head_gen + 4'h1));

    assign generation_policy_accept = explicit_new_cause
                                    ? (decoded_gen == 4'h0)
                                    : continuation_generation_accept;

    assign continuation_blocked = !explicit_new_cause
                               && (sealed_chain || generation_exhausted);

    assign parent_policy_accept = explicit_new_cause
                                ? root_policy_accept
                                : (automatic_continuation_allowed
                                   && continuation_parent_accept
                                   && continuation_generation_accept);

    assign metadata_issue_allowed = issue_valid
                                 && gate_allow
                                 && execute_ok
                                 && ctag_semantic_accept
                                 && parent_policy_accept
                                 && !buffer_valid;

    assign issue_rejected = issue_valid
                         && (!gate_allow
                             || !execute_ok
                             || !ctag_semantic_accept
                             || !parent_policy_accept
                             || buffer_valid);

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

    capu_causal_head_controller #(
        .TRANSITION_ID_WIDTH(TRANSITION_ID_WIDTH)
    ) causal_head_controller (
        .clk(clk),
        .rst_n(rst_n),
        .committed_event(retire_allowed),
        .committed_transition_id(buffered_transition_id),
        .committed_gen(buffered_ctag[7:4]),
        .head_valid(causal_head_valid),
        .causal_head_transition_id(causal_head_transition_id),
        .causal_head_gen(causal_head_gen)
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
            buffered_root_authorized    <= 1'b0;
            retired_ctag                <= '0;
            retired_transition_id       <= '0;
            retired_parent_ref          <= '0;
            retired_root_authorized     <= 1'b0;
        end else begin
            if (flush) begin
                buffered_ctag               <= '0;
                buffered_ctag_valid         <= 1'b0;
                buffered_transition_id      <= '0;
                buffered_parent_ref         <= '0;
                buffered_explicit_new_cause <= 1'b0;
                buffered_root_authorized    <= 1'b0;
            end else if (retire_allowed) begin
                retired_ctag            <= buffered_ctag;
                retired_transition_id   <= buffered_transition_id;
                retired_parent_ref      <= buffered_parent_ref;
                retired_root_authorized <= buffered_root_authorized;

                buffered_ctag               <= '0;
                buffered_ctag_valid         <= 1'b0;
                buffered_transition_id      <= '0;
                buffered_parent_ref         <= '0;
                buffered_explicit_new_cause <= 1'b0;
                buffered_root_authorized    <= 1'b0;
            end else if (metadata_issue_allowed) begin
                buffered_ctag               <= store_ctag;
                buffered_ctag_valid         <= 1'b1;
                buffered_transition_id      <= store_transition_id;
                buffered_parent_ref         <= store_parent_ref;
                buffered_explicit_new_cause <= explicit_new_cause;
                // Continuations never acquire root authorization evidence even
                // if the sideband is spuriously high; the bit is root-qualified.
                buffered_root_authorized    <= explicit_new_cause && root_authorized;
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

    property p_continuation_requires_exact_parent_and_next_gen;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && !explicit_new_cause && !issue_rejected)
            |-> (causal_head_valid
                 && !sealed_chain
                 && !generation_exhausted
                 && store_parent_ref == causal_head_transition_id
                 && decoded_gen == (causal_head_gen + 4'h1));
    endproperty
    assert property (p_continuation_requires_exact_parent_and_next_gen);

    property p_explicit_root_requires_authorization_zero_parent_and_zero_gen;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && explicit_new_cause && !issue_rejected)
            |-> (root_authorized && store_parent_ref == '0 && decoded_gen == 4'h0);
    endproperty
    assert property (p_explicit_root_requires_authorization_zero_parent_and_zero_gen);

    property p_unauthorized_root_rejected;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && explicit_new_cause && !root_authorized) |-> issue_rejected;
    endproperty
    assert property (p_unauthorized_root_rejected);

    property p_generation_exhaustion_blocks_automatic_issue;
        @(posedge clk) disable iff (!rst_n)
            (generation_exhausted && issue_valid && !explicit_new_cause)
            |-> issue_rejected;
    endproperty
    assert property (p_generation_exhaustion_blocks_automatic_issue);

    // A visible GEN=0 / parent=0 root retirement must carry the root
    // authorization fact that was latched at admission. The bit is meaningful
    // only when qualified by the retirement event.
    property p_visible_root_retains_authorization;
        @(posedge clk) disable iff (!rst_n)
            (vcml_event_valid && retired_parent_ref == '0 && retired_ctag[7:4] == 4'h0)
            |-> retired_root_authorized;
    endproperty
    assert property (p_visible_root_retains_authorization);
`endif

endmodule
