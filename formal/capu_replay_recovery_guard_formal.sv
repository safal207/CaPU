module capu_replay_recovery_guard_formal;
    localparam int AUTH_W = 4;
    localparam int SLOTS = 4;
    localparam int COUNT_W = $clog2(SLOTS + 1);

    (* gclk *) reg clk;
    reg rst_n = 1'b0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg recovery_begin;
    (* anyseq *) reg restore_valid;
    (* anyseq *) reg [SLOTS-1:0] restore_spent_valid;
    (* anyseq *) reg [(SLOTS*AUTH_W)-1:0] restore_spent_refs;
    (* anyseq *) reg explicit_new_cause;
    (* anyseq *) reg root_authorized;
    (* anyseq *) reg [AUTH_W-1:0] root_authorization_ref;
    (* anyseq *) reg root_retired_valid;
    (* anyseq *) reg [AUTH_W-1:0] retired_root_authorization_ref;

    wire recovery_ready;
    wire restore_snapshot_well_formed;
    wire restore_accept, restore_rejected;
    wire authorization_accept, authorization_ref_fresh, authorization_replay_detected;
    wire authorization_capacity_exhausted;
    wire [COUNT_W-1:0] spent_authorization_count;
    wire retirement_replay_fault, retirement_without_recovery_fault;

    capu_replay_recovery_guard #(
        .AUTHORIZATION_REF_WIDTH(AUTH_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .recovery_begin(recovery_begin),
        .restore_valid(restore_valid),
        .restore_spent_valid(restore_spent_valid),
        .restore_spent_refs(restore_spent_refs),
        .explicit_new_cause(explicit_new_cause),
        .root_authorized(root_authorized),
        .root_authorization_ref(root_authorization_ref),
        .root_retired_valid(root_retired_valid),
        .retired_root_authorization_ref(retired_root_authorization_ref),
        .recovery_ready(recovery_ready),
        .restore_snapshot_well_formed(restore_snapshot_well_formed),
        .restore_accept(restore_accept), .restore_rejected(restore_rejected),
        .authorization_accept(authorization_accept),
        .authorization_ref_fresh(authorization_ref_fresh),
        .authorization_replay_detected(authorization_replay_detected),
        .authorization_capacity_exhausted(authorization_capacity_exhausted),
        .spent_authorization_count(spent_authorization_count),
        .retirement_replay_fault(retirement_replay_fault),
        .retirement_without_recovery_fault(retirement_without_recovery_fault)
    );

    function automatic [COUNT_W-1:0] popcount(input [SLOTS-1:0] mask);
        integer k;
        begin
            popcount = '0;
            for (k = 0; k < SLOTS; k = k + 1)
                popcount = popcount + mask[k];
        end
    endfunction

    reg prev_recovery_begin = 1'b0;
    reg prev_restore_accept = 1'b0;
    reg [COUNT_W-1:0] prev_restore_count = '0;
    reg prev_restore_slot0_valid = 1'b0;
    reg [AUTH_W-1:0] prev_restore_slot0_ref = '0;

    reg seen_nonempty_restore = 1'b0;
    reg seen_restored_replay = 1'b0;
    reg seen_recovery_begin = 1'b0;
    reg seen_restore_after_recovery = 1'b0;
    reg seen_bad_snapshot_reject = 1'b0;
    reg seen_live_restore_reject = 1'b0;
    reg seen_full_restore = 1'b0;
    reg seen_capacity_reject = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            prev_recovery_begin <= 1'b0;
            prev_restore_accept <= 1'b0;
            prev_restore_count <= '0;
            prev_restore_slot0_valid <= 1'b0;
            prev_restore_slot0_ref <= '0;
            seen_nonempty_restore <= 1'b0;
            seen_restored_replay <= 1'b0;
            seen_recovery_begin <= 1'b0;
            seen_restore_after_recovery <= 1'b0;
            seen_bad_snapshot_reject <= 1'b0;
            seen_live_restore_reject <= 1'b0;
            seen_full_restore <= 1'b0;
            seen_capacity_reject <= 1'b0;
        end else begin
            assert(spent_authorization_count <= SLOTS);
            assert(authorization_capacity_exhausted
                   == (spent_authorization_count == SLOTS));

            if (!recovery_ready || recovery_begin || restore_valid)
                assert(!authorization_accept);

            if (authorization_accept) begin
                assert(recovery_ready);
                assert(!recovery_begin);
                assert(!restore_valid);
                assert(explicit_new_cause);
                assert(root_authorized);
                assert(root_authorization_ref != '0);
                assert(authorization_ref_fresh);
                assert(!authorization_replay_detected);
                assert(!authorization_capacity_exhausted);
            end

            if (authorization_replay_detected) begin
                assert(recovery_ready);
                assert(!authorization_ref_fresh);
                assert(!authorization_accept);
            end

            if (restore_accept) begin
                assert(restore_valid);
                assert(!recovery_begin);
                assert(!recovery_ready);
                assert(restore_snapshot_well_formed);
            end

            if (restore_rejected)
                assert(restore_valid);

            if (restore_valid && !restore_snapshot_well_formed) begin
                assert(!restore_accept);
                assert(restore_rejected);
                seen_bad_snapshot_reject <= 1'b1;
            end

            if (recovery_ready && restore_valid) begin
                assert(!restore_accept);
                assert(restore_rejected);
                seen_live_restore_reject <= 1'b1;
            end

            if (prev_recovery_begin) begin
                assert(!recovery_ready);
                assert(spent_authorization_count == 0);
            end

            if (prev_restore_accept) begin
                assert(recovery_ready);
                assert(spent_authorization_count == prev_restore_count);
                if (prev_restore_slot0_valid
                    && explicit_new_cause && root_authorized
                    && !recovery_begin && !restore_valid
                    && root_authorization_ref == prev_restore_slot0_ref) begin
                    assert(authorization_replay_detected);
                    assert(!authorization_accept);
                    seen_restored_replay <= 1'b1;
                end
            end

            if (restore_accept && popcount(restore_spent_valid) != 0)
                seen_nonempty_restore <= 1'b1;

            if (recovery_ready && recovery_begin)
                seen_recovery_begin <= 1'b1;

            if (seen_recovery_begin && restore_accept)
                seen_restore_after_recovery <= 1'b1;

            if (restore_accept && popcount(restore_spent_valid) == SLOTS)
                seen_full_restore <= 1'b1;

            if (authorization_capacity_exhausted
                && explicit_new_cause && root_authorized
                && root_authorization_ref != '0
                && authorization_ref_fresh && !authorization_accept)
                seen_capacity_reject <= 1'b1;

            cover(seen_nonempty_restore && seen_restored_replay);
            cover(seen_recovery_begin && seen_restore_after_recovery);
            cover(seen_bad_snapshot_reject);
            cover(seen_live_restore_reject);
            cover(seen_full_restore && seen_capacity_reject);

            prev_recovery_begin <= recovery_begin;
            prev_restore_accept <= restore_accept;
            if (restore_accept) begin
                prev_restore_count <= popcount(restore_spent_valid);
                prev_restore_slot0_valid <= restore_spent_valid[0];
                prev_restore_slot0_ref <= restore_spent_refs[0 +: AUTH_W];
            end
        end
    end
endmodule
