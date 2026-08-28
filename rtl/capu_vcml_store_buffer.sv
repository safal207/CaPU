module capu_vcml_store_buffer #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int TRANSITION_ID_WIDTH = 64,
    parameter int PARENT_REF_WIDTH = 64,
    parameter int AUTHORIZATION_REF_WIDTH = 16,
    parameter int POLICY_EPOCH_WIDTH = 8,
    parameter int SPENT_AUTHORIZATION_SLOTS = 4,
    parameter bit REQUIRE_WRITE_CLASS = 1'b1,
    parameter bit ENABLE_CAUSAL_STATE_RESTORE = 1'b0
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
    input  logic [AUTHORIZATION_REF_WIDTH-1:0] root_authorization_ref,
    input  logic [POLICY_EPOCH_WIDTH-1:0]      root_policy_epoch,

    input  logic                           causal_valid,
    input  logic                           commit_request,
    input  logic                           flush,

    // v0.15 optional recovery sideband. With the default parameter disabled,
    // all earlier v0.9-v0.14 instances retain their original semantics.
    input  logic                           causal_state_restore_valid,
    input  logic                           restore_causal_head_valid,
    input  logic [TRANSITION_ID_WIDTH-1:0] restore_causal_head_transition_id,
    input  logic [3:0]                     restore_causal_head_gen,
    input  logic                           restore_sealed_chain,

    output logic                           buffer_valid,
    output logic [ADDR_WIDTH-1:0]          buffered_addr,
    output logic [DATA_WIDTH-1:0]          buffered_data,
    output logic [15:0]                    buffered_ctag,
    output logic                           buffered_ctag_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] buffered_transition_id,
    output logic [PARENT_REF_WIDTH-1:0]    buffered_parent_ref,
    output logic                           buffered_root_authorized,
    output logic [AUTHORIZATION_REF_WIDTH-1:0] buffered_root_authorization_ref,
    output logic [POLICY_EPOCH_WIDTH-1:0]      buffered_root_policy_epoch,

    output logic                           memory_write_enable,
    output logic [ADDR_WIDTH-1:0]          memory_write_addr,
    output logic [DATA_WIDTH-1:0]          memory_write_data,

    output logic                           vcml_event_valid,
    output logic [15:0]                    retired_ctag,
    output logic [TRANSITION_ID_WIDTH-1:0] retired_transition_id,
    output logic [PARENT_REF_WIDTH-1:0]    retired_parent_ref,
    output logic                           retired_root_authorized,
    output logic [AUTHORIZATION_REF_WIDTH-1:0] retired_root_authorization_ref,
    output logic [POLICY_EPOCH_WIDTH-1:0]      retired_root_policy_epoch,

    output logic                           ctag_semantic_accept,
    output logic                           sealed_chain,
    output logic                           continuation_blocked,
    output logic                           causal_head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] causal_head_transition_id,
    output logic [3:0]                     causal_head_gen,
    output logic                           generation_policy_accept,
    output logic                           generation_exhausted,
    output logic                           root_authorization_accept,
    output logic                           authorization_ref_fresh,
    output logic                           authorization_replay_detected,
    output logic                           authorization_capacity_exhausted,
    output logic [$clog2(SPENT_AUTHORIZATION_SLOTS+1)-1:0] spent_authorization_count,
    output logic                           retired_authorization_ref_spent,
    output logic                           parent_policy_accept,
    output logic                           issue_rejected
);

    localparam int SPENT_SLOT_INDEX_WIDTH =
        (SPENT_AUTHORIZATION_SLOTS <= 1) ? 1 : $clog2(SPENT_AUTHORIZATION_SLOTS);

    logic metadata_issue_allowed;
    logic retire_allowed;
    logic automatic_continuation_allowed;
    logic buffered_explicit_new_cause;
    logic root_policy_accept;
    logic continuation_parent_accept;
    logic continuation_generation_accept;
    logic authorization_ref_present;
    logic authorization_ref_seen;
    logic retired_authorization_ref_seen;
    logic first_free_spent_slot_valid;
    logic [SPENT_SLOT_INDEX_WIDTH-1:0] first_free_spent_slot;
    logic consume_root_authorization;
    logic causal_state_restore_active;

    logic [AUTHORIZATION_REF_WIDTH-1:0]
        spent_authorization_refs [0:SPENT_AUTHORIZATION_SLOTS-1];
    logic [SPENT_AUTHORIZATION_SLOTS-1:0] spent_authorization_valid;

    logic [3:0] decoded_dom;
    logic [3:0] decoded_class;
    logic [3:0] decoded_gen;
    logic [2:0] decoded_lhint;
    logic       decoded_seal;

    integer scan_idx;
    integer reset_idx;

    assign causal_state_restore_active = ENABLE_CAUSAL_STATE_RESTORE
                                      && (causal_state_restore_valid === 1'b1);

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

    initial begin
        if (TRANSITION_ID_WIDTH != PARENT_REF_WIDTH)
            $error("CaPU v0.9 requires TRANSITION_ID_WIDTH == PARENT_REF_WIDTH");
        if (AUTHORIZATION_REF_WIDTH < 1)
            $error("CaPU v0.9 requires AUTHORIZATION_REF_WIDTH >= 1");
        if (POLICY_EPOCH_WIDTH < 1)
            $error("CaPU v0.9 requires POLICY_EPOCH_WIDTH >= 1");
        if (SPENT_AUTHORIZATION_SLOTS < 1)
            $error("CaPU v0.9 requires SPENT_AUTHORIZATION_SLOTS >= 1");
    end

    // v0.9 bounded one-shot authorization set.
    // A root authorization reference is consumed only by successful root
    // retirement. There is no eviction: when the local volatile table is full,
    // fresh roots fail closed until reset. policy_epoch remains opaque and is
    // not part of the replay identity in this version.
    always_comb begin
        authorization_ref_seen = 1'b0;
        retired_authorization_ref_seen = 1'b0;
        first_free_spent_slot_valid = 1'b0;
        first_free_spent_slot = '0;
        spent_authorization_count = '0;

        for (scan_idx = 0; scan_idx < SPENT_AUTHORIZATION_SLOTS; scan_idx = scan_idx + 1) begin
            if (spent_authorization_valid[scan_idx]) begin
                spent_authorization_count = spent_authorization_count + 1'b1;
                if (spent_authorization_refs[scan_idx] == root_authorization_ref)
                    authorization_ref_seen = 1'b1;
                if (retired_root_authorized
                    && spent_authorization_refs[scan_idx] == retired_root_authorization_ref)
                    retired_authorization_ref_seen = 1'b1;
            end else if (!first_free_spent_slot_valid) begin
                first_free_spent_slot_valid = 1'b1;
                first_free_spent_slot = scan_idx[SPENT_SLOT_INDEX_WIDTH-1:0];
            end
        end
    end

    assign authorization_capacity_exhausted = &spent_authorization_valid;
    assign authorization_ref_fresh = !authorization_ref_seen;
    assign authorization_replay_detected = explicit_new_cause
                                         && root_authorized
                                         && (root_authorization_ref != '0)
                                         && authorization_ref_seen;
    assign retired_authorization_ref_spent = retired_root_authorized
                                           && retired_root_authorization_ref != '0
                                           && retired_authorization_ref_seen;

    assign authorization_ref_present = (root_authorization_ref != '0);
    assign root_authorization_accept = explicit_new_cause
                                     && root_authorized
                                     && authorization_ref_present
                                     && !authorization_ref_seen
                                     && !authorization_capacity_exhausted;

    assign root_policy_accept = root_authorization_accept
                             && (store_parent_ref == '0)
                             && (decoded_gen == 4'h0);

    assign generation_exhausted = causal_head_valid
                                && (causal_head_gen == 4'hF);

    assign continuation_parent_accept = !explicit_new_cause
                                      && causal_head_valid
                                      && (store_parent_ref == causal_head_transition_id);

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
                                 && !buffer_valid
                                 && !causal_state_restore_active;

    assign issue_rejected = issue_valid
                         && (!gate_allow
                             || !execute_ok
                             || !ctag_semantic_accept
                             || !parent_policy_accept
                             || buffer_valid
                             || causal_state_restore_active);

    assign retire_allowed = buffer_valid
                         && causal_valid
                         && buffered_ctag_valid
                         && commit_request
                         && !flush
                         && !causal_state_restore_active;

    assign consume_root_authorization = retire_allowed
                                      && buffered_explicit_new_cause
                                      && buffered_root_authorized
                                      && buffered_root_authorization_ref != '0;

    assign vcml_event_valid = memory_write_enable;

    capu_seal_controller #(
        .ENABLE_RESTORE(ENABLE_CAUSAL_STATE_RESTORE)
    ) seal_controller (
        .clk(clk),
        .rst_n(rst_n),
        .committed_event(retire_allowed),
        .committed_seal(buffered_ctag[0]),
        .committed_explicit_new_cause(buffered_explicit_new_cause),
        .restore_valid(causal_state_restore_active),
        .restore_sealed_chain(restore_sealed_chain),
        .sealed_chain(sealed_chain),
        .automatic_continuation_allowed(automatic_continuation_allowed)
    );

    capu_causal_head_controller #(
        .TRANSITION_ID_WIDTH(TRANSITION_ID_WIDTH),
        .ENABLE_RESTORE(ENABLE_CAUSAL_STATE_RESTORE)
    ) causal_head_controller (
        .clk(clk),
        .rst_n(rst_n),
        .committed_event(retire_allowed),
        .committed_transition_id(buffered_transition_id),
        .committed_gen(buffered_ctag[7:4]),
        .restore_valid(causal_state_restore_active),
        .restore_head_valid(restore_causal_head_valid),
        .restore_transition_id(restore_causal_head_transition_id),
        .restore_gen(restore_causal_head_gen),
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
        .flush(flush || causal_state_restore_active),
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
            spent_authorization_valid         <= '0;
            for (reset_idx = 0; reset_idx < SPENT_AUTHORIZATION_SLOTS; reset_idx = reset_idx + 1)
                spent_authorization_refs[reset_idx] <= '0;

            buffered_ctag                    <= '0;
            buffered_ctag_valid              <= 1'b0;
            buffered_transition_id           <= '0;
            buffered_parent_ref              <= '0;
            buffered_explicit_new_cause      <= 1'b0;
            buffered_root_authorized         <= 1'b0;
            buffered_root_authorization_ref  <= '0;
            buffered_root_policy_epoch       <= '0;
            retired_ctag                     <= '0;
            retired_transition_id            <= '0;
            retired_parent_ref               <= '0;
            retired_root_authorized          <= 1'b0;
            retired_root_authorization_ref   <= '0;
            retired_root_policy_epoch        <= '0;
        end else begin
            if (consume_root_authorization && first_free_spent_slot_valid) begin
                spent_authorization_valid[first_free_spent_slot] <= 1'b1;
                spent_authorization_refs[first_free_spent_slot] <= buffered_root_authorization_ref;
            end

            if (flush || causal_state_restore_active) begin
                buffered_ctag                    <= '0;
                buffered_ctag_valid              <= 1'b0;
                buffered_transition_id           <= '0;
                buffered_parent_ref              <= '0;
                buffered_explicit_new_cause      <= 1'b0;
                buffered_root_authorized         <= 1'b0;
                buffered_root_authorization_ref  <= '0;
                buffered_root_policy_epoch       <= '0;
            end else if (retire_allowed) begin
                retired_ctag                    <= buffered_ctag;
                retired_transition_id           <= buffered_transition_id;
                retired_parent_ref              <= buffered_parent_ref;
                retired_root_authorized         <= buffered_root_authorized;
                retired_root_authorization_ref  <= buffered_root_authorization_ref;
                retired_root_policy_epoch       <= buffered_root_policy_epoch;

                buffered_ctag                    <= '0;
                buffered_ctag_valid              <= 1'b0;
                buffered_transition_id           <= '0;
                buffered_parent_ref              <= '0;
                buffered_explicit_new_cause      <= 1'b0;
                buffered_root_authorized         <= 1'b0;
                buffered_root_authorization_ref  <= '0;
                buffered_root_policy_epoch       <= '0;
            end else if (metadata_issue_allowed) begin
                buffered_ctag               <= store_ctag;
                buffered_ctag_valid         <= 1'b1;
                buffered_transition_id      <= store_transition_id;
                buffered_parent_ref         <= store_parent_ref;
                buffered_explicit_new_cause <= explicit_new_cause;
                if (explicit_new_cause) begin
                    buffered_root_authorized        <= root_authorized;
                    buffered_root_authorization_ref <= root_authorization_ref;
                    buffered_root_policy_epoch      <= root_policy_epoch;
                end else begin
                    buffered_root_authorized        <= 1'b0;
                    buffered_root_authorization_ref <= '0;
                    buffered_root_policy_epoch      <= '0;
                end
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

    property p_explicit_root_requires_fresh_provenance;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && explicit_new_cause && !issue_rejected)
            |-> (root_authorized
                 && root_authorization_ref != '0
                 && authorization_ref_fresh
                 && !authorization_capacity_exhausted
                 && store_parent_ref == '0
                 && decoded_gen == 4'h0);
    endproperty
    assert property (p_explicit_root_requires_fresh_provenance);

    property p_unauthorized_or_unreferenced_root_rejected;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && explicit_new_cause
             && (!root_authorized || root_authorization_ref == '0))
            |-> issue_rejected;
    endproperty
    assert property (p_unauthorized_or_unreferenced_root_rejected);

    property p_replayed_root_rejected;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && explicit_new_cause && authorization_replay_detected)
            |-> issue_rejected;
    endproperty
    assert property (p_replayed_root_rejected);

    property p_full_spent_set_rejects_new_root;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && explicit_new_cause && root_authorized
             && root_authorization_ref != '0 && authorization_capacity_exhausted)
            |-> issue_rejected;
    endproperty
    assert property (p_full_spent_set_rejects_new_root);

    property p_generation_exhaustion_blocks_automatic_issue;
        @(posedge clk) disable iff (!rst_n)
            (generation_exhausted && issue_valid && !explicit_new_cause)
            |-> issue_rejected;
    endproperty
    assert property (p_generation_exhaustion_blocks_automatic_issue);

    property p_visible_root_retains_spent_authorization_provenance;
        @(posedge clk) disable iff (!rst_n)
            (vcml_event_valid && retired_parent_ref == '0 && retired_ctag[7:4] == 4'h0)
            |-> (retired_root_authorized
                 && retired_root_authorization_ref != '0
                 && retired_authorization_ref_spent);
    endproperty
    assert property (p_visible_root_retains_spent_authorization_provenance);

    property p_restore_never_publishes_effect;
        @(posedge clk) disable iff (!rst_n)
            causal_state_restore_active |-> (!memory_write_enable && !vcml_event_valid);
    endproperty
    assert property (p_restore_never_publishes_effect);

    property p_restore_blocks_new_issue;
        @(posedge clk) disable iff (!rst_n)
            (causal_state_restore_active && issue_valid) |-> issue_rejected;
    endproperty
    assert property (p_restore_blocks_new_issue);
`endif

endmodule
