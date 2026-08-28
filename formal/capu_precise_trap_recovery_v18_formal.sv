module capu_precise_trap_recovery_v18_formal;
    localparam int REF_W = 3;
    localparam int EPOCH_W = 3;
    localparam int COMMIT_W = 4;
    localparam int BASE_W = 12;
    localparam int PC_W = 4;
    localparam int PRIV_W = 2;
    localparam int CAUSE_W = 3;
    localparam int PAYLOAD_W = BASE_W + PRIV_W + 1 + 1 + CAUSE_W + PC_W + PRIV_W + 1;

    (* gclk *) reg clk;
    reg rst_n = 1'b0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg recovery_begin;
    (* anyseq *) reg restore_valid;
    (* anyseq *) reg [REF_W-1:0] snapshot_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] snapshot_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] snapshot_checkpoint_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] snapshot_checkpoint_payload;
    (* anyseq *) reg snapshot_commitment_verified;
    (* anyseq *) reg [BASE_W-1:0] restore_base_payload;
    (* anyseq *) reg [PC_W-1:0] restore_pc;
    (* anyseq *) reg [PRIV_W-1:0] restore_privilege_mode;
    (* anyseq *) reg restore_trap_pending;
    (* anyseq *) reg restore_trap_is_interrupt;
    (* anyseq *) reg [CAUSE_W-1:0] restore_trap_cause;
    (* anyseq *) reg [PC_W-1:0] restore_trap_return_pc;
    (* anyseq *) reg [PRIV_W-1:0] restore_trap_return_privilege;
    (* anyseq *) reg restore_interrupt_mask;

    (* anyseq *) reg current_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] current_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] current_anchor_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] current_anchor_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] current_anchor_payload;

    (* anyseq *) reg checkpoint_prepare_valid;
    (* anyseq *) reg [REF_W-1:0] candidate_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] candidate_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] candidate_checkpoint_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] candidate_checkpoint_payload;
    (* anyseq *) reg candidate_commitment_verified;
    (* anyseq *) reg [PAYLOAD_W-1:0] committed_checkpoint_payload;
    (* anyseq *) reg checkpoint_abort;
    (* anyseq *) reg snapshot_persisted_valid;
    (* anyseq *) reg [REF_W-1:0] persisted_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] persisted_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] persisted_checkpoint_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] persisted_checkpoint_payload;
    (* anyseq *) reg anchor_commit_ack_valid;
    (* anyseq *) reg ack_base_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] ack_base_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_base_anchor_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] ack_base_anchor_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] ack_base_anchor_payload;
    (* anyseq *) reg [REF_W-1:0] ack_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] ack_checkpoint_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] ack_checkpoint_payload;

    (* anyseq *) reg normal_step_valid;
    (* anyseq *) reg [PC_W-1:0] normal_next_pc;
    (* anyseq *) reg [PRIV_W-1:0] normal_step_privilege;
    (* anyseq *) reg exception_valid;
    (* anyseq *) reg [CAUSE_W-1:0] exception_cause;
    (* anyseq *) reg [PC_W-1:0] exception_vector_pc;
    (* anyseq *) reg [PRIV_W-1:0] exception_target_privilege;
    (* anyseq *) reg interrupt_valid;
    (* anyseq *) reg [CAUSE_W-1:0] interrupt_cause;
    (* anyseq *) reg [PC_W-1:0] interrupt_vector_pc;
    (* anyseq *) reg [PRIV_W-1:0] interrupt_target_privilege;
    (* anyseq *) reg trap_return_valid;
    (* anyseq *) reg effect_issue_valid;
    (* anyseq *) reg effect_commit_valid;

    wire checkpoint_prepare_accept, checkpoint_prepare_rejected;
    wire checkpoint_snapshot_persist_accept, checkpoint_snapshot_persist_rejected;
    wire checkpoint_anchor_commit_request, checkpoint_anchor_commit_ack_accept;
    wire checkpoint_anchor_commit_ack_rejected, checkpoint_commit_event;
    wire checkpoint_candidate_pending, checkpoint_snapshot_durable;
    wire checkpoint_restore_accept, checkpoint_restore_rejected, checkpoint_restore_mismatch;
    wire live_execution_ready;
    wire [PC_W-1:0] live_pc;
    wire [PRIV_W-1:0] live_privilege_mode;
    wire live_trap_pending, live_trap_is_interrupt;
    wire [CAUSE_W-1:0] live_trap_cause;
    wire [PC_W-1:0] live_trap_return_pc;
    wire [PRIV_W-1:0] live_trap_return_privilege;
    wire live_interrupt_mask;
    wire [BASE_W-1:0] live_base_payload;
    wire normal_step_accept, normal_step_rejected, trap_enter_accept, trap_return_accept;
    wire privilege_mismatch_rejected, masked_interrupt_rejected;
    wire speculative_effect_pending, visible_effect, speculation_kill;
    wire [PAYLOAD_W-1:0] checkpoint_request_payload;

    wire [PAYLOAD_W-1:0] restore_exact_payload = {
        restore_base_payload, restore_pc, restore_privilege_mode,
        restore_trap_pending, restore_trap_is_interrupt, restore_trap_cause,
        restore_trap_return_pc, restore_trap_return_privilege, restore_interrupt_mask
    };
    wire expected_exception_take = exception_valid && live_execution_ready
        && !live_trap_pending && !recovery_begin && !restore_valid;
    wire expected_interrupt_take = !expected_exception_take && interrupt_valid
        && live_execution_ready && !live_trap_pending && !live_interrupt_mask
        && !recovery_begin && !restore_valid;
    wire expected_trap_take = expected_exception_take || expected_interrupt_take;

    capu_precise_trap_recovery_v18 #(
        .CHECKPOINT_REF_WIDTH(REF_W), .CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
        .CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W), .BASE_PAYLOAD_WIDTH(BASE_W),
        .PC_WIDTH(PC_W), .PRIV_WIDTH(PRIV_W), .CAUSE_WIDTH(CAUSE_W),
        .TRAP_PAYLOAD_WIDTH(PAYLOAD_W)
    ) dut (.*);

    reg expect_restore = 1'b0;
    reg [BASE_W-1:0] exp_base;
    reg [PC_W-1:0] exp_pc;
    reg [PRIV_W-1:0] exp_priv;
    reg exp_trap_pending, exp_trap_interrupt;
    reg [CAUSE_W-1:0] exp_cause;
    reg [PC_W-1:0] exp_return_pc;
    reg [PRIV_W-1:0] exp_return_priv;
    reg exp_mask;

    reg expect_trap = 1'b0;
    reg [PC_W-1:0] exp_trap_vector;
    reg [PRIV_W-1:0] exp_trap_target_priv;
    reg [CAUSE_W-1:0] exp_trap_cause;
    reg exp_trap_interrupt_kind;
    reg [PC_W-1:0] exp_trap_saved_pc;
    reg [PRIV_W-1:0] exp_trap_saved_priv;

    reg expect_return = 1'b0;
    reg [PC_W-1:0] exp_return_target_pc;
    reg [PRIV_W-1:0] exp_return_target_priv;
    reg expect_killed = 1'b0;
    reg expect_authority_cleared = 1'b0;

    reg seen_exact_restore = 1'b0;
    reg seen_restore_mismatch = 1'b0;
    reg seen_privilege_reject = 1'b0;
    reg seen_masked_interrupt = 1'b0;
    reg seen_exception = 1'b0;
    reg seen_interrupt = 1'b0;
    reg seen_trap_return = 1'b0;
    reg seen_speculation_kill = 1'b0;
    reg seen_authority_commit = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            expect_restore <= 1'b0;
            expect_trap <= 1'b0;
            expect_return <= 1'b0;
            expect_killed <= 1'b0;
            expect_authority_cleared <= 1'b0;
            seen_exact_restore <= 1'b0;
            seen_restore_mismatch <= 1'b0;
            seen_privilege_reject <= 1'b0;
            seen_masked_interrupt <= 1'b0;
            seen_exception <= 1'b0;
            seen_interrupt <= 1'b0;
            seen_trap_return <= 1'b0;
            seen_speculation_kill <= 1'b0;
            seen_authority_commit <= 1'b0;
        end else begin
            if (expect_restore) begin
                assert(live_execution_ready);
                assert(live_base_payload == exp_base);
                assert(live_pc == exp_pc);
                assert(live_privilege_mode == exp_priv);
                assert(live_trap_pending == exp_trap_pending);
                assert(live_trap_is_interrupt == exp_trap_interrupt);
                assert(live_trap_cause == exp_cause);
                assert(live_trap_return_pc == exp_return_pc);
                assert(live_trap_return_privilege == exp_return_priv);
                assert(live_interrupt_mask == exp_mask);
                expect_restore <= 1'b0;
            end
            if (expect_trap) begin
                assert(live_trap_pending);
                assert(live_pc == exp_trap_vector);
                assert(live_privilege_mode == exp_trap_target_priv);
                assert(live_trap_cause == exp_trap_cause);
                assert(live_trap_is_interrupt == exp_trap_interrupt_kind);
                assert(live_trap_return_pc == exp_trap_saved_pc);
                assert(live_trap_return_privilege == exp_trap_saved_priv);
                expect_trap <= 1'b0;
            end
            if (expect_return) begin
                assert(!live_trap_pending);
                assert(live_pc == exp_return_target_pc);
                assert(live_privilege_mode == exp_return_target_priv);
                expect_return <= 1'b0;
            end
            if (expect_killed) begin
                assert(!speculative_effect_pending);
                expect_killed <= 1'b0;
            end
            if (expect_authority_cleared) begin
                assert(!checkpoint_candidate_pending);
                assert(!checkpoint_snapshot_durable);
                expect_authority_cleared <= 1'b0;
            end

            assert(trap_enter_accept == expected_trap_take);
            assert(!visible_effect || (!recovery_begin && !restore_valid && !trap_enter_accept));
            assert(!normal_step_accept || normal_step_privilege == live_privilege_mode);
            assert(!trap_return_accept || live_trap_pending);

            if (checkpoint_prepare_accept) begin
                assert(candidate_checkpoint_payload == committed_checkpoint_payload);
                assert(candidate_commitment_verified);
                assert(candidate_checkpoint_commitment != '0);
            end
            if (checkpoint_snapshot_persist_accept) begin
                assert(persisted_checkpoint_payload == checkpoint_request_payload);
            end
            if (checkpoint_commit_event) begin
                assert(checkpoint_anchor_commit_ack_accept);
                assert(ack_checkpoint_payload == checkpoint_request_payload);
                seen_authority_commit <= 1'b1;
            end
            if (recovery_begin || restore_valid) begin
                assert(!checkpoint_prepare_accept);
                assert(!checkpoint_snapshot_persist_accept);
                assert(!checkpoint_commit_event);
                expect_authority_cleared <= 1'b1;
            end

            if (checkpoint_restore_accept) begin
                assert(snapshot_checkpoint_payload == restore_exact_payload);
                assert(current_anchor_valid);
                assert(snapshot_commitment_verified);
                assert(snapshot_checkpoint_payload == current_anchor_payload);
                exp_base <= restore_base_payload;
                exp_pc <= restore_pc;
                exp_priv <= restore_privilege_mode;
                exp_trap_pending <= restore_trap_pending;
                exp_trap_interrupt <= restore_trap_is_interrupt;
                exp_cause <= restore_trap_cause;
                exp_return_pc <= restore_trap_return_pc;
                exp_return_priv <= restore_trap_return_privilege;
                exp_mask <= restore_interrupt_mask;
                expect_restore <= 1'b1;
                seen_exact_restore <= 1'b1;
            end
            if (checkpoint_restore_mismatch) begin
                assert(checkpoint_restore_rejected);
                assert(!checkpoint_restore_accept);
                seen_restore_mismatch <= 1'b1;
            end

            if (privilege_mismatch_rejected) begin
                assert(!normal_step_accept);
                seen_privilege_reject <= 1'b1;
            end
            if (masked_interrupt_rejected) begin
                assert(!trap_enter_accept);
                seen_masked_interrupt <= 1'b1;
            end

            if (trap_enter_accept) begin
                assert(!visible_effect);
                assert(speculation_kill);
                exp_trap_vector <= expected_exception_take ? exception_vector_pc : interrupt_vector_pc;
                exp_trap_target_priv <= expected_exception_take
                    ? exception_target_privilege : interrupt_target_privilege;
                exp_trap_cause <= expected_exception_take ? exception_cause : interrupt_cause;
                exp_trap_interrupt_kind <= expected_interrupt_take;
                exp_trap_saved_pc <= live_pc;
                exp_trap_saved_priv <= live_privilege_mode;
                expect_trap <= 1'b1;
                expect_killed <= 1'b1;
                seen_speculation_kill <= 1'b1;
                if (expected_exception_take)
                    seen_exception <= 1'b1;
                if (expected_interrupt_take)
                    seen_interrupt <= 1'b1;
            end

            if (trap_return_accept) begin
                exp_return_target_pc <= live_trap_return_pc;
                exp_return_target_priv <= live_trap_return_privilege;
                expect_return <= 1'b1;
                seen_trap_return <= 1'b1;
            end

            cover(seen_exact_restore);
            cover(seen_restore_mismatch);
            cover(seen_privilege_reject);
            cover(seen_masked_interrupt);
            cover(seen_exception);
            cover(seen_interrupt);
            cover(seen_trap_return);
            cover(seen_speculation_kill);
            cover(seen_authority_commit);
        end
    end
endmodule
