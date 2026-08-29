`timescale 1ns/1ps

module astra_capu_reconciled_effect_device_a6_tb;
  localparam integer TAG_WIDTH = 8;
  localparam integer ID_WIDTH = 4;
  localparam integer COUNT_WIDTH = 16;

  localparam logic [2:0] OUTCOME_UNKNOWN       = 3'd1;
  localparam logic [2:0] OUTCOME_NOT_COMMITTED = 3'd2;
  localparam logic [2:0] OUTCOME_COMMITTED     = 3'd3;

  logic clk;
  logic cold_rst_n;
  logic logic_rst_n;

  logic device_state_load_valid;
  logic [COUNT_WIDTH-1:0] device_state_load_count;

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

  logic reconcile_valid;
  logic [TAG_WIDTH-1:0] reconcile_tag;
  logic [ID_WIDTH-1:0] reconcile_incarnation;
  logic [ID_WIDTH-1:0] reconcile_queue_epoch;
  logic [ID_WIDTH-1:0] reconcile_slot_id;
  logic [ID_WIDTH-1:0] reconcile_command_id;
  logic [ID_WIDTH-1:0] reconcile_attempt_id;
  logic [ID_WIDTH-1:0] reconcile_effect_id;
  logic [2:0] reconcile_outcome;

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

  always #5 clk = ~clk;

  task automatic clear_controls;
    begin
      device_state_load_valid = 1'b0;
      device_state_load_count = '0;
      provision_valid = 1'b0;
      authority_load_valid = 1'b0;
      authority_revoke_valid = 1'b0;
      command_valid = 1'b0;
      command_commit = 1'b0;
      reconcile_valid = 1'b0;
      reconcile_outcome = '0;
    end
  endtask

  task automatic set_lineage;
    begin
      provision_tag = 8'hA6;
      provision_incarnation = 4'h2;
      provision_queue_epoch = 4'h7;
      provision_slot_id = 4'h1;
      provision_command_id = 4'h9;
      provision_effect_id = 4'hC;

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

      reconcile_tag = provision_tag;
      reconcile_incarnation = provision_incarnation;
      reconcile_queue_epoch = provision_queue_epoch;
      reconcile_slot_id = provision_slot_id;
      reconcile_command_id = provision_command_id;
      reconcile_effect_id = provision_effect_id;

      authority_revoke_tag = provision_tag;
      authority_revoke_incarnation = provision_incarnation;
      authority_revoke_queue_epoch = provision_queue_epoch;
      authority_revoke_slot_id = provision_slot_id;
      authority_revoke_command_id = provision_command_id;
      authority_revoke_effect_id = provision_effect_id;
    end
  endtask

  task automatic pulse_provision(input logic [ID_WIDTH-1:0] next_attempt);
    logic accept_seen;
    begin
      @(negedge clk);
      provision_next_attempt = next_attempt;
      provision_valid = 1'b1;
      #1 accept_seen = provision_accept;
      @(posedge clk); #1;
      provision_valid = 1'b0;
      if (!accept_seen || !persistent_valid || persistent_next_attempt != next_attempt)
        $fatal(1, "A6 provision failed");
    end
  endtask

  task automatic pulse_load(
    input logic [ID_WIDTH-1:0] attempt,
    input logic committed
  );
    logic accept_seen;
    begin
      @(negedge clk);
      authority_load_attempt_id = attempt;
      authority_load_committed = committed;
      authority_load_valid = 1'b1;
      #1 accept_seen = authority_load_accept;
      @(posedge clk); #1;
      authority_load_valid = 1'b0;
      if (!accept_seen || !active_valid || active_attempt_id != attempt)
        $fatal(1, "A6 authority load failed");
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

  task automatic pulse_reconcile(
    input logic [ID_WIDTH-1:0] attempt,
    input logic [2:0] outcome,
    output logic accept_seen,
    output logic [2:0] reject_seen
  );
    begin
      @(negedge clk);
      reconcile_attempt_id = attempt;
      reconcile_outcome = outcome;
      reconcile_valid = 1'b1;
      #1;
      accept_seen = reconcile_accept;
      reject_seen = reconcile_reject_code;
      @(posedge clk); #1;
      reconcile_valid = 1'b0;
      reconcile_outcome = '0;
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
  logic reconcile_accept_seen;
  logic [2:0] reconcile_reject_seen;

  initial begin
    clk = 1'b0;
    cold_rst_n = 1'b0;
    logic_rst_n = 1'b0;
    clear_controls();
    set_lineage();
    provision_next_attempt = '0;
    authority_load_attempt_id = '0;
    authority_load_committed = 1'b0;
    authority_revoke_attempt_id = '0;
    command_attempt_id = '0;
    reconcile_attempt_id = '0;

    repeat (2) @(posedge clk);
    @(negedge clk);
    cold_rst_n = 1'b1;
    logic_rst_n = 1'b1;
    @(posedge clk); #1;

    pulse_provision(4'd0);
    $display("a6_frontier_provisioned next_attempt=%0d", persistent_next_attempt);

    pulse_load(4'd0, 1'b1);
    pulse_command(4'd0, 1'b0, forward_seen, command_reject_seen);
    if (!forward_seen || effect_count != 16'd0 ||
        !unresolved_valid || unresolved_attempt != 4'd0 ||
        last_outcome != OUTCOME_UNKNOWN || persistent_next_attempt != 4'd1)
      $fatal(1, "A6 attempt 0 did not enter UNKNOWN");
    $display("a6_attempt0_forwarded effect_count=%0d outcome=UNKNOWN next_attempt=%0d",
             effect_count, persistent_next_attempt);

    pulse_logic_reset();
    if (active_valid || !unresolved_valid || unresolved_attempt != 4'd0 ||
        persistent_next_attempt != 4'd1 || effect_count != 16'd0)
      $fatal(1, "A6 logic reset did not preserve UNKNOWN state");
    $display("a6_logic_restart_unknown_preserved unresolved_attempt=%0d next_attempt=%0d",
             unresolved_attempt, persistent_next_attempt);

    pulse_load(4'd0, 1'b1);
    pulse_command(4'd0, 1'b1, forward_seen, command_reject_seen);
    if (forward_seen || command_reject_seen != 4'd10 || effect_count != 16'd0)
      $fatal(1, "A6 stale UNKNOWN attempt replay was not blocked");
    $display("a6_same_attempt_after_restart_blocked reject_code=%0d effect_count=%0d",
             command_reject_seen, effect_count);

    pulse_reconcile(4'd0, OUTCOME_NOT_COMMITTED,
                    reconcile_accept_seen, reconcile_reject_seen);
    if (!reconcile_accept_seen || unresolved_valid ||
        last_outcome != OUTCOME_NOT_COMMITTED || terminal_committed || terminal_conflict)
      $fatal(1, "A6 NOT_COMMITTED reconciliation failed");
    $display("a6_negative_reconcile_accepted attempt=0 outcome=NOT_COMMITTED");

    pulse_logic_reset();
    pulse_load(4'd1, 1'b1);
    pulse_command(4'd1, 1'b1, forward_seen, command_reject_seen);
    if (!forward_seen || effect_count != 16'd1 ||
        !unresolved_valid || unresolved_attempt != 4'd1 ||
        last_outcome != OUTCOME_UNKNOWN || persistent_next_attempt != 4'd2)
      $fatal(1, "A6 successor attempt did not enter UNKNOWN");
    $display("a6_attempt1_forwarded effect_count=%0d outcome=UNKNOWN next_attempt=%0d",
             effect_count, persistent_next_attempt);

    pulse_logic_reset();
    pulse_load(4'd2, 1'b1);
    pulse_command(4'd2, 1'b1, forward_seen, command_reject_seen);
    if (forward_seen || command_reject_seen != 4'd10 || effect_count != 16'd1)
      $fatal(1, "A6 successor was not blocked while prior outcome UNKNOWN");
    $display("a6_successor_blocked_while_unknown reject_code=%0d effect_count=%0d",
             command_reject_seen, effect_count);

    pulse_reconcile(4'd0, OUTCOME_COMMITTED,
                    reconcile_accept_seen, reconcile_reject_seen);
    if (reconcile_accept_seen || reconcile_reject_seen != 3'd4 ||
        !unresolved_valid || terminal_committed)
      $fatal(1, "A6 stale reconciliation was not rejected");
    $display("a6_stale_reconcile_blocked reject_code=%0d", reconcile_reject_seen);

    pulse_reconcile(4'd1, OUTCOME_COMMITTED,
                    reconcile_accept_seen, reconcile_reject_seen);
    if (!reconcile_accept_seen || unresolved_valid ||
        !terminal_committed || terminal_conflict ||
        last_outcome != OUTCOME_COMMITTED)
      $fatal(1, "A6 COMMITTED reconciliation failed");
    $display("a6_committed_reconcile_accepted attempt=1 terminal_committed=%0d",
             terminal_committed);

    pulse_logic_reset();
    pulse_load(4'd2, 1'b1);
    pulse_command(4'd2, 1'b1, forward_seen, command_reject_seen);
    if (forward_seen || command_reject_seen != 4'd11 || effect_count != 16'd1)
      $fatal(1, "A6 terminal committed lineage accepted replay");
    $display("a6_terminal_replay_blocked reject_code=%0d effect_count=%0d",
             command_reject_seen, effect_count);

    $display("a6_summary external_effect_count=%0d persistent_next_attempt=%0d last_outcome=COMMITTED terminal_committed=1",
             effect_count, persistent_next_attempt);
    $display("ASTRA_CAPU_V1_A6_OUTCOME_RECONCILIATION_PASS");
    $finish;
  end
endmodule
