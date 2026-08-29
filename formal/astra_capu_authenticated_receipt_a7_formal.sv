module astra_capu_authenticated_receipt_a7_formal;
  localparam integer DEVICE_WIDTH = 2;
  localparam integer TAG_WIDTH = 2;
  localparam integer ID_WIDTH = 2;
  localparam integer AUTH_WIDTH = 4;
  localparam integer COUNT_WIDTH = 3;

  localparam logic [2:0] AUTH_DEVICE_ID = 3'd2;
  localparam logic [2:0] AUTH_KEY_EPOCH = 3'd3;
  localparam logic [2:0] AUTH_SEQUENCE  = 3'd4;
  localparam logic [2:0] AUTH_TAG       = 3'd5;
  localparam logic [3:0] REJECT_OUTCOME_UNKNOWN    = 4'd10;
  localparam logic [3:0] REJECT_TERMINAL_COMMITTED = 4'd11;
  localparam logic [2:0] OUTCOME_NOT_COMMITTED = 3'd2;
  localparam logic [2:0] OUTCOME_COMMITTED     = 3'd3;

  (* gclk *) logic clk;
  (* anyseq *) logic cold_rst_n;
  (* anyseq *) logic logic_rst_n;

  logic device_state_load_valid = 1'b0;
  logic [COUNT_WIDTH-1:0] device_state_load_count = '0;

  (* anyseq *) logic trust_provision_valid;
  (* anyseq *) logic [DEVICE_WIDTH-1:0] trust_provision_device_id;
  (* anyseq *) logic [ID_WIDTH-1:0] trust_provision_key_epoch;
  (* anyseq *) logic [AUTH_WIDTH-1:0] trust_provision_secret;
  (* anyseq *) logic [ID_WIDTH-1:0] trust_provision_next_receipt_seq;

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

  (* anyseq *) logic receipt_valid;
  (* anyseq *) logic [DEVICE_WIDTH-1:0] receipt_device_id;
  (* anyseq *) logic [ID_WIDTH-1:0] receipt_key_epoch;
  (* anyseq *) logic [ID_WIDTH-1:0] receipt_seq;
  (* anyseq *) logic [TAG_WIDTH-1:0] receipt_authority_tag;
  (* anyseq *) logic [ID_WIDTH-1:0] receipt_incarnation;
  (* anyseq *) logic [ID_WIDTH-1:0] receipt_queue_epoch;
  (* anyseq *) logic [ID_WIDTH-1:0] receipt_slot_id;
  (* anyseq *) logic [ID_WIDTH-1:0] receipt_command_id;
  (* anyseq *) logic [ID_WIDTH-1:0] receipt_attempt_id;
  (* anyseq *) logic [ID_WIDTH-1:0] receipt_effect_id;
  (* anyseq *) logic [2:0] receipt_outcome;
  (* anyseq *) logic [AUTH_WIDTH-1:0] receipt_auth_tag;

  logic trust_provision_accept;
  logic trust_provision_rejected;
  logic receipt_auth_accept;
  logic receipt_auth_rejected;
  logic [2:0] receipt_auth_reject_code;
  logic [AUTH_WIDTH-1:0] receipt_expected_auth_tag;
  logic receipt_reconcile_accept;
  logic receipt_reconcile_rejected;
  logic [2:0] receipt_reconcile_reject_code;
  logic provision_accept;
  logic provision_rejected;
  logic reserve_valid;
  logic reserve_accept;
  logic reserve_rejected;
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
  logic trusted_valid;
  logic [DEVICE_WIDTH-1:0] trusted_device_id;
  logic [ID_WIDTH-1:0] trusted_key_epoch;
  logic [AUTH_WIDTH-1:0] trusted_secret;
  logic [ID_WIDTH-1:0] trusted_next_receipt_seq;
  logic receipt_sequence_exhausted;
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

  astra_capu_authenticated_reconciled_effect_device_a7 #(
    .DEVICE_WIDTH(DEVICE_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .AUTH_WIDTH(AUTH_WIDTH),
    .COUNT_WIDTH(COUNT_WIDTH)
  ) dut (.*);

  logic f_past_valid;
  logic seen_command;
  logic seen_forgery_reject;
  logic seen_negative_receipt;
  logic seen_successor;
  logic seen_stale_sequence;
  logic seen_committed_receipt;
  logic seen_terminal_block;
  logic [ID_WIDTH-1:0] first_receipt_seq;

  initial begin
    f_past_valid = 1'b0;
    seen_command = 1'b0;
    seen_forgery_reject = 1'b0;
    seen_negative_receipt = 1'b0;
    seen_successor = 1'b0;
    seen_stale_sequence = 1'b0;
    seen_committed_receipt = 1'b0;
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
      assume(!trust_provision_valid && !provision_valid &&
             !authority_load_valid && !authority_revoke_valid &&
             !command_valid && !receipt_valid);

    assume($onehot0({trust_provision_valid, provision_valid,
                     authority_load_valid, authority_revoke_valid,
                     command_valid, receipt_valid}));

    if (cold_rst_n) begin
      assert(receipt_auth_rejected == (receipt_valid && !receipt_auth_accept));
      assert(receipt_reconcile_accept -> receipt_auth_accept);
      assert(receipt_reconcile_rejected -> receipt_auth_accept);
      assert(device_command_accept == command_forward);
      assert(device_completion_valid == (command_forward && command_commit));

      if (receipt_auth_accept) begin
        assert(trusted_valid);
        assert(receipt_device_id == trusted_device_id);
        assert(receipt_key_epoch == trusted_key_epoch);
        assert(receipt_seq == trusted_next_receipt_seq);
        assert(receipt_auth_tag == receipt_expected_auth_tag);
        assert(!receipt_sequence_exhausted);
      end

      if (receipt_valid && trusted_valid &&
          receipt_device_id != trusted_device_id) begin
        assert(!receipt_auth_accept);
        assert(receipt_auth_reject_code == AUTH_DEVICE_ID);
        assert(!receipt_reconcile_accept);
      end

      if (receipt_valid && trusted_valid &&
          receipt_device_id == trusted_device_id &&
          receipt_key_epoch != trusted_key_epoch) begin
        assert(!receipt_auth_accept);
        assert(receipt_auth_reject_code == AUTH_KEY_EPOCH);
        assert(!receipt_reconcile_accept);
      end

      if (receipt_valid && trusted_valid &&
          receipt_device_id == trusted_device_id &&
          receipt_key_epoch == trusted_key_epoch &&
          receipt_seq != trusted_next_receipt_seq) begin
        assert(!receipt_auth_accept);
        assert(receipt_auth_reject_code == AUTH_SEQUENCE);
        assert(!receipt_reconcile_accept);
      end

      if (receipt_valid && trusted_valid &&
          receipt_device_id == trusted_device_id &&
          receipt_key_epoch == trusted_key_epoch &&
          receipt_seq == trusted_next_receipt_seq &&
          receipt_auth_tag != receipt_expected_auth_tag &&
          !receipt_sequence_exhausted) begin
        assert(!receipt_auth_accept);
        assert(receipt_auth_reject_code == AUTH_TAG);
        assert(!receipt_reconcile_accept);
      end

      if (unresolved_valid && command_valid && active_valid &&
          active_committed && !attempt_spent && !authority_revoke_valid &&
          command_authority_tag == active_authority_tag &&
          command_incarnation == active_incarnation &&
          command_queue_epoch == active_queue_epoch &&
          command_slot_id == active_slot_id &&
          command_id == active_command_id &&
          command_attempt_id == active_attempt_id &&
          command_effect_id == active_effect_id) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_OUTCOME_UNKNOWN);
      end

      if (terminal_committed && command_valid && active_valid &&
          active_committed && !attempt_spent && !authority_revoke_valid &&
          command_authority_tag == active_authority_tag &&
          command_incarnation == active_incarnation &&
          command_queue_epoch == active_queue_epoch &&
          command_slot_id == active_slot_id &&
          command_id == active_command_id &&
          command_attempt_id == active_attempt_id &&
          command_effect_id == active_effect_id) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_TERMINAL_COMMITTED);
      end
    end

    if (f_past_valid && $past(cold_rst_n)) begin
      if ($past(trust_provision_accept)) begin
        assert(trusted_valid);
        assert(trusted_device_id == $past(trust_provision_device_id));
        assert(trusted_key_epoch == $past(trust_provision_key_epoch));
        assert(trusted_secret == $past(trust_provision_secret));
        assert(trusted_next_receipt_seq ==
               $past(trust_provision_next_receipt_seq));
      end

      if ($past(receipt_auth_accept)) begin
        assert(trusted_next_receipt_seq ==
               ($past(trusted_next_receipt_seq) +
                {{(ID_WIDTH-1){1'b0}}, 1'b1}));
      end

      if ($past(receipt_valid && receipt_auth_rejected)) begin
        assert(trusted_valid == $past(trusted_valid));
        assert(trusted_device_id == $past(trusted_device_id));
        assert(trusted_key_epoch == $past(trusted_key_epoch));
        assert(trusted_secret == $past(trusted_secret));
        assert(trusted_next_receipt_seq ==
               $past(trusted_next_receipt_seq));
      end

      if ($past(receipt_auth_accept && receipt_reconcile_rejected)) begin
        assert(persistent_next_attempt == $past(persistent_next_attempt));
        assert(unresolved_valid == $past(unresolved_valid));
        assert(unresolved_attempt == $past(unresolved_attempt));
        assert(last_outcome == $past(last_outcome));
        assert(last_resolved_attempt == $past(last_resolved_attempt));
        assert(terminal_committed == $past(terminal_committed));
        assert(terminal_conflict == $past(terminal_conflict));
      end

      if (!$past(logic_rst_n)) begin
        assert(!active_valid);
        assert(!active_committed);
        assert(!attempt_spent);
        assert($stable(trusted_valid));
        assert($stable(trusted_device_id));
        assert($stable(trusted_key_epoch));
        assert($stable(trusted_secret));
        assert($stable(trusted_next_receipt_seq));
        assert($stable(persistent_valid));
        assert($stable(persistent_next_attempt));
        assert($stable(unresolved_valid));
        assert($stable(unresolved_attempt));
        assert($stable(last_outcome));
        assert($stable(last_resolved_attempt));
        assert($stable(terminal_committed));
        assert($stable(terminal_conflict));
        assert($stable(effect_count));
      end
    end

    if (command_forward && !seen_command)
      seen_command <= 1'b1;

    if (seen_command && receipt_valid && receipt_auth_rejected &&
        receipt_auth_reject_code == AUTH_TAG)
      seen_forgery_reject <= 1'b1;

    if (seen_forgery_reject && receipt_auth_accept &&
        receipt_reconcile_accept &&
        receipt_outcome == OUTCOME_NOT_COMMITTED) begin
      seen_negative_receipt <= 1'b1;
      first_receipt_seq <= receipt_seq;
    end

    if (seen_negative_receipt && command_forward && command_commit)
      seen_successor <= 1'b1;

    if (seen_successor && receipt_valid && receipt_auth_rejected &&
        receipt_auth_reject_code == AUTH_SEQUENCE &&
        receipt_seq == first_receipt_seq)
      seen_stale_sequence <= 1'b1;

    if (seen_stale_sequence && receipt_auth_accept &&
        receipt_reconcile_accept &&
        receipt_outcome == OUTCOME_COMMITTED)
      seen_committed_receipt <= 1'b1;

    if (seen_committed_receipt && command_valid && command_rejected &&
        command_reject_code == REJECT_TERMINAL_COMMITTED)
      seen_terminal_block <= 1'b1;

    cover(trust_provision_accept);
    cover(provision_accept);
    cover(command_forward);
    cover(seen_forgery_reject);
    cover(seen_negative_receipt);
    cover(seen_successor);
    cover(seen_stale_sequence);
    cover(seen_committed_receipt);
    cover(seen_terminal_block);
  end
endmodule
