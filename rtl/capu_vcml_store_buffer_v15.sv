module capu_vcml_store_buffer_v15 #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int TRANSITION_ID_WIDTH = 64,
    parameter int PARENT_REF_WIDTH = 64,
    parameter int AUTHORIZATION_REF_WIDTH = 16,
    parameter int POLICY_EPOCH_WIDTH = 8,
    parameter int SPENT_AUTHORIZATION_SLOTS = 4,
    parameter bit REQUIRE_WRITE_CLASS = 1'b1
) (
    input  logic clk,
    input  logic rst_n,

    // Accepted v0.14 full-state checkpoint snapshot. In the intended
    // composition restore_valid is driven only by v0.14 full_state_restore_accept.
    input  logic recovery_begin,
    input  logic restore_valid,
    input  logic [SPENT_AUTHORIZATION_SLOTS-1:0] restore_spent_valid,
    input  logic [(SPENT_AUTHORIZATION_SLOTS*AUTHORIZATION_REF_WIDTH)-1:0] restore_spent_refs,
    input  logic restore_causal_head_valid,
    input  logic [TRANSITION_ID_WIDTH-1:0] restore_causal_head_transition_id,
    input  logic [3:0] restore_causal_head_gen,
    input  logic restore_sealed_chain,

    input  logic issue_valid,
    input  logic gate_allow,
    input  logic execute_ok,
    input  logic [ADDR_WIDTH-1:0] store_addr,
    input  logic [DATA_WIDTH-1:0] store_data,
    input  logic [15:0] store_ctag,
    input  logic store_ctag_valid,
    input  logic [TRANSITION_ID_WIDTH-1:0] store_transition_id,
    input  logic [PARENT_REF_WIDTH-1:0] store_parent_ref,
    input  logic explicit_new_cause,
    input  logic root_authorized,
    input  logic [AUTHORIZATION_REF_WIDTH-1:0] root_authorization_ref,
    input  logic [POLICY_EPOCH_WIDTH-1:0] root_policy_epoch,
    input  logic causal_valid,
    input  logic commit_request,
    input  logic flush,

    output logic buffer_valid,
    output logic memory_write_enable,
    output logic [ADDR_WIDTH-1:0] memory_write_addr,
    output logic [DATA_WIDTH-1:0] memory_write_data,
    output logic vcml_event_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] retired_transition_id,
    output logic [PARENT_REF_WIDTH-1:0] retired_parent_ref,
    output logic retired_root_authorized,
    output logic [AUTHORIZATION_REF_WIDTH-1:0] retired_root_authorization_ref,
    output logic [POLICY_EPOCH_WIDTH-1:0] retired_root_policy_epoch,
    output logic issue_rejected,

    output logic live_causal_state_ready,
    output logic live_causal_head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] live_causal_head_transition_id,
    output logic [3:0] live_causal_head_gen,
    output logic live_sealed_chain,
    output logic live_generation_exhausted,

    output logic causal_restore_snapshot_well_formed,
    output logic causal_restore_accept,
    output logic causal_restore_rejected,

    output logic replay_recovery_ready,
    output logic replay_restore_snapshot_well_formed,
    output logic replay_restore_accept,
    output logic replay_restore_rejected,
    output logic replay_authorization_accept,
    output logic replay_authorization_ref_fresh,
    output logic replay_detected,
    output logic replay_capacity_exhausted,
    output logic [$clog2(SPENT_AUTHORIZATION_SLOTS+1)-1:0] replay_spent_count,
    output logic replay_retirement_fault,
    output logic replay_retirement_without_recovery_fault
);

    logic guarded_restore_valid;
    logic guarded_issue_valid;
    logic runtime_admission_ready;
    logic runtime_flush;
    logic causal_runtime_ready;
    logic guarded_root_authorized;
    logic inner_issue_rejected;
    logic inner_buffered_ctag_valid;
    logic inner_buffered_root_authorized;
    logic [AUTHORIZATION_REF_WIDTH-1:0] inner_buffered_root_authorization_ref;
    logic inner_root_retire_now;

    function automatic logic causal_snapshot_well_formed_fn(
        input logic head_valid,
        input logic [TRANSITION_ID_WIDTH-1:0] head_transition_id,
        input logic [3:0] head_gen,
        input logic sealed_chain
    );
        begin
            // Empty/cold causal state has one canonical representation. A valid
            // head may carry any implementation-width transition id and GEN;
            // the v0.14 commitment/anchor layer is responsible for binding it.
            causal_snapshot_well_formed_fn = head_valid
                || (head_transition_id == '0 && head_gen == 4'h0 && !sealed_chain);
        end
    endfunction

    assign causal_restore_snapshot_well_formed = causal_snapshot_well_formed_fn(
        restore_causal_head_valid,
        restore_causal_head_transition_id,
        restore_causal_head_gen,
        restore_sealed_chain);

    assign guarded_restore_valid = restore_valid
                                && causal_restore_snapshot_well_formed;

    // Every execution class is fail-closed while recovery is incomplete or a
    // restore attempt is in flight. v0.10 guarded only roots because ordinary
    // continuations had no restored head; v0.15 deliberately closes that gap.
    assign live_causal_state_ready = causal_runtime_ready && replay_recovery_ready;
    assign runtime_admission_ready = live_causal_state_ready
                                  && !recovery_begin
                                  && !restore_valid;
    assign guarded_issue_valid = issue_valid && runtime_admission_ready;

    // Recovery activity is also a speculation barrier. A candidate that was
    // buffered before recovery_begin, or before any restore attempt, cannot
    // retire across the recovery boundary.
    assign runtime_flush = flush || recovery_begin || restore_valid;

    assign causal_restore_accept = replay_restore_accept;
    assign causal_restore_rejected = restore_valid && !causal_restore_accept;

    assign guarded_root_authorized = explicit_new_cause
                                   ? replay_authorization_accept
                                   : root_authorized;

    // Match the downstream v0.9 retirement predicate so the recovery guard
    // consumes a newly used root reference on the exact visible retirement.
    assign inner_root_retire_now = buffer_valid
                                && causal_valid
                                && inner_buffered_ctag_valid
                                && commit_request
                                && !runtime_flush
                                && inner_buffered_root_authorized;

    capu_replay_recovery_guard #(
        .AUTHORIZATION_REF_WIDTH(AUTHORIZATION_REF_WIDTH),
        .SPENT_AUTHORIZATION_SLOTS(SPENT_AUTHORIZATION_SLOTS)
    ) replay_guard (
        .clk(clk),
        .rst_n(rst_n),
        .recovery_begin(recovery_begin),
        .restore_valid(guarded_restore_valid),
        .restore_spent_valid(restore_spent_valid),
        .restore_spent_refs(restore_spent_refs),
        .explicit_new_cause(explicit_new_cause),
        .root_authorized(root_authorized),
        .root_authorization_ref(root_authorization_ref),
        .root_retired_valid(inner_root_retire_now),
        .retired_root_authorization_ref(inner_buffered_root_authorization_ref),
        .recovery_ready(replay_recovery_ready),
        .restore_snapshot_well_formed(replay_restore_snapshot_well_formed),
        .restore_accept(replay_restore_accept),
        .restore_rejected(replay_restore_rejected),
        .authorization_accept(replay_authorization_accept),
        .authorization_ref_fresh(replay_authorization_ref_fresh),
        .authorization_replay_detected(replay_detected),
        .authorization_capacity_exhausted(replay_capacity_exhausted),
        .spent_authorization_count(replay_spent_count),
        .retirement_replay_fault(replay_retirement_fault),
        .retirement_without_recovery_fault(replay_retirement_without_recovery_fault)
    );

    capu_vcml_store_buffer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TRANSITION_ID_WIDTH(TRANSITION_ID_WIDTH),
        .PARENT_REF_WIDTH(PARENT_REF_WIDTH),
        .AUTHORIZATION_REF_WIDTH(AUTHORIZATION_REF_WIDTH),
        .POLICY_EPOCH_WIDTH(POLICY_EPOCH_WIDTH),
        .SPENT_AUTHORIZATION_SLOTS(SPENT_AUTHORIZATION_SLOTS),
        .REQUIRE_WRITE_CLASS(REQUIRE_WRITE_CLASS),
        .ENABLE_CAUSAL_STATE_RESTORE(1'b1)
    ) inner (
        .clk(clk),
        .rst_n(rst_n),
        .issue_valid(guarded_issue_valid),
        .gate_allow(gate_allow),
        .execute_ok(execute_ok),
        .store_addr(store_addr),
        .store_data(store_data),
        .store_ctag(store_ctag),
        .store_ctag_valid(store_ctag_valid),
        .store_transition_id(store_transition_id),
        .store_parent_ref(store_parent_ref),
        .explicit_new_cause(explicit_new_cause),
        .root_authorized(guarded_root_authorized),
        .root_authorization_ref(root_authorization_ref),
        .root_policy_epoch(root_policy_epoch),
        .causal_valid(causal_valid),
        .commit_request(commit_request),
        .flush(runtime_flush),
        .causal_state_restore_valid(replay_restore_accept),
        .restore_causal_head_valid(restore_causal_head_valid),
        .restore_causal_head_transition_id(restore_causal_head_transition_id),
        .restore_causal_head_gen(restore_causal_head_gen),
        .restore_sealed_chain(restore_sealed_chain),
        .buffer_valid(buffer_valid),
        .buffered_ctag_valid(inner_buffered_ctag_valid),
        .buffered_root_authorized(inner_buffered_root_authorized),
        .buffered_root_authorization_ref(inner_buffered_root_authorization_ref),
        .memory_write_enable(memory_write_enable),
        .memory_write_addr(memory_write_addr),
        .memory_write_data(memory_write_data),
        .vcml_event_valid(vcml_event_valid),
        .retired_transition_id(retired_transition_id),
        .retired_parent_ref(retired_parent_ref),
        .retired_root_authorized(retired_root_authorized),
        .retired_root_authorization_ref(retired_root_authorization_ref),
        .retired_root_policy_epoch(retired_root_policy_epoch),
        .sealed_chain(live_sealed_chain),
        .causal_head_valid(live_causal_head_valid),
        .causal_head_transition_id(live_causal_head_transition_id),
        .causal_head_gen(live_causal_head_gen),
        .generation_exhausted(live_generation_exhausted),
        .issue_rejected(inner_issue_rejected)
    );

    assign issue_rejected = issue_valid
                         && (!runtime_admission_ready || inner_issue_rejected);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            causal_runtime_ready <= 1'b0;
        else if (recovery_begin)
            causal_runtime_ready <= 1'b0;
        else if (replay_restore_accept)
            causal_runtime_ready <= 1'b1;
    end

