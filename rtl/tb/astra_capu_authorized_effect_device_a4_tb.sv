`timescale 1ns/1ps

module astra_capu_authorized_effect_device_a4_tb;
  localparam logic [2:0] REJECT_NO_AUTHORITY   = 3'd1;
  localparam logic [2:0] REJECT_UNCOMMITTED    = 3'd2;
  localparam logic [2:0] REJECT_IDENTITY       = 3'd3;
  localparam logic [2:0] REJECT_ALREADY_ISSUED = 3'd4;

  logic clk = 1'b0;
  logic rst_n;

  logic device_state_load_valid;
  logic [15:0] device_state_load_count;

  logic authority_load_valid;
  logic authority_load_committed;
  logic [7:0] authority_load_tag;
  logic [3:0] authority_load_incarnation;
  logic [3:0] authority_load_queue_epoch;
  logic [3:0] authority_load_slot_id;
  logic [3:0] authority_load_command_id;
  logic [3:0] authority_load_attempt_id;
  logic [3:0] authority_load_effect_id;

  logic authority_revoke_valid;
  logic [7:0] authority_revoke_tag;
  logic [3:0] authority_revoke_incarnation;
  logic [3:0] authority_revoke_queue_epoch;
  logic [3:0] authority_revoke_slot_id;
  logic [3:0] authority_revoke_command_id;
  logic [3:0] authority_revoke_attempt_id;
  logic [3:0] authority_revoke_effect_id;

  logic command_valid;
  logic command_commit;
  logic [7:0] command_authority_tag;
  logic [3:0] command_incarnation;
  logic [3:0] command_queue_epoch;
  logic [3:0] command_slot_id;
  logic [3:0] command_id;
  logic [3:0] command_attempt_id;
  logic [3:0] command_effect_id;

  logic authority_load_accept;
  logic authority_load_rejected;
  logic authority_revoke_accept;
  logic authority_revoke_rejected;
  logic command_forward;
  logic command_rejected;
  logic [2:0] command_reject_code;
  logic device_command_accept;
  logic device_completion_valid;
  logic [15:0] effect_count;
  logic active_valid;
  logic active_committed;
  logic attempt_spent;
  logic [7:0] active_authority_tag;
  logic [3:0] active_incarnation;
  logic [3:0] active_queue_epoch;
  logic [3:0] active_slot_id;
  logic [3:0] active_command_id;
  logic [3:0] active_attempt_id;
  logic [3:0] active_effect_id;

  always #5 clk = ~clk;

  astra_capu_authorized_effect_device_a4 dut (.*);

  task automatic load_authority(
    input logic committed,
    input logic [7:0] tag,
    input logic [3:0] incarnation,
    input logic [3:0] queue_epoch,
    input logic [3:0] slot_id,
    input logic [3:0] command_id_value,
    input logic [3:0] attempt_id,
    input logic [3:0] effect_id
  );
    begin
      @(negedge clk);
      authority_load_committed = committed;
      authority_load_tag = tag;
      authority_load_incarnation = incarnation;
      authority_load_queue_epoch = queue_epoch;
      authority_load_slot_id = slot_id;
      authority_load_command_id = command_id_value;
      authority_load_attempt_id = attempt_id;
      authority_load_effect_id = effect_id;
      authority_load_valid = 1'b1;
      #1;
      if (!authority_load_accept || authority_load_rejected)
        $fatal(1, "A4 load authority unexpectedly rejected");
      @(posedge clk);
      #1;
      authority_load_valid = 1'b0;
      if (!active_valid || active_committed != committed)
        $fatal(1, "A4 authority state did not load");
    end
  endtask

  task automatic revoke_authority(
    input logic [7:0] tag,
    input logic [3:0] incarnation,
    input logic [3:0] queue_epoch,
    input logic [3:0] slot_id,
    input logic [3:0] command_id_value,
    input logic [3:0] attempt_id,
    input logic [3:0] effect_id
  );
    begin
      @(negedge clk);
      authority_revoke_tag = tag;
      authority_revoke_incarnation = incarnation;
      authority_revoke_queue_epoch = queue_epoch;
      authority_revoke_slot_id = slot_id;
      authority_revoke_command_id = command_id_value;
      authority_revoke_attempt_id = attempt_id;
      authority_revoke_effect_id = effect_id;
      authority_revoke_valid = 1'b1;
      #1;
      if (!authority_revoke_accept || authority_revoke_rejected)
        $fatal(1, "A4 exact revoke unexpectedly rejected");
      @(posedge clk);
      #1;
      authority_revoke_valid = 1'b0;
      if (active_valid)
        $fatal(1, "A4 authority remained active after revoke");
    end
  endtask

  task automatic issue_command(
    input logic [7:0] tag,
    input logic [3:0] incarnation,
    input logic [3:0] queue_epoch,
    input logic [3:0] slot_id,
    input logic [3:0] command_id_value,
    input logic [3:0] attempt_id,
    input logic [3:0] effect_id,
    input logic commit_effect,
    input logic expect_forward,
    input logic [2:0] expected_reject_code
  );
    integer before_count;
    begin
      @(negedge clk);
      before_count = effect_count;
      command_authority_tag = tag;
      command_incarnation = incarnation;
      command_queue_epoch = queue_epoch;
      command_slot_id = slot_id;
      command_id = command_id_value;
      command_attempt_id = attempt_id;
      command_effect_id = effect_id;
      command_commit = commit_effect;
      command_valid = 1'b1;
      #1;
      if (command_forward != expect_forward)
        $fatal(1, "A4 command_forward mismatch");
      if (device_command_accept != expect_forward)
        $fatal(1, "A4 device acceptance bypassed shim");
      if (!expect_forward) begin
        if (!command_rejected || command_reject_code != expected_reject_code)
          $fatal(1, "A4 reject code mismatch");
      end else if (command_rejected) begin
        $fatal(1, "A4 exact committed command was rejected");
      end
      @(posedge clk);
      #1;
      command_valid = 1'b0;
      command_commit = 1'b0;
      if (effect_count != before_count + ((expect_forward && commit_effect) ? 1 : 0))
        $fatal(1, "A4 external effect count changed without authorized committed command");
      if (expect_forward && !attempt_spent)
        $fatal(1, "A4 forwarded attempt was not marked spent");
    end
  endtask

  initial begin
    rst_n = 1'b0;
    device_state_load_valid = 1'b0;
    device_state_load_count = '0;
    authority_load_valid = 1'b0;
    authority_load_committed = 1'b0;
    authority_load_tag = '0;
    authority_load_incarnation = '0;
    authority_load_queue_epoch = '0;
    authority_load_slot_id = '0;
    authority_load_command_id = '0;
    authority_load_attempt_id = '0;
    authority_load_effect_id = '0;
    authority_revoke_valid = 1'b0;
    authority_revoke_tag = '0;
    authority_revoke_incarnation = '0;
    authority_revoke_queue_epoch = '0;
    authority_revoke_slot_id = '0;
    authority_revoke_command_id = '0;
    authority_revoke_attempt_id = '0;
    authority_revoke_effect_id = '0;
    command_valid = 1'b0;
    command_commit = 1'b0;
    command_authority_tag = '0;
    command_incarnation = '0;
    command_queue_epoch = '0;
    command_slot_id = '0;
    command_id = '0;
    command_attempt_id = '0;
    command_effect_id = '0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    load_authority(1'b1, 8'hA1, 4'd2, 4'd7, 4'd1, 4'd2, 4'd0, 4'd4);
    $display("a4_authority_loaded committed=1 tag=A1 incarnation=2 epoch=7 attempt=0");

    issue_command(8'hA1, 4'd2, 4'd7, 4'd1, 4'd2, 4'd0, 4'd4, 1'b1, 1'b1, 3'd0);
    $display("a4_exact_forward forward=1 device_accept=1 effect_count=%0d", effect_count);

    issue_command(8'hA1, 4'd2, 4'd7, 4'd1, 4'd2, 4'd0, 4'd4, 1'b1, 1'b0, REJECT_ALREADY_ISSUED);
    $display("a4_duplicate_blocked reject_code=%0d effect_count=%0d", REJECT_ALREADY_ISSUED, effect_count);

    revoke_authority(8'hA1, 4'd2, 4'd7, 4'd1, 4'd2, 4'd0, 4'd4);
    load_authority(1'b0, 8'hB2, 4'd3, 4'd0, 4'd1, 4'd2, 4'd0, 4'd4);
    issue_command(8'hB2, 4'd3, 4'd0, 4'd1, 4'd2, 4'd0, 4'd4, 1'b1, 1'b0, REJECT_UNCOMMITTED);
    $display("a4_uncommitted_blocked reject_code=%0d effect_count=%0d", REJECT_UNCOMMITTED, effect_count);

    revoke_authority(8'hB2, 4'd3, 4'd0, 4'd1, 4'd2, 4'd0, 4'd4);
    load_authority(1'b1, 8'hC3, 4'd4, 4'd1, 4'd1, 4'd2, 4'd0, 4'd4);
    issue_command(8'hC3, 4'd3, 4'd1, 4'd1, 4'd2, 4'd0, 4'd4, 1'b1, 1'b0, REJECT_IDENTITY);
    $display("a4_stale_identity_blocked reject_code=%0d active_incarnation=%0d", REJECT_IDENTITY, active_incarnation);

    issue_command(8'hC3, 4'd4, 4'd1, 4'd1, 4'd2, 4'd0, 4'd4, 1'b0, 1'b1, 3'd0);
    $display("a4_unknown_dispatch forward=1 external_commit=0 attempt_spent=1 effect_count=%0d", effect_count);

    issue_command(8'hC3, 4'd4, 4'd1, 4'd1, 4'd2, 4'd0, 4'd4, 1'b1, 1'b0, REJECT_ALREADY_ISSUED);
    $display("a4_same_attempt_replay_blocked reject_code=%0d effect_count=%0d", REJECT_ALREADY_ISSUED, effect_count);

    revoke_authority(8'hC3, 4'd4, 4'd1, 4'd1, 4'd2, 4'd0, 4'd4);
    load_authority(1'b1, 8'hD4, 4'd4, 4'd1, 4'd1, 4'd2, 4'd1, 4'd4);
    issue_command(8'hD4, 4'd4, 4'd1, 4'd1, 4'd2, 4'd1, 4'd4, 1'b1, 1'b1, 3'd0);
    $display("a4_successor_attempt_forwarded attempt=1 effect_count=%0d", effect_count);

    revoke_authority(8'hD4, 4'd4, 4'd1, 4'd1, 4'd2, 4'd1, 4'd4);
    issue_command(8'hD4, 4'd4, 4'd1, 4'd1, 4'd2, 4'd1, 4'd4, 1'b1, 1'b0, REJECT_NO_AUTHORITY);
    $display("a4_revoked_authority_blocked reject_code=%0d effect_count=%0d", REJECT_NO_AUTHORITY, effect_count);

    if (effect_count != 16'd2)
      $fatal(1, "A4 final effect count must include only two authorized committed commands");

    $display("a4_summary authorized_commits=2 blocked_duplicate=1 blocked_uncommitted=1 blocked_stale=1 blocked_revoked=1 final_effect_count=%0d", effect_count);
    $display("ASTRA_CAPU_V1_A4_SYNTHESIZABLE_AUTHORITY_SHIM_PASS");
    $finish;
  end
endmodule
