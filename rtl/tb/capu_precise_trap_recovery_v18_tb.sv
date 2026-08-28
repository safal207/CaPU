`timescale 1ns/1ps

module capu_precise_trap_recovery_v18_tb;
    localparam int REF_W = 4;
    localparam int EPOCH_W = 4;
    localparam int COMMIT_W = 16;
    localparam int BASE_W = 32;
    localparam int PC_W = 8;
    localparam int PRIV_W = 2;
    localparam int CAUSE_W = 4;
    localparam int PAYLOAD_W = BASE_W + PRIV_W + 1 + 1 + CAUSE_W + PC_W + PRIV_W + 1;

    logic clk = 0;
    logic rst_n = 0;
    always #5 clk = ~clk;

    logic recovery_begin, restore_valid;
    logic [REF_W-1:0] snapshot_checkpoint_ref;
    logic [EPOCH_W-1:0] snapshot_checkpoint_epoch;
    logic [COMMIT_W-1:0] snapshot_checkpoint_commitment;
    logic [PAYLOAD_W-1:0] snapshot_checkpoint_payload;
    logic snapshot_commitment_verified;
    logic [BASE_W-1:0] restore_base_payload;
    logic [PC_W-1:0] restore_pc;
    logic [PRIV_W-1:0] restore_privilege_mode;
    logic restore_trap_pending, restore_trap_is_interrupt;
    logic [CAUSE_W-1:0] restore_trap_cause;
    logic [PC_W-1:0] restore_trap_return_pc;
    logic [PRIV_W-1:0] restore_trap_return_privilege;
    logic restore_interrupt_mask;

    logic current_anchor_valid;
    logic [REF_W-1:0] current_anchor_ref;
    logic [EPOCH_W-1:0] current_anchor_epoch;
    logic [COMMIT_W-1:0] current_anchor_commitment;
    logic [PAYLOAD_W-1:0] current_anchor_payload;

    logic checkpoint_prepare_valid;
    logic [REF_W-1:0] candidate_checkpoint_ref;
    logic [EPOCH_W-1:0] candidate_checkpoint_epoch;
    logic [COMMIT_W-1:0] candidate_checkpoint_commitment;
    logic [PAYLOAD_W-1:0] candidate_checkpoint_payload;
    logic candidate_commitment_verified;
    logic [PAYLOAD_W-1:0] committed_checkpoint_payload;
    logic checkpoint_abort;

    logic snapshot_persisted_valid;
    logic [REF_W-1:0] persisted_checkpoint_ref;
    logic [EPOCH_W-1:0] persisted_checkpoint_epoch;
    logic [COMMIT_W-1:0] persisted_checkpoint_commitment;
    logic [PAYLOAD_W-1:0] persisted_checkpoint_payload;

    logic anchor_commit_ack_valid, ack_base_anchor_valid;
    logic [REF_W-1:0] ack_base_anchor_ref;
    logic [EPOCH_W-1:0] ack_base_anchor_epoch;
    logic [COMMIT_W-1:0] ack_base_anchor_commitment;
    logic [PAYLOAD_W-1:0] ack_base_anchor_payload;
    logic [REF_W-1:0] ack_checkpoint_ref;
    logic [EPOCH_W-1:0] ack_checkpoint_epoch;
    logic [COMMIT_W-1:0] ack_checkpoint_commitment;
    logic [PAYLOAD_W-1:0] ack_checkpoint_payload;

    logic normal_step_valid;
    logic [PC_W-1:0] normal_next_pc;
    logic [PRIV_W-1:0] normal_step_privilege;
    logic exception_valid;
    logic [CAUSE_W-1:0] exception_cause;
    logic [PC_W-1:0] exception_vector_pc;
    logic [PRIV_W-1:0] exception_target_privilege;
    logic interrupt_valid;
    logic [CAUSE_W-1:0] interrupt_cause;
    logic [PC_W-1:0] interrupt_vector_pc;
    logic [PRIV_W-1:0] interrupt_target_privilege;
    logic trap_return_valid;
    logic effect_issue_valid, effect_commit_valid;

    logic checkpoint_prepare_accept, checkpoint_prepare_rejected;
    logic checkpoint_snapshot_persist_accept, checkpoint_snapshot_persist_rejected;
    logic checkpoint_anchor_commit_request, checkpoint_anchor_commit_ack_accept;
    logic checkpoint_anchor_commit_ack_rejected, checkpoint_commit_event;
    logic checkpoint_candidate_pending, checkpoint_snapshot_durable;
    logic checkpoint_restore_accept, checkpoint_restore_rejected, checkpoint_restore_mismatch;
    logic live_execution_ready;
    logic [PC_W-1:0] live_pc;
    logic [PRIV_W-1:0] live_privilege_mode;
    logic live_trap_pending, live_trap_is_interrupt;
    logic [CAUSE_W-1:0] live_trap_cause;
    logic [PC_W-1:0] live_trap_return_pc;
    logic [PRIV_W-1:0] live_trap_return_privilege;
    logic live_interrupt_mask;
    logic [BASE_W-1:0] live_base_payload;
    logic normal_step_accept, normal_step_rejected, trap_enter_accept, trap_return_accept;
    logic privilege_mismatch_rejected, masked_interrupt_rejected;
    logic speculative_effect_pending, visible_effect, speculation_kill;
    logic [PAYLOAD_W-1:0] checkpoint_request_payload;

    function automatic [PAYLOAD_W-1:0] pack_payload(
        input [BASE_W-1:0] base,
        input [PC_W-1:0] pc,
        input [PRIV_W-1:0] priv,
        input trap_pending,
        input trap_is_interrupt,
        input [CAUSE_W-1:0] cause,
        input [PC_W-1:0] return_pc,
        input [PRIV_W-1:0] return_priv,
        input interrupt_mask
    );
        pack_payload = {base, pc, priv, trap_pending, trap_is_interrupt,
                        cause, return_pc, return_priv, interrupt_mask};
    endfunction

    task automatic tick;
        @(posedge clk); #1;
    endtask

    task automatic clear_pulses;
        begin
            recovery_begin = 0; restore_valid = 0; checkpoint_prepare_valid = 0;
            checkpoint_abort = 0; snapshot_persisted_valid = 0; anchor_commit_ack_valid = 0;
            normal_step_valid = 0; exception_valid = 0; interrupt_valid = 0;
            trap_return_valid = 0; effect_issue_valid = 0; effect_commit_valid = 0;
        end
    endtask

    capu_precise_trap_recovery_v18 #(
        .CHECKPOINT_REF_WIDTH(REF_W), .CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
        .CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W), .BASE_PAYLOAD_WIDTH(BASE_W),
        .PC_WIDTH(PC_W), .PRIV_WIDTH(PRIV_W), .CAUSE_WIDTH(CAUSE_W)
    ) dut (.*);

    initial begin
        recovery_begin = 0; restore_valid = 0;
        snapshot_checkpoint_ref = 0; snapshot_checkpoint_epoch = 0;
        snapshot_checkpoint_commitment = 0; snapshot_checkpoint_payload = 0;
        snapshot_commitment_verified = 0;
        restore_base_payload = 0; restore_pc = 0; restore_privilege_mode = 0;
        restore_trap_pending = 0; restore_trap_is_interrupt = 0; restore_trap_cause = 0;
        restore_trap_return_pc = 0; restore_trap_return_privilege = 0; restore_interrupt_mask = 0;
        current_anchor_valid = 0; current_anchor_ref = 0; current_anchor_epoch = 0;
        current_anchor_commitment = 0; current_anchor_payload = 0;
        checkpoint_prepare_valid = 0; candidate_checkpoint_ref = 0; candidate_checkpoint_epoch = 0;
        candidate_checkpoint_commitment = 0; candidate_checkpoint_payload = 0;
        candidate_commitment_verified = 0; committed_checkpoint_payload = 0; checkpoint_abort = 0;
        snapshot_persisted_valid = 0; persisted_checkpoint_ref = 0; persisted_checkpoint_epoch = 0;
        persisted_checkpoint_commitment = 0; persisted_checkpoint_payload = 0;
        anchor_commit_ack_valid = 0; ack_base_anchor_valid = 0; ack_base_anchor_ref = 0;
        ack_base_anchor_epoch = 0; ack_base_anchor_commitment = 0; ack_base_anchor_payload = 0;
        ack_checkpoint_ref = 0; ack_checkpoint_epoch = 0; ack_checkpoint_commitment = 0;
        ack_checkpoint_payload = 0;
        normal_step_valid = 0; normal_next_pc = 0; normal_step_privilege = 0;
        exception_valid = 0; exception_cause = 0; exception_vector_pc = 0; exception_target_privilege = 0;
        interrupt_valid = 0; interrupt_cause = 0; interrupt_vector_pc = 0; interrupt_target_privilege = 0;
        trap_return_valid = 0; effect_issue_valid = 0; effect_commit_valid = 0;

        repeat (2) tick;
        rst_n = 1;
        tick;

        // Canonical live state for first authority.
        committed_checkpoint_payload = pack_payload(32'hc001cafe, 8'h40, 2'd1, 1'b0, 1'b0,
                                                    4'h0, 8'h00, 2'd0, 1'b1);
        candidate_checkpoint_ref = 4'h3;
        candidate_checkpoint_epoch = 4'h1;
        candidate_checkpoint_commitment = 16'hb117;
        candidate_commitment_verified = 1;

        // Same causal/base payload but mutated privilege must fail at PREPARE.
        candidate_checkpoint_payload = pack_payload(32'hc001cafe, 8'h40, 2'd2, 1'b0, 1'b0,
                                                    4'h0, 8'h00, 2'd0, 1'b1);
        checkpoint_prepare_valid = 1;
        #1;
        if (!checkpoint_prepare_rejected || checkpoint_prepare_accept) $fatal(1, "mutated privilege prepared");
        $display("prepare_privilege_mutation rejected=1 exact=1");
        tick; clear_pulses();

        candidate_checkpoint_payload = committed_checkpoint_payload;
        checkpoint_prepare_valid = 1;
        #1;
        if (!checkpoint_prepare_accept) $fatal(1, "exact checkpoint prepare rejected");
        tick; clear_pulses();
        if (!checkpoint_candidate_pending) $fatal(1, "candidate not pending");

        persisted_checkpoint_ref = candidate_checkpoint_ref;
        persisted_checkpoint_epoch = candidate_checkpoint_epoch;
        persisted_checkpoint_commitment = candidate_checkpoint_commitment;
        persisted_checkpoint_payload = candidate_checkpoint_payload;
        snapshot_persisted_valid = 1;
        #1;
        if (!checkpoint_snapshot_persist_accept) $fatal(1, "exact persistence rejected");
        tick; clear_pulses();
        if (!checkpoint_snapshot_durable || !checkpoint_anchor_commit_request) $fatal(1, "not durable/requesting anchor");

        ack_base_anchor_valid = 0;
        ack_checkpoint_ref = candidate_checkpoint_ref;
        ack_checkpoint_epoch = candidate_checkpoint_epoch;
        ack_checkpoint_commitment = candidate_checkpoint_commitment;
        ack_checkpoint_payload = candidate_checkpoint_payload;
        anchor_commit_ack_valid = 1;
        #1;
        if (!checkpoint_anchor_commit_ack_accept || !checkpoint_commit_event) $fatal(1, "exact anchor ACK rejected");
        tick; clear_pulses();
        if (checkpoint_candidate_pending) $fatal(1, "authority candidate survived commit");

        // External anchor reflects the committed v0.18 record.
        current_anchor_valid = 1;
        current_anchor_ref = candidate_checkpoint_ref;
        current_anchor_epoch = candidate_checkpoint_epoch;
        current_anchor_commitment = candidate_checkpoint_commitment;
        current_anchor_payload = candidate_checkpoint_payload;

        snapshot_checkpoint_ref = current_anchor_ref;
        snapshot_checkpoint_epoch = current_anchor_epoch;
        snapshot_checkpoint_commitment = current_anchor_commitment;
        snapshot_checkpoint_payload = current_anchor_payload;
        snapshot_commitment_verified = 1;
        restore_base_payload = 32'hc001cafe;
        restore_pc = 8'h40;
        restore_privilege_mode = 2'd1;
        restore_trap_pending = 0;
        restore_trap_is_interrupt = 0;
        restore_trap_cause = 0;
        restore_trap_return_pc = 0;
        restore_trap_return_privilege = 0;
        restore_interrupt_mask = 1;

        // Same anchor with altered explicit trap/privilege bytes must reject.
        restore_privilege_mode = 2'd2;
        restore_valid = 1;
        #1;
        if (!checkpoint_restore_rejected || !checkpoint_restore_mismatch || checkpoint_restore_accept)
            $fatal(1, "mutated privilege restore accepted");
        $display("restore_privilege_mutation rejected=1");
        tick; clear_pulses();

        restore_privilege_mode = 2'd1;
        restore_valid = 1;
        #1;
        if (!checkpoint_restore_accept) $fatal(1, "exact restore rejected");
        tick; clear_pulses();
        if (!live_execution_ready || live_pc != 8'h40 || live_privilege_mode != 2'd1 || !live_interrupt_mask)
            $fatal(1, "restored runtime mismatch");
        $display("exact_restore ready=1 pc=40 privilege=1 mask=1");

        // Wrong privilege cannot advance architectural execution.
        normal_step_valid = 1; normal_step_privilege = 2'd0; normal_next_pc = 8'h41;
        #1;
        if (!privilege_mismatch_rejected || normal_step_accept) $fatal(1, "wrong privilege step accepted");
        $display("privilege_mismatch rejected=1");
        tick; clear_pulses();
        if (live_pc != 8'h40) $fatal(1, "wrong privilege changed pc");

        // Masked interrupt cannot enter a trap.
        interrupt_valid = 1; interrupt_cause = 4'h7; interrupt_vector_pc = 8'he0; interrupt_target_privilege = 2'd3;
        #1;
        if (!masked_interrupt_rejected || trap_enter_accept) $fatal(1, "masked interrupt taken");
        $display("masked_interrupt rejected=1");
        tick; clear_pulses();

        // Create speculative effect then take exception while commit is requested.
        effect_issue_valid = 1;
        #1;
        if (visible_effect) $fatal(1, "new speculative effect became visible");
        tick; clear_pulses();
        if (!speculative_effect_pending) $fatal(1, "speculative effect not pending");

        exception_valid = 1; exception_cause = 4'h5; exception_vector_pc = 8'hf0; exception_target_privilege = 2'd3;
        interrupt_valid = 1; interrupt_cause = 4'h6; interrupt_vector_pc = 8'he0; interrupt_target_privilege = 2'd2;
        effect_commit_valid = 1;
        #1;
        if (!trap_enter_accept || visible_effect || !speculation_kill) $fatal(1, "trap was not precise visible-effect barrier");
        tick; clear_pulses();
        if (speculative_effect_pending) $fatal(1, "pre-trap speculation survived");
        if (!live_trap_pending || live_trap_is_interrupt || live_trap_cause != 4'h5)
            $fatal(1, "exception priority/context wrong");
        if (live_pc != 8'hf0 || live_privilege_mode != 2'd3
            || live_trap_return_pc != 8'h40 || live_trap_return_privilege != 2'd1)
            $fatal(1, "trap entry state wrong");
        $display("exception_priority precise=1 return_pc=40 return_privilege=1");

        trap_return_valid = 1;
        #1;
        if (!trap_return_accept) $fatal(1, "trap return rejected");
        tick; clear_pulses();
        if (live_trap_pending || live_pc != 8'h40 || live_privilege_mode != 2'd1)
            $fatal(1, "trap return did not restore context");
        $display("trap_return exact=1 pc=40 privilege=1");

        normal_step_valid = 1; normal_step_privilege = 2'd1; normal_next_pc = 8'h41;
        #1;
        if (!normal_step_accept) $fatal(1, "valid normal step rejected");
        tick; clear_pulses();
        if (live_pc != 8'h41) $fatal(1, "normal step did not advance pc");

        recovery_begin = 1;
        #1;
        if (visible_effect) $fatal(1, "effect visible during recovery");
        tick; clear_pulses();
        if (live_execution_ready) $fatal(1, "runtime remained ready after recovery");
        $display("recovery_priority runtime_closed=1");

        $display("CAPU_VCML_TRAP_PRIVILEGE_V18_PASS pc=%0h", live_pc);
        $finish;
    end
endmodule
