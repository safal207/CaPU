module astra_capu_authority_shim_a4_formal;
  localparam integer TAG_WIDTH = 3;
  localparam integer ID_WIDTH = 3;
  localparam integer COUNT_WIDTH = 4;

  localparam logic [2:0] REJECT_NO_AUTHORITY   = 3'd1;
  localparam logic [2:0] REJECT_UNCOMMITTED    = 3'd2;
  localparam logic [2:0] REJECT_IDENTITY       = 3'd3;
  localparam logic [2:0] REJECT_ALREADY_ISSUED = 3'd4;
  localparam logic [2:0] REJECT_REVOKE_PENDING = 3'd5;

  (* gclk *) logic clk;
  (* anyseq *) logic rst_n;

  (* anyseq *) logic device_state_load_valid;
  (* anyseq *) logic [COUNT_WIDTH-1:0] device_state_load_count;

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

  logic authority_load_accept;
  logic authority_load_rejected;
  logic authority_revoke_accept;
  logic authority_revoke_rejected;
  logic command_forward;
  logic command_rejected;
  logic [2:0] command_reject_code;
  logic device_command_accept;
  logic device_completion_valid;
  logic [COUNT_WIDTH-1:0] effect_count;
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

  astra_capu_authorized_effect_device_a4 #(
    .TAG_WIDTH(TAG_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .COUNT_WIDTH(COUNT_WIDTH)
  ) dut (.*);

  logic command_identity_matches;
  logic revoke_identity_matches;
  always_comb begin
    command_identity_matches =
      command_authority_tag == active_authority_tag &&
      command_incarnation == active_incarnation &&
      command_queue_epoch == active_queue_epoch &&
      command_slot_id == active_slot_id &&
      command_id == active_command_id &&
      command_attempt_id == active_attempt_id &&
      command_effect_id == active_effect_id;

    revoke_identity_matches =
      authority_revoke_tag == active_authority_tag &&
      authority_revoke_incarnation == active_incarnation &&
      authority_revoke_queue_epoch == active_queue_epoch &&
      authority_revoke_slot_id == active_slot_id &&
      authority_revoke_command_id == active_command_id &&
      authority_revoke_attempt_id == active_attempt_id &&
      authority_revoke_effect_id == active_effect_id;
  end

  logic f_past_valid;
  initial f_past_valid = 1'b0;

  always @(posedge clk) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid)
      assume(!rst_n);
    else
      assume(rst_n);

    assume($onehot0({device_state_load_valid, authority_load_valid,
                     authority_revoke_valid, command_valid}));

    if (rst_n) begin
      assert(device_command_accept == command_forward);
      assert(device_completion_valid == (command_forward && command_commit));
      assert(command_rejected == (command_valid && !command_forward));
      assert(authority_load_rejected == (authority_load_valid && !authority_load_accept));
      assert(authority_revoke_rejected == (authority_revoke_valid && !authority_revoke_accept));

      if (command_forward) begin
        assert(active_valid);
        assert(active_committed);
        assert(command_identity_matches);
        assert(!attempt_spent);
        assert(!authority_revoke_valid);
      end

      if (command_valid && !active_valid) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_NO_AUTHORITY);
      end

      if (command_valid && active_valid && !active_committed && !authority_revoke_valid) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_UNCOMMITTED);
      end

      if (command_valid && active_valid && active_committed &&
          !command_identity_matches && !authority_revoke_valid) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_IDENTITY);
      end

      if (command_valid && active_valid && active_committed &&
          command_identity_matches && attempt_spent && !authority_revoke_valid) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_ALREADY_ISSUED);
      end

      if (command_valid && authority_revoke_valid) begin
        assert(!command_forward);
        assert(command_reject_code == REJECT_REVOKE_PENDING);
      end

      if (authority_revoke_accept) begin
        assert(active_valid);
        assert(revoke_identity_matches);
      end

      if (authority_load_accept)
        assert(!active_valid);
    end

    if (f_past_valid && $past(rst_n)) begin
      if ($past(authority_load_accept)) begin
        assert(active_valid);
        assert(active_committed == $past(authority_load_committed));
        assert(active_authority_tag == $past(authority_load_tag));
        assert(active_incarnation == $past(authority_load_incarnation));
        assert(active_queue_epoch == $past(authority_load_queue_epoch));
        assert(active_slot_id == $past(authority_load_slot_id));
        assert(active_command_id == $past(authority_load_command_id));
        assert(active_attempt_id == $past(authority_load_attempt_id));
        assert(active_effect_id == $past(authority_load_effect_id));
        assert(!attempt_spent);
      end

      if ($past(authority_revoke_accept)) begin
        assert(!active_valid);
        assert(!active_committed);
        assert(!attempt_spent);
      end

      if ($past(command_forward)) begin
        assert(attempt_spent);
        if ($past(command_commit))
          assert(effect_count == $past(effect_count) + {{(COUNT_WIDTH-1){1'b0}}, 1'b1});
        else
          assert(effect_count == $past(effect_count));
      end

      if ($past(command_valid && command_rejected)) begin
        assert(effect_count == $past(effect_count));
        assert($stable(active_valid));
        assert($stable(active_committed));
        assert($stable(active_authority_tag));
        assert($stable(active_incarnation));
        assert($stable(active_queue_epoch));
        assert($stable(active_slot_id));
        assert($stable(active_command_id));
        assert($stable(active_attempt_id));
        assert($stable(active_effect_id));
        assert($stable(attempt_spent));
      end
    end

    cover(authority_load_accept && authority_load_committed);
    cover(authority_load_accept && !authority_load_committed);
    cover(command_forward && command_commit);
    cover(command_forward && !command_commit);
    cover(command_valid && command_rejected && command_reject_code == REJECT_IDENTITY);
    cover(command_valid && command_rejected && command_reject_code == REJECT_ALREADY_ISSUED);
    cover(authority_revoke_accept);
  end
endmodule
