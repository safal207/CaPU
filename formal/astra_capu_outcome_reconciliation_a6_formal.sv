module astra_capu_outcome_reconciliation_a6_formal;
  localparam integer TAG_WIDTH = 3;
  localparam integer ID_WIDTH = 3;
  localparam integer COUNT_WIDTH = 4;

  localparam logic [2:0] OUTCOME_UNKNOWN       = 3'd1;
  localparam logic [2:0] OUTCOME_NOT_COMMITTED = 3'd2;
  localparam logic [2:0] OUTCOME_COMMITTED     = 3'd3;
  localparam logic [2:0] OUTCOME_CONFLICT      = 3'd4;

  localparam logic [3:0] REJECT_OUTCOME_UNKNOWN    = 4'd10;
  localparam logic [3:0] REJECT_TERMINAL_COMMITTED = 4'd11;
  localparam logic [3:0] REJECT_TERMINAL_CONFLICT  = 4'd12;

  localparam logic [2:0] RECONCILE_ATTEMPT = 3'd4;

  (* gclk *) logic clk;
  (* anyseq *) logic cold_rst_n;
  (* anyseq *) logic logic_rst_n;

  logic device_state_load_valid = 1'b0;
  logic [COUNT_WIDTH-1:0] device_state_load_count = '0;

  (* anyseq *) logic provision_valid;
  (* anyseq *) logic [TAG_WIDTH-1:0] provision_tag;
  (* anyseq *) logic [ID_WIDTH-1:0] provision_incarnation;
  (* anyseq *) logic [ID_WIDTH-1:0] provision_queue_epoch;
  (* anyseq *) logic [ID_WIDTH-1:0] provision_slot_id;
  (* anyseq *) logic [ID_WIDTH-1:0] provision_command_id;
  (* anyseq *) logic [ID_WIDTH-1:0] provision_effect_id;
  (* anyseq *) logic [ID_WIDTH-1:0] provision_next_attempt;

  (* anyseq *) logic authority_load_valid;
  (* anyseq *) logic authority_load_committed;
  (* anyseq *) logic [TAG_WIDTH-1:0] authority_load_tag;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_load_incarnation;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_load_queue_epoch;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_load_slot_id;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_load_command_id;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_load_attempt_id;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_load_effect_id;

  (* anyseq *) logic authority_revoke_valid;
  (* anyseq *) logic [TAG_WIDTH-1:0] authority_revoke_tag;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_revoke_incarnation;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_revoke_queue_epoch;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_revoke_slot_id;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_revoke_command_id;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_revoke_attempt_id;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_revoke_effect_id;

  (* anyseq *) logic command_valid;
  (* anyseq *) logic command_commit;
  (* anyseq *) logic [TAG_WIDTH-1:0] command_authority_tag;
  (* anyseq *) logic [ID_WIDTH-1:0] command_incarnation;
  (* anyseq *) logic [ID_WIDTH-1:0] command_queue_epoch;
  (* anyseq *) logic [ID_WIDTH-1:0] command_slot_id;
  (* anyseq *) logic [ID_WIDTH-1:0] command_id;
  (* anyseq *) logic [ID_WIDTH-1:0] command_attempt_id;
  (* anyseq *) logic [ID_WIDTH-1:0] command_effect_id;

  (* anyseq *) logic reconcile_valid;
  (* anyseq *) logic [TAG_WIDTH-1:0] reconcile_tag;
  (* anyseq *) logic [ID_WIDTH-1:0] reconcile_incarnation;
  (* anyseq *) logic [ID_WIDTH-1:0] reconcile_queue_epoch;
  (* anyseq *) logic [ID_WIDTH-1:0] reconcile_slot_id;
  (* anyseq *) logic [ID_WIDTH-1:0] reconcile_command_id;
  (* anyseq *) logic [ID_WIDTH-1:0] reconcile_attempt_id;
  (* anyseq *) logic [ID_WIDTH-1:0] reconcile_effect_id;
  (* anyseq *) logic [2:0] reconcile_outcome;

  logic provision_accept;
  logic provision_rejected;
  logic reserve_valid;
  logic reserve_accept;
  logic reserve_rejected;
  logic reconcile_accept;
  logic reconcile_rejected;
  logic [2:0] reconcile_reject_code;
  logic frontier_exhausted;
  logic authority_load_accept;
  logic authority_load_rejected;
  logic authority_revoke_accept;
  logic authority_revoke_rejected;
  logic command_forward;
  logic command_rejected;
  logic [3:0] command_reject_code;
  logic device_command_accept;
  logic device_completion_valid;
  logic [COUNT_WIDTH-1:0] effect_count;

  logic persistent_valid;
  logic [TAG_WIDTH-1:0] persistent_tag;
  logic [ID_WIDTH-1:0] persistent_incarnation;
  logic [ID_WIDTH-1:0] persistent_queue_epoch;
  logic [ID_WIDTH-1:0] persistent_slot_id;
  logic [ID_WIDTH-1:0] persistent_command_id;
  logic [ID_WIDTH-1:0] persistent_effect_id;
  logic [ID_WIDTH-1:0] persistent_next_attempt;
  logic unresolved_valid;
  logic [ID_WIDTH-1:0] unresolved_attempt;
  logic [2:0] last_outcome;
  logic [ID_WIDTH-1:0] last_resolved_attempt;
  logic terminal_committed;
  logic terminal_conflict;

  logic active_valid;
  logic active_committed;
  logic attempt_spent;
  logic [TAG_WIDTH-1:0] active_authority_tag;
  logic [ID_WIDTH-1:0] active_incarnation;
  logic [ID_WIDTH-1:0] active_queue_epoch;
  logic [ID_WIDTH-1:0] active_slot_id;
  logic [ID_WIDTH-1:0] active_command_id;
  logic [ID_WIDTH-1:0] active_attempt_id;
  logic [ID_WIDTH-1:0] active_effect_id;

  astra_capu_reconciled_effect_device_a6 #(
    .TAG_WIDTH(TAG_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .COUNT_WIDTH(COUNT_WIDTH)
  ) dut (.*);

  logic command_identity_matches;
  logic command_lineage_matches;
  logic reconcile_lineage_matches;
  logic reconcile_outcome_valid;

  always_comb begin
    command_identity_matches =
      command_authority_tag == active_authority_tag &&
      command_incarnation == active_incarnation &&
      command_queue_epoch == active_queue_epoch &&
      command_slot_id == active_slot_id &&
      command_id == active_command_id &&
      command_attempt_id == active_attempt_id &&
      command_effect_id == active_effect_id;

    command_lineage_matches =
      active_authority_tag == persistent_tag &&
      active_incarnation == persistent_incarnation &&
      active_queue_epoch == persistent_queue_epoch &&
      active_slot_id == persistent_slot_id &&
      active_command_id == persistent_command_id &&
      active_effect_id == persistent_effect_id;

    reconcile_lineage_matches =
      reconcile_tag == persistent_tag &&
      reconcile_incarnation == persistent_incarnation &&
      reconcile_queue_epoch == persistent_queue_epoch &&
      reconcile_slot_id == persistent_slot_id &&
      reconcile_command_id == persistent_command_id &&
      reconcile_effect_id == persistent_effect_id;

    reconcile_outcome_valid =
      reconcile_outcome == OUTCOME_NOT_COMMITTED ||
      reconcile_outcome == OUTCOME_COMMITTED ||
      reconcile_outcome == OUTCOME_CONFLICT;
  end

  logic f_past_valid;
  logic seen_first_forward;
  logic seen_logic_restart;
  logic seen_unknown_block;
  logic seen_negative_reconcile;
  logic seen_successor_forward;
  logic seen_successor_restart;
  logic seen_successor_unknown_block;
  logic seen_committed_reconcile;
  logic seen_terminal_block;

  logic [TAG_WIDTH-1:0] first_tag;
  logic [ID_WIDTH-1:0] first_incarnation;
  logic [ID_WIDTH-1:0] first_queue_epoch;
  logic [ID_WIDTH-1:0] first_slot_id;
  logic [ID_WIDTH-1:0] first_command_id;
  logic [ID_WIDTH-1:0] first_attempt_id;
  logic [ID_WIDTH-1:0] first_effect_id;

  initial begin
    f_past_valid = 1'b0;
    seen_first_forward = 1'b0;
    seen_logic_restart = 1'b0;
    seen_unknown_block = 1'b0;
    seen_negative_reconcile = 1'b0;
    seen_successor_forward = 1'b0;
    seen_successor_restart = 1'b0;
    seen_successor_unknown_block = 1'b0;
    seen_committed_reconcile = 1'b0;
    seen_terminal_block = 1'b0;
  end

  always @(posedge clk) begin
    f_past_valid <= 1'b1;

    if (!f_past_valid) begin
      assume(!cold_rst_n);
      assume(!logic_rst_n);
    end else begin
      assume(cold_rst_n);
    end

    if (!logic_rst_n)
      assume(!provision_valid && !authority_load_valid &&
             !authority_revoke_valid && !command_valid && !reconcile_valid);

    assume($onehot0({provision_valid, authority_load_valid,
                     authority_revoke_valid, command_valid,
                     reconcile_valid}));

    if (cold_rst_n) begin
      assert(device_command_accept == command_forward);
      assert(device_completion_valid == (command_forward && command_commit));
      assert(command_rejected == (command_valid && !command_forward));
      assert(reconcile_rejected == (reconcile_valid && !reconcile_accept));

      if (command_forward) begin
        assert(logic_rst_n);
        assert(active_valid && active_committed);
        assert(command_identity_matches);
        assert(!attempt_spent);
        assert(persistent_valid);
        assert(command_lineage_matches);
        assert(!unresolved_valid);
        assert(!terminal_committed && !terminal_conflict);
        assert(active_attempt_id == persistent_next_attempt);
        assert(!frontier_exhausted);
        assert(reserve_valid && reserve_accept);
      end

      if (command_valid && active_valid && active_committed &&
          command_identity_matches && !attempt_spent &&
          !authority_revoke_valid && persistent_valid &&
          command_lineage_matches && unresolved_valid) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_OUTCOME_UNKNOWN);
      end

      if (command_valid && active_valid && active_committed &&
          command_identity_matches && !attempt_spent &&
          !authority_revoke_valid && persistent_valid &&
          command_lineage_matches && terminal_committed) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_TERMINAL_COMMITTED);
      end

      if (command_valid && active_valid && active_committed &&
          command_identity_matches && !attempt_spent &&
          !authority_revoke_valid && persistent_valid &&
          command_lineage_matches && terminal_conflict) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_TERMINAL_CONFLICT);
      end

      if (reconcile_accept) begin
        assert(persistent_valid);
        assert(reconcile_lineage_matches);
        assert(unresolved_valid);
        assert(reconcile_attempt_id == unresolved_attempt);
        assert(reconcile_outcome_valid);
        assert(!terminal_committed && !terminal_conflict);
      end

      if (reconcile_valid && persistent_valid &&
          reconcile_lineage_matches && unresolved_valid &&
          reconcile_attempt_id != unresolved_attempt &&
          !terminal_committed && !terminal_conflict) begin
        assert(!reconcile_accept);
        assert(reconcile_reject_code == RECONCILE_ATTEMPT);
      end

      if (seen_first_forward && command_forward &&
          command_authority_tag == first_tag &&
          command_incarnation == first_incarnation &&
          command_queue_epoch == first_queue_epoch &&
          command_slot_id == first_slot_id &&
          command_id == first_command_id &&
          command_attempt_id == first_attempt_id &&
          command_effect_id == first_effect_id)
        assert(1'b0);
    end

    if (f_past_valid && $past(cold_rst_n)) begin
      if ($past(provision_accept)) begin
        assert(persistent_valid);
        assert(persistent_tag == $past(provision_tag));
        assert(persistent_incarnation == $past(provision_incarnation));
        assert(persistent_queue_epoch == $past(provision_queue_epoch));
        assert(persistent_slot_id == $past(provision_slot_id));
        assert(persistent_command_id == $past(provision_command_id));
        assert(persistent_effect_id == $past(provision_effect_id));
        assert(persistent_next_attempt == $past(provision_next_attempt));
        assert(!unresolved_valid);
        assert(!terminal_committed && !terminal_conflict);
      end

      if ($past(command_forward)) begin
        assert(unresolved_valid);
        assert(unresolved_attempt == $past(active_attempt_id));
        assert(last_outcome == OUTCOME_UNKNOWN);
        assert(persistent_next_attempt ==
               ($past(active_attempt_id) + {{(ID_WIDTH-1){1'b0}}, 1'b1}));
        if ($past(command_commit))
          assert(effect_count == $past(effect_count) + {{(COUNT_WIDTH-1){1'b0}}, 1'b1});
        else
          assert(effect_count == $past(effect_count));
      end

      if ($past(reconcile_accept)) begin
        assert(!unresolved_valid);
        assert(last_outcome == $past(reconcile_outcome));
        assert(last_resolved_attempt == $past(reconcile_attempt_id));
        assert(persistent_next_attempt == $past(persistent_next_attempt));
        if ($past(reconcile_outcome) == OUTCOME_NOT_COMMITTED) begin
          assert(!terminal_committed && !terminal_conflict);
        end else if ($past(reconcile_outcome) == OUTCOME_COMMITTED) begin
          assert(terminal_committed && !terminal_conflict);
        end else if ($past(reconcile_outcome) == OUTCOME_CONFLICT) begin
          assert(terminal_conflict && !terminal_committed);
        end
      end

      if (!$past(logic_rst_n)) begin
        assert(!active_valid);
        assert(!active_committed);
        assert(!attempt_spent);
        assert($stable(persistent_valid));
        assert($stable(persistent_tag));
        assert($stable(persistent_incarnation));
        assert($stable(persistent_queue_epoch));
        assert($stable(persistent_slot_id));
        assert($stable(persistent_command_id));
        assert($stable(persistent_effect_id));
        assert($stable(persistent_next_attempt));
        assert($stable(unresolved_valid));
        assert($stable(unresolved_attempt));
        assert($stable(last_outcome));
        assert($stable(last_resolved_attempt));
        assert($stable(terminal_committed));
        assert($stable(terminal_conflict));
        assert($stable(effect_count));
      end

      if ($past(command_valid && command_rejected))
        assert(effect_count == $past(effect_count));

      if ($past(reconcile_valid && reconcile_rejected)) begin
        assert(persistent_next_attempt == $past(persistent_next_attempt));
        assert(unresolved_valid == $past(unresolved_valid));
        assert(unresolved_attempt == $past(unresolved_attempt));
        assert(last_outcome == $past(last_outcome));
        assert(last_resolved_attempt == $past(last_resolved_attempt));
        assert(terminal_committed == $past(terminal_committed));
        assert(terminal_conflict == $past(terminal_conflict));
      end
    end

    if (command_forward && !seen_first_forward) begin
      seen_first_forward <= 1'b1;
      first_tag <= command_authority_tag;
      first_incarnation <= command_incarnation;
      first_queue_epoch <= command_queue_epoch;
      first_slot_id <= command_slot_id;
      first_command_id <= command_id;
      first_attempt_id <= command_attempt_id;
      first_effect_id <= command_effect_id;
    end

    if (seen_first_forward && !logic_rst_n)
      seen_logic_restart <= 1'b1;

    if (seen_logic_restart && command_valid && command_rejected &&
        command_reject_code == REJECT_OUTCOME_UNKNOWN &&
        command_authority_tag == first_tag &&
        command_incarnation == first_incarnation &&
        command_queue_epoch == first_queue_epoch &&
        command_slot_id == first_slot_id &&
        command_id == first_command_id &&
        command_attempt_id == first_attempt_id &&
        command_effect_id == first_effect_id)
      seen_unknown_block <= 1'b1;

    if (seen_unknown_block && reconcile_accept &&
        reconcile_outcome == OUTCOME_NOT_COMMITTED &&
        reconcile_tag == first_tag &&
        reconcile_incarnation == first_incarnation &&
        reconcile_queue_epoch == first_queue_epoch &&
        reconcile_slot_id == first_slot_id &&
        reconcile_command_id == first_command_id &&
        reconcile_attempt_id == first_attempt_id &&
        reconcile_effect_id == first_effect_id)
      seen_negative_reconcile <= 1'b1;

    if (seen_negative_reconcile && command_forward &&
        command_authority_tag == first_tag &&
        command_incarnation == first_incarnation &&
        command_queue_epoch == first_queue_epoch &&
        command_slot_id == first_slot_id &&
        command_id == first_command_id &&
        command_attempt_id ==
          (first_attempt_id + {{(ID_WIDTH-1){1'b0}}, 1'b1}) &&
        command_effect_id == first_effect_id)
      seen_successor_forward <= 1'b1;

    if (seen_successor_forward && !logic_rst_n)
      seen_successor_restart <= 1'b1;

    if (seen_successor_restart && command_valid && command_rejected &&
        command_reject_code == REJECT_OUTCOME_UNKNOWN)
      seen_successor_unknown_block <= 1'b1;

    if (seen_successor_unknown_block && reconcile_accept &&
        reconcile_outcome == OUTCOME_COMMITTED &&
        reconcile_tag == first_tag &&
        reconcile_incarnation == first_incarnation &&
        reconcile_queue_epoch == first_queue_epoch &&
        reconcile_slot_id == first_slot_id &&
        reconcile_command_id == first_command_id &&
        reconcile_attempt_id ==
          (first_attempt_id + {{(ID_WIDTH-1){1'b0}}, 1'b1}) &&
        reconcile_effect_id == first_effect_id)
      seen_committed_reconcile <= 1'b1;

    if (seen_committed_reconcile && command_valid && command_rejected &&
        command_reject_code == REJECT_TERMINAL_COMMITTED)
      seen_terminal_block <= 1'b1;

    cover(provision_accept);
    cover(command_forward);
    cover(seen_logic_restart);
    cover(seen_unknown_block);
    cover(seen_negative_reconcile);
    cover(seen_successor_forward);
    cover(seen_successor_unknown_block);
    cover(seen_committed_reconcile);
    cover(seen_terminal_block);
  end
endmodule
