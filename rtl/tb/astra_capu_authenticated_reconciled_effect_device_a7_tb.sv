`timescale 1ns/1ps

module astra_capu_authenticated_reconciled_effect_device_a7_tb;
  localparam integer DEVICE_WIDTH = 8;
  localparam integer TAG_WIDTH = 8;
  localparam integer ID_WIDTH = 4;
  localparam integer AUTH_WIDTH = 16;
  localparam integer COUNT_WIDTH = 16;

  localparam logic [2:0] OUTCOME_NOT_COMMITTED = 3'd2;
  localparam logic [2:0] OUTCOME_COMMITTED     = 3'd3;

  logic clk;
  logic cold_rst_n;
  logic logic_rst_n;

  logic device_state_load_valid;
  logic [COUNT_WIDTH-1:0] device_state_load_count;

  logic trust_provision_valid;
  logic [DEVICE_WIDTH-1:0] trust_provision_device_id;
  logic [ID_WIDTH-1:0] trust_provision_key_epoch;
  logic [AUTH_WIDTH-1:0] trust_provision_secret;
  logic [ID_WIDTH-1:0] trust_provision_next_receipt_seq;

  logic provision_valid;
  logic [TAG_WIDTH-1:0] provision_tag;
  logic [ID_WIDTH-1:0] provision_incarnation;
  logic [ID_WIDTH-1:0] provision_queue_epoch;
  logic [ID_WIDTH-1:0] provision_slot_id;
  logic [ID_WIDTH-1:0] provision_command_id;
  logic [ID_WIDTH-1:0] provision_effect_id;
  logic [ID_WIDTH-1:0] provision_next_attempt;

  logic authority_load_valid;
  logic authority_load_committed;
  logic [TAG_WIDTH-1:0] authority_load_tag;
  logic [ID_WIDTH-1:0] authority_load_incarnation;
  logic [ID_WIDTH-1:0] authority_load_queue_epoch;
  logic [ID_WIDTH-1:0] authority_load_slot_id;
  logic [ID_WIDTH-1:0] authority_load_command_id;
  logic [ID_WIDTH-1:0] authority_load_attempt_id;
  logic [ID_WIDTH-1:0] authority_load_effect_id;

  logic authority_revoke_valid;
  logic [TAG_WIDTH-1:0] authority_revoke_tag;
  logic [ID_WIDTH-1:0] authority_revoke_incarnation;
  logic [ID_WIDTH-1:0] authority_revoke_queue_epoch;
  logic [ID_WIDTH-1:0] authority_revoke_slot_id;
  logic [ID_WIDTH-1:0] authority_revoke_command_id;
  logic [ID_WIDTH-1:0] authority_revoke_attempt_id;
  logic [ID_WIDTH-1:0] authority_revoke_effect_id;

  logic command_valid;
  logic command_commit;
  logic [TAG_WIDTH-1:0] command_authority_tag;
  logic [ID_WIDTH-1:0] command_incarnation;
  logic [ID_WIDTH-1:0] command_queue_epoch;
  logic [ID_WIDTH-1:0] command_slot_id;
  logic [ID_WIDTH-1:0] command_id;
  logic [ID_WIDTH-1:0] command_attempt_id;
  logic [ID_WIDTH-1:0] command_effect_id;

  logic receipt_valid;
  logic [DEVICE_WIDTH-1:0] receipt_device_id;
  logic [ID_WIDTH-1:0] receipt_key_epoch;
  logic [ID_WIDTH-1:0] receipt_seq;
  logic [TAG_WIDTH-1:0] receipt_authority_tag;
  logic [ID_WIDTH-1:0] receipt_incarnation;
  logic [ID_WIDTH-1:0] receipt_queue_epoch;
  logic [ID_WIDTH-1:0] receipt_slot_id;
  logic [ID_WIDTH-1:0] receipt_command_id;
  logic [ID_WIDTH-1:0] receipt_attempt_id;
  logic [ID_WIDTH-1:0] receipt_effect_id;
  logic [2:0] receipt_outcome;
  logic [AUTH_WIDTH-1:0] receipt_auth_tag;

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

  always #5 clk = ~clk;

  function automatic [AUTH_WIDTH-1:0] rotl1(
    input [AUTH_WIDTH-1:0] value
  );
    begin
      rotl1 = {value[AUTH_WIDTH-2:0], value[AUTH_WIDTH-1]};
    end
  endfunction

  function automatic [AUTH_WIDTH-1:0] receipt_tag_fn(
    input [DEVICE_WIDTH-1:0] device_id_i,
    input [ID_WIDTH-1:0] key_epoch_i,
    input [ID_WIDTH-1:0] seq_i,
    input [TAG_WIDTH-1:0] authority_tag_i,
    input [ID_WIDTH-1:0] incarnation_i,
    input [ID_WIDTH-1:0] queue_epoch_i,
    input [ID_WIDTH-1:0] slot_id_i,
    input [ID_WIDTH-1:0] command_id_i,
    input [ID_WIDTH-1:0] attempt_id_i,
    input [ID_WIDTH-1:0] effect_id_i,
    input [2:0] outcome_i
  );
    logic [AUTH_WIDTH-1:0] acc;
    begin
      acc = 16'hBEEF;
      acc = rotl1(acc) ^ device_id_i;
      acc = rotl1(acc) ^ key_epoch_i;
      acc = rotl1(acc) ^ seq_i;
      acc = rotl1(acc) ^ authority_tag_i;
      acc = rotl1(acc) ^ incarnation_i;
      acc = rotl1(acc) ^ queue_epoch_i;
      acc = rotl1(acc) ^ slot_id_i;
      acc = rotl1(acc) ^ command_id_i;
      acc = rotl1(acc) ^ attempt_id_i;
      acc = rotl1(acc) ^ effect_id_i;
      acc = rotl1(acc) ^ outcome_i;
      receipt_tag_fn = acc;
    end
  endfunction

  task automatic clear_controls;
    begin
      device_state_load_valid = 1'b0;
      device_state_load_count = '0;
      trust_provision_valid = 1'b0;
      provision_valid = 1'b0;
      authority_load_valid = 1'b0;
      authority_revoke_valid = 1'b0;
      command_valid = 1'b0;
      command_commit = 1'b0;
      receipt_valid = 1'b0;
      receipt_auth_tag = '0;
    end
  endtask

  task automatic set_lineage;
    begin
      trust_provision_device_id = 8'h3C;
      trust_provision_key_epoch = 4'd2;
      trust_provision_secret = 16'hBEEF;
      trust_provision_next_receipt_seq = 4'd0;

      provision_tag = 8'hA7;
      provision_incarnation = 4'd2;
      provision_queue_epoch = 4'd7;
      provision_slot_id = 4'd1;
      provision_command_id = 4'd9;
      provision_effect_id = 4'd12;
      provision_next_attempt = 4'd0;

      authority_load_tag = provision_tag;
      authority_load_incarnation = provision_incarnation;
      authority_load_queue_epoch = provision_queue_epoch;
      authority_load_slot_id = provision_slot_id;
      authority_load_command_id = provision_command_id;
      authority_load_effect_id = provision_effect_id;

      command_authority_tag = provision_tag;
      command_incarnation = provision_incarnation;
      command_queue_epoch = provision_queue_epoch;
      command_slot_id = provision_slot_id;
      command_id = provision_command_id;
      command_effect_id = provision_effect_id;

      receipt_device_id = trust_provision_device_id;
      receipt_key_epoch = trust_provision_key_epoch;
      receipt_authority_tag = provision_tag;
      receipt_incarnation = provision_incarnation;
      receipt_queue_epoch = provision_queue_epoch;
      receipt_slot_id = provision_slot_id;
      receipt_command_id = provision_command_id;
      receipt_effect_id = provision_effect_id;

      authority_revoke_tag = provision_tag;
      authority_revoke_incarnation = provision_incarnation;
      authority_revoke_queue_epoch = provision_queue_epoch;
      authority_revoke_slot_id = provision_slot_id;
      authority_revoke_command_id = provision_command_id;
      authority_revoke_effect_id = provision_effect_id;
    end
  endtask

  task automatic pulse_trust_provision;
    logic accept_seen;
    begin
      @(negedge clk);
      trust_provision_valid = 1'b1;
      #1 accept_seen = trust_provision_accept;
      @(posedge clk); #1;
      trust_provision_valid = 1'b0;
      if (!accept_seen || !trusted_valid ||
          trusted_device_id != 8'h3C ||
          trusted_key_epoch != 4'd2 ||
          trusted_next_receipt_seq != 4'd0)
        $fatal(1, "A7 trust provision failed");
    end
  endtask

  task automatic pulse_provision;
    logic accept_seen;
    begin
      @(negedge clk);
      provision_valid = 1'b1;
      #1 accept_seen = provision_accept;
      @(posedge clk); #1;
      provision_valid = 1'b0;
      if (!accept_seen || !persistent_valid || persistent_next_attempt != 4'd0)
        $fatal(1, "A7 outcome-store provision failed");
    end
  endtask

  task automatic pulse_load(
    input logic [ID_WIDTH-1:0] attempt
  );
    logic accept_seen;
    begin
      @(negedge clk);
      authority_load_attempt_id = attempt;
      authority_load_committed = 1'b1;
      authority_load_valid = 1'b1;
      #1 accept_seen = authority_load_accept;
      @(posedge clk); #1;
      authority_load_valid = 1'b0;
      if (!accept_seen || !active_valid || active_attempt_id != attempt)
        $fatal(1, "A7 authority load failed");
    end
  endtask

  task automatic pulse_command(
    input logic [ID_WIDTH-1:0] attempt,
    input logic commit_effect,
    output logic forward_seen,
    output logic [3:0] reject_seen
  );
    begin
      @(negedge clk);
      command_attempt_id = attempt;
      command_commit = commit_effect;
      command_valid = 1'b1;
      #1;
      forward_seen = command_forward;
      reject_seen = command_reject_code;
      @(posedge clk); #1;
      command_valid = 1'b0;
      command_commit = 1'b0;
    end
  endtask

  task automatic pulse_receipt(
    input logic [DEVICE_WIDTH-1:0] device_id_i,
    input logic [ID_WIDTH-1:0] key_epoch_i,
    input logic [ID_WIDTH-1:0] seq_i,
    input logic [ID_WIDTH-1:0] attempt_i,
    input logic [2:0] outcome_i,
    input logic forge_tag,
    output logic auth_seen,
    output logic [2:0] auth_reject_seen,
    output logic reconcile_seen,
    output logic [2:0] reconcile_reject_seen
  );
    logic [AUTH_WIDTH-1:0] exact_tag;
    begin
      @(negedge clk);
      receipt_device_id = device_id_i;
      receipt_key_epoch = key_epoch_i;
      receipt_seq = seq_i;
      receipt_attempt_id = attempt_i;
      receipt_outcome = outcome_i;
      exact_tag = receipt_tag_fn(
        device_id_i,
        key_epoch_i,
        seq_i,
        receipt_authority_tag,
        receipt_incarnation,
        receipt_queue_epoch,
        receipt_slot_id,
        receipt_command_id,
        attempt_i,
        receipt_effect_id,
        outcome_i
      );
      receipt_auth_tag = forge_tag ? (exact_tag ^ 16'd1) : exact_tag;
      receipt_valid = 1'b1;
      #1;
      auth_seen = receipt_auth_accept;
      auth_reject_seen = receipt_auth_reject_code;
      reconcile_seen = receipt_reconcile_accept;
      reconcile_reject_seen = receipt_reconcile_reject_code;
      @(posedge clk); #1;
      receipt_valid = 1'b0;
      receipt_auth_tag = '0;
    end
  endtask

  task automatic pulse_logic_reset;
    begin
      @(negedge clk);
      logic_rst_n = 1'b0;
      @(posedge clk); #1;
      @(negedge clk);
      logic_rst_n = 1'b1;
      @(posedge clk); #1;
    end
  endtask

  logic forward_seen;
  logic [3:0] command_reject_seen;
  logic auth_seen;
  logic [2:0] auth_reject_seen;
  logic reconcile_seen;
  logic [2:0] reconcile_reject_seen;

  initial begin
    clk = 1'b0;
    cold_rst_n = 1'b0;
    logic_rst_n = 1'b0;
    clear_controls();
    set_lineage();
    authority_load_attempt_id = '0;
    authority_load_committed = 1'b0;
    authority_revoke_attempt_id = '0;
    command_attempt_id = '0;
    receipt_seq = '0;
    receipt_attempt_id = '0;
    receipt_outcome = '0;

    repeat (2) @(posedge clk);
    @(negedge clk);
    cold_rst_n = 1'b1;
    logic_rst_n = 1'b1;
    @(posedge clk); #1;

    pulse_trust_provision();
    pulse_provision();

    pulse_load(4'd0);
    pulse_command(4'd0, 1'b0, forward_seen, command_reject_seen);
    if (!forward_seen || effect_count != 16'd0 ||
        !unresolved_valid || last_outcome != 3'd1)
      $fatal(1, "A7 attempt 0 did not enter UNKNOWN");
    $display("a7_attempt0_forwarded outcome=UNKNOWN effect_count=%0d", effect_count);

    pulse_receipt(8'h3C, 4'd2, 4'd0, 4'd0,
                  OUTCOME_NOT_COMMITTED, 1'b1,
                  auth_seen, auth_reject_seen,
                  reconcile_seen, reconcile_reject_seen);
    if (auth_seen || auth_reject_seen != 3'd5 ||
        trusted_next_receipt_seq != 4'd0 || !unresolved_valid)
      $fatal(1, "A7 forged receipt was not rejected");
    $display("a7_forged_receipt_blocked reject_code=%0d next_receipt_seq=%0d",
             auth_reject_seen, trusted_next_receipt_seq);

    pulse_receipt(8'h3C, 4'd2, 4'd0, 4'd0,
                  OUTCOME_NOT_COMMITTED, 1'b0,
                  auth_seen, auth_reject_seen,
                  reconcile_seen, reconcile_reject_seen);
    if (!auth_seen || !reconcile_seen ||
        trusted_next_receipt_seq != 4'd1 || unresolved_valid ||
        last_outcome != OUTCOME_NOT_COMMITTED)
      $fatal(1, "A7 exact negative receipt failed");
    $display("a7_negative_receipt_authenticated seq=0 outcome=NOT_COMMITTED next_receipt_seq=%0d",
             trusted_next_receipt_seq);

    pulse_logic_reset();
    pulse_load(4'd1);
    pulse_command(4'd1, 1'b1, forward_seen, command_reject_seen);
    if (!forward_seen || effect_count != 16'd1 ||
        !unresolved_valid || unresolved_attempt != 4'd1)
      $fatal(1, "A7 successor attempt failed");
    $display("a7_attempt1_forwarded outcome=UNKNOWN effect_count=%0d", effect_count);

    pulse_logic_reset();
    pulse_receipt(8'h3C, 4'd2, 4'd0, 4'd0,
                  OUTCOME_NOT_COMMITTED, 1'b0,
                  auth_seen, auth_reject_seen,
                  reconcile_seen, reconcile_reject_seen);
    if (auth_seen || auth_reject_seen != 3'd4 ||
        trusted_next_receipt_seq != 4'd1 || !unresolved_valid)
      $fatal(1, "A7 stale receipt sequence was not rejected");
    $display("a7_stale_receipt_replay_blocked reject_code=%0d next_receipt_seq=%0d",
             auth_reject_seen, trusted_next_receipt_seq);

    pulse_receipt(8'h3D, 4'd2, 4'd1, 4'd1,
                  OUTCOME_COMMITTED, 1'b0,
                  auth_seen, auth_reject_seen,
                  reconcile_seen, reconcile_reject_seen);
    if (auth_seen || auth_reject_seen != 3'd2 ||
        trusted_next_receipt_seq != 4'd1 || !unresolved_valid)
      $fatal(1, "A7 foreign device receipt was not rejected");
    $display("a7_foreign_device_receipt_blocked reject_code=%0d next_receipt_seq=%0d",
             auth_reject_seen, trusted_next_receipt_seq);

    pulse_receipt(8'h3C, 4'd2, 4'd1, 4'd1,
                  OUTCOME_COMMITTED, 1'b0,
                  auth_seen, auth_reject_seen,
                  reconcile_seen, reconcile_reject_seen);
    if (!auth_seen || !reconcile_seen ||
        trusted_next_receipt_seq != 4'd2 || !terminal_committed ||
        last_outcome != OUTCOME_COMMITTED)
      $fatal(1, "A7 exact committed receipt failed");
    $display("a7_committed_receipt_authenticated seq=1 terminal_committed=%0d next_receipt_seq=%0d",
             terminal_committed, trusted_next_receipt_seq);

    pulse_logic_reset();
    pulse_load(4'd2);
    pulse_command(4'd2, 1'b1, forward_seen, command_reject_seen);
    if (forward_seen || command_reject_seen != 4'd11 || effect_count != 16'd1)
      $fatal(1, "A7 terminal replay was not blocked");
    $display("a7_terminal_replay_blocked reject_code=%0d effect_count=%0d",
             command_reject_seen, effect_count);

    $display("a7_summary external_effect_count=%0d persistent_next_attempt=%0d next_receipt_seq=%0d last_outcome=COMMITTED",
             effect_count, persistent_next_attempt, trusted_next_receipt_seq);
    $display("ASTRA_CAPU_V1_A7_AUTHENTICATED_DEVICE_RECEIPT_PASS");
    $finish;
  end
endmodule