`ifdef CAPU_ASSERTIONS
    property p_fail_closed_until_full_runtime_restore;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && !live_causal_state_ready) |-> issue_rejected;
    endproperty
    assert property (p_fail_closed_until_full_runtime_restore);

    property p_recovery_activity_flushes_speculation;
        @(posedge clk) disable iff (!rst_n)
            (recovery_begin || restore_valid) |=> (!buffer_valid && !memory_write_enable);
    endproperty
    assert property (p_recovery_activity_flushes_speculation);

    property p_restore_never_executes_store;
        @(posedge clk) disable iff (!rst_n)
            replay_restore_accept |-> (!memory_write_enable && !vcml_event_valid);
    endproperty
    assert property (p_restore_never_executes_store);

    property p_restore_establishes_exact_live_causal_state;
        @(posedge clk) disable iff (!rst_n)
            replay_restore_accept
            |=> (live_causal_state_ready
                 && live_causal_head_valid == $past(restore_causal_head_valid)
                 && live_causal_head_transition_id == $past(restore_causal_head_transition_id)
                 && live_causal_head_gen == $past(restore_causal_head_gen)
                 && live_sealed_chain == $past(restore_sealed_chain));
    endproperty
    assert property (p_restore_establishes_exact_live_causal_state);

    property p_live_continuation_uses_restored_parent_gen_seal;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && runtime_admission_ready && !explicit_new_cause && !issue_rejected)
            |-> (live_causal_head_valid
                 && !live_sealed_chain
                 && !live_generation_exhausted
                 && store_parent_ref == live_causal_head_transition_id
                 && store_ctag[7:4] == (live_causal_head_gen + 4'h1));
    endproperty
    assert property (p_live_continuation_uses_restored_parent_gen_seal);

    property p_recovered_seal_blocks_automatic_continuation;
        @(posedge clk) disable iff (!rst_n)
            (live_causal_state_ready && live_sealed_chain
             && issue_valid && !explicit_new_cause) |-> issue_rejected;
    endproperty
    assert property (p_recovered_seal_blocks_automatic_continuation);

    property p_recovered_gen_exhaustion_blocks_wrap;
        @(posedge clk) disable iff (!rst_n)
            (live_causal_state_ready && live_generation_exhausted
             && issue_valid && !explicit_new_cause) |-> issue_rejected;
    endproperty
    assert property (p_recovered_gen_exhaustion_blocks_wrap);

    property p_restored_replay_remains_rejected;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && explicit_new_cause && replay_detected) |-> issue_rejected;
    endproperty
    assert property (p_restored_replay_remains_rejected);
`endif

endmodule
