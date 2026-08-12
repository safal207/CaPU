module capu_replay_recovery_guard #(
    parameter int AUTHORIZATION_REF_WIDTH = 16,
    parameter int SPENT_AUTHORIZATION_SLOTS = 4
) (
    input  logic clk,
    input  logic rst_n,

    // Explicit recovery phase. A recovery begins fail-closed and must be
    // followed by one accepted snapshot before root authorization can reopen.
    input  logic recovery_begin,
    input  logic restore_valid,
    input  logic [SPENT_AUTHORIZATION_SLOTS-1:0] restore_spent_valid,
    input  logic [(SPENT_AUTHORIZATION_SLOTS*AUTHORIZATION_REF_WIDTH)-1:0] restore_spent_refs,

    input  logic explicit_new_cause,
    input  logic root_authorized,
    input  logic [AUTHORIZATION_REF_WIDTH-1:0] root_authorization_ref,

    // Qualified successful root retirement from the downstream CaPU boundary.
    input  logic root_retired_valid,
    input  logic [AUTHORIZATION_REF_WIDTH-1:0] retired_root_authorization_ref,

    output logic recovery_ready,
    output logic restore_snapshot_well_formed,
    output logic restore_accept,
    output logic restore_rejected,

    output logic authorization_accept,
    output logic authorization_ref_fresh,
    output logic authorization_replay_detected,
    output logic authorization_capacity_exhausted,
    output logic [$clog2(SPENT_AUTHORIZATION_SLOTS+1)-1:0] spent_authorization_count,

    output logic retirement_replay_fault,
    output logic retirement_without_recovery_fault
);

    localparam int SPENT_SLOT_INDEX_WIDTH =
        (SPENT_AUTHORIZATION_SLOTS <= 1) ? 1 : $clog2(SPENT_AUTHORIZATION_SLOTS);

    logic [AUTHORIZATION_REF_WIDTH-1:0]
        spent_authorization_refs [0:SPENT_AUTHORIZATION_SLOTS-1];
    logic [SPENT_AUTHORIZATION_SLOTS-1:0] spent_authorization_valid;

    logic authorization_ref_seen;
    logic retired_authorization_ref_seen;
    logic first_free_spent_slot_valid;
    logic [SPENT_SLOT_INDEX_WIDTH-1:0] first_free_spent_slot;
    logic consume_retired_authorization;
    logic recovery_gate_open;

    integer scan_idx;
    integer check_i;
    integer check_j;
    integer state_idx;

    initial begin
        if (AUTHORIZATION_REF_WIDTH < 1)
            $error("CaPU v0.10 requires AUTHORIZATION_REF_WIDTH >= 1");
        if (SPENT_AUTHORIZATION_SLOTS < 1)
            $error("CaPU v0.10 requires SPENT_AUTHORIZATION_SLOTS >= 1");
    end

    // Snapshot validity is deliberately structural, not cryptographic.
    // Every occupied slot must be non-zero and occupied refs must be unique.
    always_comb begin
        restore_snapshot_well_formed = 1'b1;
        for (check_i = 0; check_i < SPENT_AUTHORIZATION_SLOTS; check_i = check_i + 1) begin
            if (restore_spent_valid[check_i]) begin
                if (restore_spent_refs[(check_i*AUTHORIZATION_REF_WIDTH) +: AUTHORIZATION_REF_WIDTH] == '0)
                    restore_snapshot_well_formed = 1'b0;
                for (check_j = check_i + 1; check_j < SPENT_AUTHORIZATION_SLOTS; check_j = check_j + 1) begin
                    if (restore_spent_valid[check_j]
                        && restore_spent_refs[(check_i*AUTHORIZATION_REF_WIDTH) +: AUTHORIZATION_REF_WIDTH]
                           == restore_spent_refs[(check_j*AUTHORIZATION_REF_WIDTH) +: AUTHORIZATION_REF_WIDTH])
                        restore_snapshot_well_formed = 1'b0;
                end
            end
        end
    end

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
                if (spent_authorization_refs[scan_idx] == retired_root_authorization_ref)
                    retired_authorization_ref_seen = 1'b1;
            end else if (!first_free_spent_slot_valid) begin
                first_free_spent_slot_valid = 1'b1;
                first_free_spent_slot = scan_idx[SPENT_SLOT_INDEX_WIDTH-1:0];
            end
        end
    end

    assign recovery_gate_open = recovery_ready && !recovery_begin && !restore_valid;

    assign restore_accept = restore_valid
                         && !recovery_begin
                         && !recovery_ready
                         && restore_snapshot_well_formed;

    assign restore_rejected = restore_valid
                           && (recovery_begin
                               || recovery_ready
                               || !restore_snapshot_well_formed);

    assign authorization_capacity_exhausted = &spent_authorization_valid;
    assign authorization_ref_fresh = recovery_gate_open && !authorization_ref_seen;

    assign authorization_replay_detected = recovery_gate_open
                                         && explicit_new_cause
                                         && root_authorized
                                         && root_authorization_ref != '0
                                         && authorization_ref_seen;

    assign authorization_accept = recovery_gate_open
                                && explicit_new_cause
                                && root_authorized
                                && root_authorization_ref != '0
                                && !authorization_ref_seen
                                && !authorization_capacity_exhausted;

    assign retirement_replay_fault = recovery_ready
                                   && root_retired_valid
                                   && retired_root_authorization_ref != '0
                                   && retired_authorization_ref_seen;

    assign retirement_without_recovery_fault = root_retired_valid && !recovery_ready;

    assign consume_retired_authorization = recovery_ready
                                         && !recovery_begin
                                         && root_retired_valid
                                         && retired_root_authorization_ref != '0
                                         && !retired_authorization_ref_seen
                                         && first_free_spent_slot_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            recovery_ready <= 1'b0;
            spent_authorization_valid <= '0;
            for (state_idx = 0; state_idx < SPENT_AUTHORIZATION_SLOTS; state_idx = state_idx + 1)
                spent_authorization_refs[state_idx] <= '0;
        end else if (recovery_begin) begin
            recovery_ready <= 1'b0;
            spent_authorization_valid <= '0;
            for (state_idx = 0; state_idx < SPENT_AUTHORIZATION_SLOTS; state_idx = state_idx + 1)
                spent_authorization_refs[state_idx] <= '0;
        end else if (restore_accept) begin
            recovery_ready <= 1'b1;
            spent_authorization_valid <= restore_spent_valid;
            for (state_idx = 0; state_idx < SPENT_AUTHORIZATION_SLOTS; state_idx = state_idx + 1)
                spent_authorization_refs[state_idx]
                    <= restore_spent_refs[(state_idx*AUTHORIZATION_REF_WIDTH) +: AUTHORIZATION_REF_WIDTH];
        end else if (consume_retired_authorization) begin
            spent_authorization_valid[first_free_spent_slot] <= 1'b1;
            spent_authorization_refs[first_free_spent_slot] <= retired_root_authorization_ref;
        end
    end

`ifdef CAPU_ASSERTIONS
    property p_fail_closed_until_restore;
        @(posedge clk) disable iff (!rst_n)
            (!recovery_ready || recovery_begin) |-> !authorization_accept;
    endproperty
    assert property (p_fail_closed_until_restore);

    property p_replay_rejected;
        @(posedge clk) disable iff (!rst_n)
            authorization_replay_detected |-> !authorization_accept;
    endproperty
    assert property (p_replay_rejected);

    property p_bad_snapshot_not_accepted;
        @(posedge clk) disable iff (!rst_n)
            (restore_valid && !restore_snapshot_well_formed) |-> !restore_accept;
    endproperty
    assert property (p_bad_snapshot_not_accepted);

    property p_live_state_not_overwritten;
        @(posedge clk) disable iff (!rst_n)
            (recovery_ready && restore_valid) |-> restore_rejected;
    endproperty
    assert property (p_live_state_not_overwritten);
`endif

endmodule
