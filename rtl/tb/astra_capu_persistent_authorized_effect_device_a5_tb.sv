`timescale 1ns/1ps

module astra_capu_persistent_authorized_effect_device_a5_tb;
  localparam integer TAG_WIDTH = 8;
  localparam integer ID_WIDTH = 4;
  localparam integer COUNT_WIDTH = 16;

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

  logic provision_accept;
  logic provision_rejected;
  logic persist_advance_valid;
  logic persist_advance_accept;
  logic persist_advance_rejected;
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

  astra_capu_persistent_authorized_effect_device_a5 #(
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
    end
  endtask

  task automatic set_lineage;
    begin
      provision_tag = 8'hA5;
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
        $fatal(1, "A5 provision failed");
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
        $fatal(1, "A5 authority load failed");
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
  logic [3:0] reject_seen;

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

    repeat (2) @(posedge clk);
    @(negedge clk);
    cold_rst_n = 1'b1;
    logic_rst_n = 1'b1;
    @(posedge clk); #1;

    pulse_provision(4'd0);
    $display("a5_frontier_provisioned next_attempt=%0d", persistent_next_attempt);

    pulse_load(4'd0, 1'b1);
    pulse_command(4'd0, 1'b1, forward_seen, reject_seen);
    if (!forward_seen || effect_count != 16'd1 || persistent_next_attempt != 4'd1)
      $fatal(1, "A5 attempt 0 did not commit-before-effect");
    $display("a5_attempt0_forwarded forward=%0d effect_count=%0d persistent_next_attempt=%0d",
             forward_seen, effect_count, persistent_next_attempt);

    pulse_logic_reset();
    if (active_valid || persistent_next_attempt != 4'd1 || effect_count != 16'd1)
      $fatal(1, "A5 logic reset did not preserve external state");
    $display("a5_logic_restart active_valid=%0d effect_count=%0d persistent_next_attempt=%0d",
             active_valid, effect_count, persistent_next_attempt);

    pulse_load(4'd0, 1'b1);
    pulse_command(4'd0, 1'b1, forward_seen, reject_seen);
    if (forward_seen || reject_seen != 4'd8 || effect_count != 16'd1)
      $fatal(1, "A5 stale attempt replay was not blocked");
    $display("a5_same_attempt_after_restart_blocked reject_code=%0d effect_count=%0d",
             reject_seen, effect_count);

    pulse_logic_reset();
    pulse_load(4'd1, 1'b1);
    pulse_command(4'd1, 1'b1, forward_seen, reject_seen);
    if (!forward_seen || effect_count != 16'd2 || persistent_next_attempt != 4'd2)
      $fatal(1, "A5 successor attempt failed");
    $display("a5_successor_attempt_forwarded attempt=1 effect_count=%0d persistent_next_attempt=%0d",
             effect_count, persistent_next_attempt);

    pulse_logic_reset();
    pulse_load(4'd3, 1'b1);
    pulse_command(4'd3, 1'b1, forward_seen, reject_seen);
    if (forward_seen || reject_seen != 4'd8 || effect_count != 16'd2)
      $fatal(1, "A5 future attempt was not blocked");
    $display("a5_future_attempt_blocked attempt=3 frontier=%0d reject_code=%0d",
             persistent_next_attempt, reject_seen);

    $display("a5_summary external_effect_count=%0d persistent_next_attempt=%0d restart_replay_blocked=1 successor_forwarded=1",
             effect_count, persistent_next_attempt);
    $display("ASTRA_CAPU_V1_A5_PERSISTENT_ANTI_REPLAY_PASS");
    $finish;
  end
endmodule
