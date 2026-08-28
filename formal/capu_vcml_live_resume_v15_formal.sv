module capu_vcml_live_resume_v15_formal;
    localparam int ADDR_W = 4;
    localparam int DATA_W = 8;
    localparam int TID_W = 4;
    localparam int AUTH_W = 4;
    localparam int POLICY_W = 4;
    localparam int SLOTS = 2;

    (* gclk *) reg clk;
    reg rst_n = 1'b0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg recovery_begin;
    (* anyseq *) reg restore_valid;
    (* anyseq *) reg [SLOTS-1:0] restore_spent_valid;
    (* anyseq *) reg [(SLOTS*AUTH_W)-1:0] restore_spent_refs;
    (* anyseq *) reg restore_causal_head_valid;
    (* anyseq *) reg [TID_W-1:0] restore_causal_head_transition_id;
    (* anyseq *) reg [3:0] restore_causal_head_gen;
    (* anyseq *) reg restore_sealed_chain;

    (* anyseq *) reg issue_valid;
    (* anyseq *) reg gate_allow;
    (* anyseq *) reg execute_ok;
    (* anyseq *) reg [ADDR_W-1:0] store_addr;
    (* anyseq *) reg [DATA_W-1:0] store_data;
    (* anyseq *) reg [15:0] store_ctag;
    (* anyseq *) reg store_ctag_valid;
    (* anyseq *) reg [TID_W-1:0] store_transition_id;
    (* anyseq *) reg [TID_W-1:0] store_parent_ref;
    (* anyseq *) reg explicit_new_cause;
    (* anyseq *) reg root_authorized;
    (* anyseq *) reg [AUTH_W-1:0] root_authorization_ref;
    (* anyseq *) reg [POLICY_W-1:0] root_policy_epoch;
    (* anyseq *) reg causal_valid;
    (* anyseq *) reg commit_request;
    (* anyseq *) reg flush;

    wire buffer_valid;
    wire memory_write_enable;
    wire [ADDR_W-1:0] memory_write_addr;
    wire [DATA_W-1:0] memory_write_data;
    wire vcml_event_valid;
    wire [TID_W-1:0] retired_transition_id;
    wire [TID_W-1:0] retired_parent_ref;
    wire retired_root_authorized;
    wire [AUTH_W-1:0] retired_root_authorization_ref;
    wire [POLICY_W-1:0] retired_root_policy_epoch;
    wire issue_rejected;
    wire live_causal_state_ready;
    wire live_causal_head_valid;
    wire [TID_W-1:0] live_causal_head_transition_id;
    wire [3:0] live_causal_head_gen;
    wire live_sealed_chain;
    wire live_generation_exhausted;
    wire causal_restore_snapshot_well_formed;
    wire causal_restore_accept;
    wire causal_restore_rejected;
    wire replay_recovery_ready;
    wire replay_restore_snapshot_well_formed;
    wire replay_restore_accept;
    wire replay_restore_rejected;
    wire replay_authorization_accept;
    wire replay_authorization_ref_fresh;
    wire replay_detected;
    wire replay_capacity_exhausted;
    wire [$clog2(SLOTS+1)-1:0] replay_spent_count;
    wire replay_retirement_fault;
    wire replay_retirement_without_recovery_fault;

    capu_vcml_store_buffer_v15 #(
        .ADDR_WIDTH(ADDR_W),
        .DATA_WIDTH(DATA_W),
        .TRANSITION_ID_WIDTH(TID_W),
        .PARENT_REF_WIDTH(TID_W),
        .AUTHORIZATION_REF_WIDTH(AUTH_W),
        .POLICY_EPOCH_WIDTH(POLICY_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS)
    ) dut (.*);

    reg expect_restored = 1'b0;
    reg expected_head_valid = 1'b0;
    reg [TID_W-1:0] expected_head_id = '0;
    reg [3:0] expected_head_gen = 4'h0;
    reg expected_seal = 1'b0;
    reg prev_recovery_activity = 1'b0;

    reg seen_open_restore = 1'b0;
    reg seen_exact_continuation_admit = 1'b0;
    reg seen_exact_continuation_retire = 1'b0;
    reg seen_sealed_reject = 1'b0;
    reg seen_genf_reject = 1'b0;
    reg seen_restored_replay_reject = 1'b0;
    reg seen_recovery_flush = 1'b0;

    wire normal_issue_admitted = issue_valid && !explicit_new_cause && !issue_rejected;

    always @(posedge clk) begin
        if (!rst_n) begin
            expect_restored <= 1'b0;
            prev_recovery_activity <= 1'b0;
            seen_open_restore <= 1'b0;
            seen_exact_continuation_admit <= 1'b0;
            seen_exact_continuation_retire <= 1'b0;
            seen_sealed_reject <= 1'b0;
            seen_genf_reject <= 1'b0;
            seen_restored_replay_reject <= 1'b0;
            seen_recovery_flush <= 1'b0;
        end else begin
            if (expect_restored) begin
                assert(live_causal_state_ready);
                assert(live_causal_head_valid == expected_head_valid);
                assert(live_causal_head_transition_id == expected_head_id);
                assert(live_causal_head_gen == expected_head_gen);
                assert(live_sealed_chain == expected_seal);
                expect_restored <= 1'b0;
            end

            if (causal_restore_accept) begin
                assert(restore_valid);
                assert(causal_restore_snapshot_well_formed);
                assert(replay_restore_accept);
                expect_restored <= 1'b1;
                expected_head_valid <= restore_causal_head_valid;
                expected_head_id <= restore_causal_head_transition_id;
                expected_head_gen <= restore_causal_head_gen;
                expected_seal <= restore_sealed_chain;
                if (restore_causal_head_valid
                    && !restore_sealed_chain
                    && restore_causal_head_gen != 4'hF)
                    seen_open_restore <= 1'b1;
            end

            if (restore_valid && !causal_restore_snapshot_well_formed) begin
                assert(!causal_restore_accept);
                assert(causal_restore_rejected);
            end

            if (issue_valid && !live_causal_state_ready)
                assert(issue_rejected);

            if (normal_issue_admitted) begin
                assert(live_causal_state_ready);
                assert(live_causal_head_valid);
                assert(!live_sealed_chain);
                assert(!live_generation_exhausted);
                assert(store_parent_ref == live_causal_head_transition_id);
                assert(store_ctag[7:4] == (live_causal_head_gen + 4'h1));
                if (seen_open_restore)
                    seen_exact_continuation_admit <= 1'b1;
            end

            if (live_causal_state_ready && live_sealed_chain
                && issue_valid && !explicit_new_cause) begin
                assert(issue_rejected);
                seen_sealed_reject <= 1'b1;
            end

            if (live_causal_state_ready && live_generation_exhausted
                && issue_valid && !explicit_new_cause) begin
                assert(issue_rejected);
                seen_genf_reject <= 1'b1;
            end

            if (issue_valid && explicit_new_cause && replay_detected) begin
                assert(issue_rejected);
                seen_restored_replay_reject <= 1'b1;
            end

            if (prev_recovery_activity) begin
                assert(!buffer_valid);
                assert(!memory_write_enable);
                seen_recovery_flush <= 1'b1;
            end

            if (memory_write_enable && seen_exact_continuation_admit)
                seen_exact_continuation_retire <= 1'b1;

            assert(vcml_event_valid == memory_write_enable);

            // Recovery activity is a stronger boundary than normal flush: it
            // must close admission immediately and clear any old speculation.
            if ((recovery_begin || restore_valid) && issue_valid)
                assert(issue_rejected);

            prev_recovery_activity <= recovery_begin || restore_valid;

            cover(seen_open_restore);
            cover(seen_exact_continuation_admit);
            cover(seen_exact_continuation_retire);
            cover(seen_sealed_reject);
            cover(seen_genf_reject);
            cover(seen_restored_replay_reject);
            cover(seen_recovery_flush);
        end
    end
endmodule
