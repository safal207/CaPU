`timescale 1ns/1ps

module capu_vcml_checkpoint_commit_v12_tb;
    localparam int ADDR_W = 16;
    localparam int DATA_W = 32;
    localparam int TID_W = 16;
    localparam int PARENT_W = 16;
    localparam int AUTH_W = 16;
    localparam int POLICY_W = 8;
    localparam int SLOTS = 4;
    localparam int CP_REF_W = 16;
    localparam int CP_EPOCH_W = 8;
    localparam int CP_STATE_W = 16;

    logic clk = 0;
    always #5 clk = ~clk;

    logic rst_n = 0;

    logic recovery_begin, restore_valid;
    logic [SLOTS-1:0] restore_spent_valid;
    logic [(SLOTS*AUTH_W)-1:0] restore_spent_refs;
    logic cold_start_authorized;
    logic [CP_REF_W-1:0] snapshot_checkpoint_ref;
    logic [CP_EPOCH_W-1:0] snapshot_checkpoint_epoch;
    logic [CP_STATE_W-1:0] snapshot_checkpoint_state_tag;

    logic current_anchor_valid;
    logic [CP_REF_W-1:0] current_anchor_ref;
    logic [CP_EPOCH_W-1:0] current_anchor_epoch;
    logic [CP_STATE_W-1:0] current_anchor_state_tag;

    logic checkpoint_prepare_valid;
    logic [CP_REF_W-1:0] candidate_checkpoint_ref;
    logic [CP_EPOCH_W-1:0] candidate_checkpoint_epoch;
    logic [CP_STATE_W-1:0] candidate_checkpoint_state_tag;
    logic checkpoint_abort;
    logic snapshot_persisted_valid;
    logic [CP_REF_W-1:0] persisted_checkpoint_ref;
    logic [CP_EPOCH_W-1:0] persisted_checkpoint_epoch;
    logic [CP_STATE_W-1:0] persisted_checkpoint_state_tag;
    logic anchor_commit_ack_valid;
    logic ack_base_anchor_valid;
    logic [CP_REF_W-1:0] ack_base_anchor_ref;
    logic [CP_EPOCH_W-1:0] ack_base_anchor_epoch;
    logic [CP_STATE_W-1:0] ack_base_anchor_state_tag;
    logic [CP_REF_W-1:0] ack_checkpoint_ref;
    logic [CP_EPOCH_W-1:0] ack_checkpoint_epoch;
    logic [CP_STATE_W-1:0] ack_checkpoint_state_tag;

    logic issue_valid, gate_allow, execute_ok;
    logic [ADDR_W-1:0] store_addr;
    logic [DATA_W-1:0] store_data;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [TID_W-1:0] store_transition_id;
    logic [PARENT_W-1:0] store_parent_ref;
    logic explicit_new_cause, root_authorized;
    logic [AUTH_W-1:0] root_authorization_ref;
    logic [POLICY_W-1:0] root_policy_epoch;
    logic causal_valid, commit_request, flush;

    wire buffer_valid, memory_write_enable, vcml_event_valid, issue_rejected;
    wire [ADDR_W-1:0] memory_write_addr;
    wire [DATA_W-1:0] memory_write_data;
    wire [TID_W-1:0] retired_transition_id;
    wire [PARENT_W-1:0] retired_parent_ref;
    wire retired_root_authorized;
    wire [AUTH_W-1:0] retired_root_authorization_ref;
    wire [POLICY_W-1:0] retired_root_policy_epoch;

    wire checkpoint_restore_accept, checkpoint_restore_rejected;
    wire checkpoint_rollback_detected, checkpoint_anchor_mismatch;
    wire checkpoint_cold_start_accept, derived_checkpoint_trusted;
    wire replay_recovery_ready, replay_restore_snapshot_well_formed;
    wire replay_restore_accept, replay_restore_rejected;
    wire replay_authorization_accept, replay_authorization_ref_fresh;
    wire replay_detected, replay_capacity_exhausted;
    wire [$clog2(SLOTS+1)-1:0] replay_spent_count;
    wire replay_retirement_fault, replay_retirement_without_recovery_fault;

    wire checkpoint_prepare_accept, checkpoint_prepare_rejected;
    wire checkpoint_candidate_pending, checkpoint_candidate_invalid;
    wire checkpoint_epoch_exhausted, checkpoint_stale_base_detected;
    wire checkpoint_snapshot_persist_accept, checkpoint_snapshot_persist_rejected;
    wire checkpoint_snapshot_durable, checkpoint_anchor_commit_request;
    wire checkpoint_anchor_commit_ack_accept, checkpoint_anchor_commit_ack_rejected;
    wire checkpoint_commit_event, checkpoint_request_base_anchor_valid;
    wire [CP_REF_W-1:0] checkpoint_request_base_anchor_ref;
    wire [CP_EPOCH_W-1:0] checkpoint_request_base_anchor_epoch;
    wire [CP_STATE_W-1:0] checkpoint_request_base_anchor_state_tag;
    wire [CP_REF_W-1:0] checkpoint_request_ref;
    wire [CP_EPOCH_W-1:0] checkpoint_request_epoch;
    wire [CP_STATE_W-1:0] checkpoint_request_state_tag;

    capu_vcml_store_buffer_v12 #(
        .ADDR_WIDTH(ADDR_W), .DATA_WIDTH(DATA_W),
        .TRANSITION_ID_WIDTH(TID_W), .PARENT_REF_WIDTH(PARENT_W),
        .AUTHORIZATION_REF_WIDTH(AUTH_W), .POLICY_EPOCH_WIDTH(POLICY_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS),
        .CHECKPOINT_REF_WIDTH(CP_REF_W), .CHECKPOINT_EPOCH_WIDTH(CP_EPOCH_W),
        .CHECKPOINT_STATE_TAG_WIDTH(CP_STATE_W)
    ) dut (.*);

    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task check_cond(input logic cond, input [255:0] msg);
        begin
            if (!cond) begin
                $display("FAIL %0s", msg);
                $fatal(1);
            end
        end
    endtask

    task clear_store_issue;
        begin
            issue_valid = 0;
            explicit_new_cause = 0;
            root_authorized = 0;
            root_authorization_ref = 0;
            root_policy_epoch = 0;
            causal_valid = 0;
            commit_request = 0;
            flush = 0;
        end
    endtask

    task clear_checkpoint_handshakes;
        begin
            checkpoint_prepare_valid = 0;
            checkpoint_abort = 0;
            snapshot_persisted_valid = 0;
            anchor_commit_ack_valid = 0;
            ack_base_anchor_valid = 0;
            ack_base_anchor_ref = 0;
            ack_base_anchor_epoch = 0;
            ack_base_anchor_state_tag = 0;
            ack_checkpoint_ref = 0;
            ack_checkpoint_epoch = 0;
            ack_checkpoint_state_tag = 0;
        end
    endtask

    initial begin
        recovery_begin = 0;
        restore_valid = 0;
        restore_spent_valid = 0;
        restore_spent_refs = 0;
        cold_start_authorized = 0;
        snapshot_checkpoint_ref = 0;
        snapshot_checkpoint_epoch = 0;
        snapshot_checkpoint_state_tag = 0;

        current_anchor_valid = 0;
        current_anchor_ref = 0;
        current_anchor_epoch = 0;
        current_anchor_state_tag = 0;

        candidate_checkpoint_ref = 0;
        candidate_checkpoint_epoch = 0;
        candidate_checkpoint_state_tag = 0;
        persisted_checkpoint_ref = 0;
        persisted_checkpoint_epoch = 0;
        persisted_checkpoint_state_tag = 0;
        clear_checkpoint_handshakes();

        gate_allow = 1;
        execute_ok = 1;
        store_addr = 16'h0042;
        store_data = 32'hCAFE_0042;
        store_ctag = 16'h4200; // USER / WRITE / GEN=0 / unsealed
        store_ctag_valid = 1;
        store_transition_id = 16'h0100;
        store_parent_ref = 0;
        clear_store_issue();

        repeat (2) tick();
        rst_n = 1;
        tick();

        // Initial checkpoint candidate must begin at epoch 1.
        candidate_checkpoint_ref = 16'hC001;
        candidate_checkpoint_epoch = 8'h01;
        candidate_checkpoint_state_tag = 16'hD101;
        checkpoint_prepare_valid = 1;
        #1;
        check_cond(checkpoint_prepare_accept, "initial epoch-1 checkpoint must prepare");
        tick();
        checkpoint_prepare_valid = 0;
        check_cond(checkpoint_candidate_pending && !checkpoint_snapshot_durable,
                   "prepared checkpoint must be pending but not durable");
        $display("TRACE V12 prepared ref=C001 epoch=1 durable=0");

        // Anchor ACK before snapshot persistence cannot commit authority.
        anchor_commit_ack_valid = 1;
        ack_checkpoint_ref = 16'hC001;
        ack_checkpoint_epoch = 8'h01;
        ack_checkpoint_state_tag = 16'hD101;
        #1;
        check_cond(!checkpoint_anchor_commit_request, "no commit request before snapshot persistence");
        check_cond(checkpoint_anchor_commit_ack_rejected && !checkpoint_commit_event,
                   "early anchor ack must fail closed");
        tick();
        anchor_commit_ack_valid = 0;
        $display("TRACE V12 early_anchor_ack rejected=1");

        // Wrong persistence acknowledgement must not make the candidate durable.
        snapshot_persisted_valid = 1;
        persisted_checkpoint_ref = 16'hC001;
        persisted_checkpoint_epoch = 8'h01;
        persisted_checkpoint_state_tag = 16'hDEAD;
        #1;
        check_cond(checkpoint_snapshot_persist_rejected && !checkpoint_snapshot_persist_accept,
                   "wrong persisted state tag must reject");
        tick();
        check_cond(!checkpoint_snapshot_durable, "wrong persistence ack must not latch durable state");

        // Exact persistence acknowledgement opens the anchor-CAS request.
        persisted_checkpoint_state_tag = 16'hD101;
        #1;
        check_cond(checkpoint_snapshot_persist_accept, "exact persistence ack must pass");
        tick();
        snapshot_persisted_valid = 0;
        #1;
        check_cond(checkpoint_snapshot_durable && checkpoint_anchor_commit_request,
                   "durable snapshot must request anchor commit");
        check_cond(!checkpoint_request_base_anchor_valid
                   && checkpoint_request_ref == 16'hC001
                   && checkpoint_request_epoch == 8'h01
                   && checkpoint_request_state_tag == 16'hD101,
                   "initial CAS request must bind exact candidate against empty base");
        $display("TRACE V12 snapshot_durable anchor_request=1");

        // Wrong CAS acknowledgement cannot make the checkpoint authoritative.
        anchor_commit_ack_valid = 1;
        ack_base_anchor_valid = 0;
        ack_base_anchor_ref = 0;
        ack_base_anchor_epoch = 0;
        ack_base_anchor_state_tag = 0;
        ack_checkpoint_ref = 16'hC002;
        ack_checkpoint_epoch = 8'h01;
        ack_checkpoint_state_tag = 16'hD101;
        #1;
        check_cond(checkpoint_anchor_commit_ack_rejected && !checkpoint_commit_event,
                   "wrong candidate CAS ack must reject");
        tick();
        check_cond(checkpoint_candidate_pending && checkpoint_snapshot_durable,
                   "wrong ack must leave durable candidate pending");

        // Exact external CAS acknowledgement commits recovery authority.
        ack_checkpoint_ref = 16'hC001;
        #1;
        check_cond(checkpoint_anchor_commit_ack_accept && checkpoint_commit_event,
                   "exact anchor CAS ack must commit checkpoint authority");
        tick();
        clear_checkpoint_handshakes();
        check_cond(!checkpoint_candidate_pending && !checkpoint_snapshot_durable,
                   "committed candidate must leave pending state");
        $display("TRACE V12 checkpoint_committed ref=C001 epoch=1");

        // Emulate the external durable store publishing the new anchor.
        current_anchor_valid = 1;
        current_anchor_ref = 16'hC001;
        current_anchor_epoch = 8'h01;
        current_anchor_state_tag = 16'hD101;

        // Recovery trust is now derived from exact state binding; no free-standing
        // checkpoint_trusted sideband exists in the v0.12 wrapper.
        restore_spent_valid = 4'b0001;
        restore_spent_refs[0 +: AUTH_W] = 16'hA110;
        snapshot_checkpoint_ref = 16'hC001;
        snapshot_checkpoint_epoch = 8'h01;
        snapshot_checkpoint_state_tag = 16'hD101;
        restore_valid = 1;
        #1;
        check_cond(derived_checkpoint_trusted, "exact snapshot state tag must derive trust");
        check_cond(checkpoint_restore_accept && replay_restore_accept,
                   "committed exact checkpoint must restore replay state");
        tick();
        restore_valid = 0;
        #1;
        check_cond(replay_recovery_ready && replay_spent_count == 1,
                   "checkpoint restore must recover spent A110");
        $display("TRACE V12 committed_checkpoint_restored spent=1");

        // Recovered replay protection remains active.
        issue_valid = 1;
        explicit_new_cause = 1;
        root_authorized = 1;
        root_authorization_ref = 16'hA110;
        root_policy_epoch = 8'h11;
        #1;
        check_cond(replay_detected && issue_rejected,
                   "restored A110 must remain replay-rejected");
        tick();
        clear_store_issue();

        // Fresh A120 still reaches causal retirement.
        issue_valid = 1;
        explicit_new_cause = 1;
        root_authorized = 1;
        root_authorization_ref = 16'hA120;
        root_policy_epoch = 8'h12;
        store_transition_id = 16'h0101;
        #1;
        check_cond(replay_authorization_accept, "fresh A120 must pass replay guard");
        tick();
        issue_valid = 0;
        explicit_new_cause = 0;
        root_authorized = 0;
        root_authorization_ref = 0;
        causal_valid = 1;
        commit_request = 1;
        tick();
        check_cond(memory_write_enable && vcml_event_valid,
                   "fresh root after restore must publish STORE and vCML event");
        clear_store_issue();
        tick();
        check_cond(replay_spent_count == 2, "A120 retirement must join spent set");
        $display("TRACE V12 fresh_after_restore ref=A120 spent=2");

        // A state-tag mismatch cannot restore even when ref+epoch match.
        recovery_begin = 1;
        tick();
        recovery_begin = 0;
        restore_spent_valid = 4'b0011;
        restore_spent_refs[0 +: AUTH_W] = 16'hA110;
        restore_spent_refs[AUTH_W +: AUTH_W] = 16'hA120;
        snapshot_checkpoint_state_tag = 16'hBAD0;
        restore_valid = 1;
        #1;
        check_cond(!derived_checkpoint_trusted && checkpoint_restore_rejected,
                   "tampered state binding must fail closed");
        tick();
        check_cond(!replay_recovery_ready, "tampered snapshot must not reopen recovery");
        snapshot_checkpoint_state_tag = 16'hD101;
        #1;
        check_cond(checkpoint_restore_accept && replay_restore_accept,
                   "exact state binding must restore after tamper rejection");
        tick();
        restore_valid = 0;
        check_cond(replay_recovery_ready && replay_spent_count == 2,
                   "exact checkpoint must restore both spent refs");
        $display("TRACE V12 state_binding_tamper rejected=1 exact_restore=1");

        // Prepare C002/2 against C001/1, then emulate a concurrent writer that
        // advances the durable anchor before our snapshot persistence completes.
        candidate_checkpoint_ref = 16'hC002;
        candidate_checkpoint_epoch = 8'h02;
        candidate_checkpoint_state_tag = 16'hD202;
        checkpoint_prepare_valid = 1;
        #1;
        check_cond(checkpoint_prepare_accept, "C002/2 must prepare against C001/1");
        tick();
        checkpoint_prepare_valid = 0;
        current_anchor_ref = 16'hC009;
        current_anchor_epoch = 8'h02;
        current_anchor_state_tag = 16'hD209;
        #1;
        check_cond(checkpoint_stale_base_detected && !checkpoint_anchor_commit_request,
                   "concurrent anchor advance must stale the prepared candidate");
        tick();
        check_cond(!checkpoint_candidate_pending,
                   "stale-base candidate must be discarded fail-closed");
        $display("TRACE V12 concurrent_anchor_advance stale_candidate=1");

        // Skipping an epoch is forbidden.
        candidate_checkpoint_ref = 16'hC010;
        candidate_checkpoint_epoch = 8'h04; // current anchor is epoch 2; expected 3
        candidate_checkpoint_state_tag = 16'hD310;
        checkpoint_prepare_valid = 1;
        #1;
        check_cond(checkpoint_candidate_invalid && checkpoint_prepare_rejected,
                   "skipped checkpoint epoch must reject");
        tick();
        checkpoint_prepare_valid = 0;

        // Valid C010/3 may persist, but abort after persistence must not make it
        // authoritative. The durable snapshot may be orphaned; the anchor is not.
        candidate_checkpoint_epoch = 8'h03;
        checkpoint_prepare_valid = 1;
        #1;
        check_cond(checkpoint_prepare_accept, "next checkpoint epoch must prepare");
        tick();
        checkpoint_prepare_valid = 0;
        snapshot_persisted_valid = 1;
        persisted_checkpoint_ref = 16'hC010;
        persisted_checkpoint_epoch = 8'h03;
        persisted_checkpoint_state_tag = 16'hD310;
        #1;
        check_cond(checkpoint_snapshot_persist_accept, "C010/3 persistence must accept");
        tick();
        snapshot_persisted_valid = 0;
        check_cond(checkpoint_anchor_commit_request, "persisted C010/3 must request anchor CAS");
        checkpoint_abort = 1;
        #1;
        check_cond(!checkpoint_anchor_commit_request && !checkpoint_commit_event,
                   "abort must suppress anchor commit even after persistence");
        tick();
        checkpoint_abort = 0;
        check_cond(!checkpoint_candidate_pending, "abort must clear pending candidate");
        check_cond(current_anchor_ref == 16'hC009 && current_anchor_epoch == 8'h02,
                   "abort must not alter external authoritative anchor");
        $display("TRACE V12 persisted_then_abort anchor_unchanged=C009/2");

        // Re-drive C010/3 and commit it with an exact base+candidate CAS ack.
        checkpoint_prepare_valid = 1;
        #1;
        check_cond(checkpoint_prepare_accept, "aborted checkpoint may be prepared again");
        tick();
        checkpoint_prepare_valid = 0;
        snapshot_persisted_valid = 1;
        #1;
        check_cond(checkpoint_snapshot_persist_accept, "re-driven snapshot persistence must accept");
        tick();
        snapshot_persisted_valid = 0;
        anchor_commit_ack_valid = 1;
        ack_base_anchor_valid = 1;
        ack_base_anchor_ref = 16'hC009;
        ack_base_anchor_epoch = 8'h02;
        ack_base_anchor_state_tag = 16'hD209;
        ack_checkpoint_ref = 16'hC010;
        ack_checkpoint_epoch = 8'h03;
        ack_checkpoint_state_tag = 16'hD310;
        #1;
        check_cond(checkpoint_anchor_commit_ack_accept && checkpoint_commit_event,
                   "exact non-empty-base CAS ack must commit C010/3");
        tick();
        clear_checkpoint_handshakes();
        current_anchor_ref = 16'hC010;
        current_anchor_epoch = 8'h03;
        current_anchor_state_tag = 16'hD310;
        $display("TRACE V12 checkpoint_committed ref=C010 epoch=3");

        // Epoch wrap is fail-closed.
        current_anchor_epoch = 8'hFF;
        candidate_checkpoint_ref = 16'hC011;
        candidate_checkpoint_epoch = 8'h00;
        candidate_checkpoint_state_tag = 16'hD411;
        checkpoint_prepare_valid = 1;
        #1;
        check_cond(checkpoint_epoch_exhausted && checkpoint_prepare_rejected,
                   "checkpoint epoch wrap must fail closed");
        tick();
        checkpoint_prepare_valid = 0;
        $display("TRACE V12 epoch_exhausted wrap_rejected=1");

        $display("CAPU_VCML_BRIDGE_V12_CHECKPOINT_COMMIT_PASS");
        $finish;
    end
endmodule
