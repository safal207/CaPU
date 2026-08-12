module capu_vcml_store_buffer_v16 #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int TRANSITION_ID_WIDTH = 64,
    parameter int PARENT_REF_WIDTH = 64,
    parameter int AUTHORIZATION_REF_WIDTH = 16,
    parameter int POLICY_EPOCH_WIDTH = 8,
    parameter int SPENT_AUTHORIZATION_SLOTS = 4,
    parameter int ARCH_EPOCH_WIDTH = 8,
    parameter bit REQUIRE_WRITE_CLASS = 1'b1
) (
    input logic clk,
    input logic rst_n,

    input logic recovery_begin,
    input logic restore_valid,
    input logic [ARCH_EPOCH_WIDTH-1:0] restore_arch_epoch,
    input logic [ARCH_EPOCH_WIDTH-1:0] restore_causal_epoch,
    input logic [ADDR_WIDTH-1:0] restore_pc,
    input logic [DATA_WIDTH-1:0] restore_gpr0,
    input logic [DATA_WIDTH-1:0] restore_gpr1,
    input logic [DATA_WIDTH-1:0] restore_gpr2,
    input logic [DATA_WIDTH-1:0] restore_gpr3,
    input logic [7:0] restore_status,

    input logic [SPENT_AUTHORIZATION_SLOTS-1:0] restore_spent_valid,
    input logic [(SPENT_AUTHORIZATION_SLOTS*AUTHORIZATION_REF_WIDTH)-1:0] restore_spent_refs,
    input logic restore_causal_head_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] restore_causal_head_transition_id,
    input logic [3:0] restore_causal_head_gen,
    input logic restore_sealed_chain,

    input logic issue_valid,
    input logic [ADDR_WIDTH-1:0] issue_pc,
    input logic [1:0] store_addr_reg,
    input logic [1:0] store_data_reg,
    input logic gate_allow,
    input logic execute_ok,
    input logic [15:0] store_ctag,
    input logic store_ctag_valid,
    input logic [TRANSITION_ID_WIDTH-1:0] store_transition_id,
    input logic [PARENT_REF_WIDTH-1:0] store_parent_ref,
    input logic explicit_new_cause,
    input logic root_authorized,
    input logic [AUTHORIZATION_REF_WIDTH-1:0] root_authorization_ref,
    input logic [POLICY_EPOCH_WIDTH-1:0] root_policy_epoch,
    input logic causal_valid,
    input logic commit_request,
    input logic flush,

    output logic memory_write_enable,
    output logic [ADDR_WIDTH-1:0] memory_write_addr,
    output logic [DATA_WIDTH-1:0] memory_write_data,
    output logic vcml_event_valid,
    output logic issue_rejected,
    output logic speculative_buffer_valid,

    output logic live_execution_ready,
    output logic [ARCH_EPOCH_WIDTH-1:0] live_restore_epoch,
    output logic [ADDR_WIDTH-1:0] live_pc,
    output logic [DATA_WIDTH-1:0] live_gpr0,
    output logic [DATA_WIDTH-1:0] live_gpr1,
    output logic [DATA_WIDTH-1:0] live_gpr2,
    output logic [DATA_WIDTH-1:0] live_gpr3,
    output logic [7:0] live_status,

    output logic live_causal_state_ready,
    output logic live_causal_head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] live_causal_head_transition_id,
    output logic [3:0] live_causal_head_gen,
    output logic live_sealed_chain,
    output logic live_generation_exhausted,

    output logic split_state_restore_rejected,
    output logic architectural_restore_accept
);

    logic arch_state_ready;
    logic epochs_match;
    logic inner_restore_valid;
    logic inner_recovery_begin;
    logic inner_issue_valid;
    logic inner_issue_rejected;
    logic buffer_valid;
    logic [TRANSITION_ID_WIDTH-1:0] retired_transition_id;
    logic [PARENT_REF_WIDTH-1:0] retired_parent_ref;
    logic retired_root_authorized;
    logic [AUTHORIZATION_REF_WIDTH-1:0] retired_root_authorization_ref;
    logic [POLICY_EPOCH_WIDTH-1:0] retired_root_policy_epoch;
    logic causal_restore_snapshot_well_formed;
    logic causal_restore_accept;
    logic causal_restore_rejected;
    logic replay_recovery_ready;
    logic replay_restore_snapshot_well_formed;
    logic replay_restore_accept;
    logic replay_restore_rejected;
    logic replay_authorization_accept;
    logic replay_authorization_ref_fresh;
    logic replay_detected;
    logic replay_capacity_exhausted;
    logic [$clog2(SPENT_AUTHORIZATION_SLOTS+1)-1:0] replay_spent_count;
    logic replay_retirement_fault;
    logic replay_retirement_without_recovery_fault;
    logic [ADDR_WIDTH-1:0] selected_store_addr;
    logic [DATA_WIDTH-1:0] selected_store_data;

    assign epochs_match = restore_arch_epoch == restore_causal_epoch;
    assign split_state_restore_rejected = restore_valid && !epochs_match;
    assign inner_recovery_begin = recovery_begin || split_state_restore_rejected;
    // Recovery has strict priority: a snapshot presented while recovery_begin is
    // asserted cannot be reported as accepted because sequential state is being
    // cleared on that edge.
    assign inner_restore_valid = restore_valid && epochs_match && !recovery_begin;
    assign live_execution_ready = arch_state_ready && live_causal_state_ready;
    assign inner_issue_valid = issue_valid
                            && live_execution_ready
                            && !inner_recovery_begin
                            && !restore_valid
                            && (issue_pc == live_pc);
    assign speculative_buffer_valid = buffer_valid;

    always_comb begin
        case (store_addr_reg)
            2'd0: selected_store_addr = live_gpr0[ADDR_WIDTH-1:0];
            2'd1: selected_store_addr = live_gpr1[ADDR_WIDTH-1:0];
            2'd2: selected_store_addr = live_gpr2[ADDR_WIDTH-1:0];
            default: selected_store_addr = live_gpr3[ADDR_WIDTH-1:0];
        endcase
        case (store_data_reg)
            2'd0: selected_store_data = live_gpr0;
            2'd1: selected_store_data = live_gpr1;
            2'd2: selected_store_data = live_gpr2;
            default: selected_store_data = live_gpr3;
        endcase
    end

    capu_vcml_store_buffer_v15 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TRANSITION_ID_WIDTH(TRANSITION_ID_WIDTH),
        .PARENT_REF_WIDTH(PARENT_REF_WIDTH),
        .AUTHORIZATION_REF_WIDTH(AUTHORIZATION_REF_WIDTH),
        .POLICY_EPOCH_WIDTH(POLICY_EPOCH_WIDTH),
        .SPENT_AUTHORIZATION_SLOTS(SPENT_AUTHORIZATION_SLOTS),
        .REQUIRE_WRITE_CLASS(REQUIRE_WRITE_CLASS)
    ) inner (
        .clk(clk), .rst_n(rst_n),
        .recovery_begin(inner_recovery_begin), .restore_valid(inner_restore_valid),
        .restore_spent_valid(restore_spent_valid), .restore_spent_refs(restore_spent_refs),
        .restore_causal_head_valid(restore_causal_head_valid),
        .restore_causal_head_transition_id(restore_causal_head_transition_id),
        .restore_causal_head_gen(restore_causal_head_gen), .restore_sealed_chain(restore_sealed_chain),
        .issue_valid(inner_issue_valid), .gate_allow(gate_allow), .execute_ok(execute_ok),
        .store_addr(selected_store_addr), .store_data(selected_store_data),
        .store_ctag(store_ctag), .store_ctag_valid(store_ctag_valid),
        .store_transition_id(store_transition_id), .store_parent_ref(store_parent_ref),
        .explicit_new_cause(explicit_new_cause), .root_authorized(root_authorized),
        .root_authorization_ref(root_authorization_ref), .root_policy_epoch(root_policy_epoch),
        .causal_valid(causal_valid), .commit_request(commit_request), .flush(flush),
        .buffer_valid(buffer_valid), .memory_write_enable(memory_write_enable),
        .memory_write_addr(memory_write_addr), .memory_write_data(memory_write_data),
        .vcml_event_valid(vcml_event_valid), .retired_transition_id(retired_transition_id),
        .retired_parent_ref(retired_parent_ref), .retired_root_authorized(retired_root_authorized),
        .retired_root_authorization_ref(retired_root_authorization_ref),
        .retired_root_policy_epoch(retired_root_policy_epoch), .issue_rejected(inner_issue_rejected),
        .live_causal_state_ready(live_causal_state_ready),
        .live_causal_head_valid(live_causal_head_valid),
        .live_causal_head_transition_id(live_causal_head_transition_id),
        .live_causal_head_gen(live_causal_head_gen), .live_sealed_chain(live_sealed_chain),
        .live_generation_exhausted(live_generation_exhausted),
        .causal_restore_snapshot_well_formed(causal_restore_snapshot_well_formed),
        .causal_restore_accept(causal_restore_accept), .causal_restore_rejected(causal_restore_rejected),
        .replay_recovery_ready(replay_recovery_ready),
        .replay_restore_snapshot_well_formed(replay_restore_snapshot_well_formed),
        .replay_restore_accept(replay_restore_accept), .replay_restore_rejected(replay_restore_rejected),
        .replay_authorization_accept(replay_authorization_accept),
        .replay_authorization_ref_fresh(replay_authorization_ref_fresh),
        .replay_detected(replay_detected), .replay_capacity_exhausted(replay_capacity_exhausted),
        .replay_spent_count(replay_spent_count), .replay_retirement_fault(replay_retirement_fault),
        .replay_retirement_without_recovery_fault(replay_retirement_without_recovery_fault)
    );

    assign architectural_restore_accept = causal_restore_accept && inner_restore_valid;
    assign issue_rejected = issue_valid
                         && (!live_execution_ready
                             || inner_recovery_begin
                             || restore_valid
                             || issue_pc != live_pc
                             || inner_issue_rejected);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arch_state_ready <= 1'b0;
            live_restore_epoch <= '0;
            live_pc <= '0;
            live_gpr0 <= '0; live_gpr1 <= '0; live_gpr2 <= '0; live_gpr3 <= '0;
            live_status <= '0;
        end else if (inner_recovery_begin) begin
            arch_state_ready <= 1'b0;
        end else if (architectural_restore_accept) begin
            arch_state_ready <= 1'b1;
            live_restore_epoch <= restore_arch_epoch;
            live_pc <= restore_pc;
            live_gpr0 <= restore_gpr0; live_gpr1 <= restore_gpr1;
            live_gpr2 <= restore_gpr2; live_gpr3 <= restore_gpr3;
            live_status <= restore_status;
        end else if (memory_write_enable) begin
            live_pc <= live_pc + {{(ADDR_WIDTH-1){1'b0}},1'b1};
        end
    end

`ifdef CAPU_ASSERTIONS
    property p_split_state_restore_fails_closed;
        @(posedge clk) disable iff (!rst_n)
            (restore_valid && !epochs_match)
            |-> (!architectural_restore_accept && !memory_write_enable && issue_rejected == issue_valid);
    endproperty
    assert property (p_split_state_restore_fails_closed);

    property p_recovery_has_priority;
        @(posedge clk) disable iff (!rst_n)
            recovery_begin |-> (!architectural_restore_accept && (issue_valid -> issue_rejected));
    endproperty
    assert property (p_recovery_has_priority);

    property p_split_state_restore_closes_runtime;
        @(posedge clk) disable iff (!rst_n)
            split_state_restore_rejected |=> !live_execution_ready;
    endproperty
    assert property (p_split_state_restore_closes_runtime);

    property p_atomic_arch_restore;
        @(posedge clk) disable iff (!rst_n)
            architectural_restore_accept |=> (
                live_restore_epoch == $past(restore_arch_epoch)
                && live_pc == $past(restore_pc)
                && live_gpr0 == $past(restore_gpr0)
                && live_gpr1 == $past(restore_gpr1)
                && live_gpr2 == $past(restore_gpr2)
                && live_gpr3 == $past(restore_gpr3)
                && live_status == $past(restore_status)
                && ((recovery_begin || restore_valid) || live_execution_ready));
    endproperty
    assert property (p_atomic_arch_restore);

    property p_wrong_pc_rejected;
        @(posedge clk) disable iff (!rst_n)
            (issue_valid && live_execution_ready && issue_pc != live_pc) |-> issue_rejected;
    endproperty
    assert property (p_wrong_pc_rejected);
`endif
endmodule
