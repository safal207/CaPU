`timescale 1ns/1ps

module astra_capu_authority_gate_a4_tb;
  localparam ID_WIDTH = 4;
  localparam SPENT_DEPTH = 2;

  logic clk = 1'b0;
  logic rst_n;
  logic recovery_begin;

  logic authority_load_valid;
  logic authority_committed;
  logic [ID_WIDTH-1:0] authority_queue_incarnation;
  logic [ID_WIDTH-1:0] authority_queue_epoch;
  logic [ID_WIDTH-1:0] authority_slot_id;
  logic [ID_WIDTH-1:0] authority_command_id;
  logic [ID_WIDTH-1:0] authority_attempt_id;
  logic [ID_WIDTH-1:0] authority_effect_id;

  logic command_valid;
  logic [ID_WIDTH-1:0] command_queue_incarnation;
  logic [ID_WIDTH-1:0] command_queue_epoch;
  logic [ID_WIDTH-1:0] command_slot_id;
  logic [ID_WIDTH-1:0] command_command_id;
  logic [ID_WIDTH-1:0] command_attempt_id;
  logic [ID_WIDTH-1:0] command_effect_id;

  logic authority_load_accept;
  logic authority_load_rejected;
  logic command_permit;
  logic command_rejected;
  logic downstream_command_valid;

  logic token_valid_o;
  logic token_committed_o;
  logic token_spent_o;
  logic [ID_WIDTH-1:0] token_queue_incarnation_o;
  logic [ID_WIDTH-1:0] token_queue_epoch_o;
  logic [ID_WIDTH-1:0] token_slot_id_o;
  logic [ID_WIDTH-1:0] token_command_id_o;
  logic [ID_WIDTH-1:0] token_attempt_id_o;
  logic [ID_WIDTH-1:0] token_effect_id_o;
  logic [SPENT_DEPTH-1:0] spent_valid_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_queue_incarnations_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_queue_epochs_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_slot_ids_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_command_ids_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_attempt_ids_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_effect_ids_o;

  logic device_command_accept;
  logic device_completion_valid;
  logic [15:0] effect_count;

  integer last_load_accept;
  integer last_load_reject;
  integer last_permit;
  integer last_reject;

  always #5 clk = ~clk;

  astra_capu_authority_gate_a4 #(
    .ID_WIDTH(ID_WIDTH),
    .SPENT_DEPTH(SPENT_DEPTH)
  ) gate (
    .clk(clk),
    .rst_n(rst_n),
    .recovery_begin(recovery_begin),
    .authority_load_valid(authority_load_valid),
    .authority_committed(authority_committed),
    .authority_queue_incarnation(authority_queue_incarnation),
    .authority_queue_epoch(authority_queue_epoch),
    .authority_slot_id(authority_slot_id),
    .authority_command_id(authority_command_id),
    .authority_attempt_id(authority_attempt_id),
    .authority_effect_id(authority_effect_id),
    .command_valid(command_valid),
    .command_queue_incarnation(command_queue_incarnation),
    .command_queue_epoch(command_queue_epoch),
    .command_slot_id(command_slot_id),
    .command_command_id(command_command_id),
    .command_attempt_id(command_attempt_id),
    .command_effect_id(command_effect_id),
    .authority_load_accept(authority_load_accept),
    .authority_load_rejected(authority_load_rejected),
    .command_permit(command_permit),
    .command_rejected(command_rejected),
    .downstream_command_valid(downstream_command_valid),
    .token_valid_o(token_valid_o),
    .token_committed_o(token_committed_o),
    .token_spent_o(token_spent_o),
    .token_queue_incarnation_o(token_queue_incarnation_o),
    .token_queue_epoch_o(token_queue_epoch_o),
    .token_slot_id_o(token_slot_id_o),
    .token_command_id_o(token_command_id_o),
    .token_attempt_id_o(token_attempt_id_o),
    .token_effect_id_o(token_effect_id_o),
    .spent_valid_o(spent_valid_o),
    .spent_queue_incarnations_o(spent_queue_incarnations_o),
    .spent_queue_epochs_o(spent_queue_epochs_o),
    .spent_slot_ids_o(spent_slot_ids_o),
    .spent_command_ids_o(spent_command_ids_o),
    .spent_attempt_ids_o(spent_attempt_ids_o),
    .spent_effect_ids_o(spent_effect_ids_o)
  );

  astra_capu_effect_counter_a3 device (
    .clk(clk),
    .rst_n(rst_n),
    .load_valid(1'b0),
    .load_effect_count(16'b0),
    .command_valid(downstream_command_valid),
    .command_commit(1'b1),
    .command_accept(device_command_accept),
    .completion_valid(device_completion_valid),
    .effect_count(effect_count)
  );

  task automatic load_token(
    input logic committed,
    input logic [ID_WIDTH-1:0] incarnation,
    input logic [ID_WIDTH-1:0] epoch,
    input logic [ID_WIDTH-1:0] slot_id,
    input logic [ID_WIDTH-1:0] command_id,
    input logic [ID_WIDTH-1:0] attempt_id,
    input logic [ID_WIDTH-1:0] effect_id
  );
    begin
      @(negedge clk);
      authority_committed = committed;
      authority_queue_incarnation = incarnation;
      authority_queue_epoch = epoch;
      authority_slot_id = slot_id;
      authority_command_id = command_id;
      authority_attempt_id = attempt_id;
      authority_effect_id = effect_id;
      authority_load_valid = 1'b1;
      #1;
      last_load_accept = authority_load_accept;
      last_load_reject = authority_load_rejected;
      @(posedge clk);
      #1;
      authority_load_valid = 1'b0;
    end
  endtask

  task automatic send_command(
    input logic during_recovery,
    input logic [ID_WIDTH-1:0] incarnation,
    input logic [ID_WIDTH-1:0] epoch,
    input logic [ID_WIDTH-1:0] slot_id,
    input logic [ID_WIDTH-1:0] command_id,
    input logic [ID_WIDTH-1:0] attempt_id,
    input logic [ID_WIDTH-1:0] effect_id
  );
    begin
      @(negedge clk);
      recovery_begin = during_recovery;
      command_queue_incarnation = incarnation;
      command_queue_epoch = epoch;
      command_slot_id = slot_id;
      command_command_id = command_id;
      command_attempt_id = attempt_id;
      command_effect_id = effect_id;
      command_valid = 1'b1;
      #1;
      last_permit = command_permit;
      last_reject = command_rejected;
      @(posedge clk);
      #1;
      command_valid = 1'b0;
      recovery_begin = 1'b0;
    end
  endtask

  initial begin
    rst_n = 1'b0;
    recovery_begin = 1'b0;
    authority_load_valid = 1'b0;
    authority_committed = 1'b0;
    authority_queue_incarnation = '0;
    authority_queue_epoch = '0;
    authority_slot_id = '0;
    authority_command_id = '0;
    authority_attempt_id = '0;
    authority_effect_id = '0;
    command_valid = 1'b0;
    command_queue_incarnation = '0;
    command_queue_epoch = '0;
    command_slot_id = '0;
    command_command_id = '0;
    command_attempt_id = '0;
    command_effect_id = '0;
    last_load_accept = 0;
    last_load_reject = 0;
    last_permit = 0;
    last_reject = 0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    send_command(1'b0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h0, 4'h5);
    if (!last_reject || effect_count != 0) $fatal(1, "missing authority was not blocked");
    $display("a4_missing_authority blocked=1 effect_count=%0d", effect_count);

    load_token(1'b0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h0, 4'h5);
    send_command(1'b0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h0, 4'h5);
    if (!last_reject || effect_count != 0) $fatal(1, "uncommitted authority was not blocked");
    $display("a4_uncommitted_authority blocked=1 effect_count=%0d", effect_count);

    load_token(1'b1, 4'h1, 4'h2, 4'h3, 4'h4, 4'h0, 4'h5);
    send_command(1'b0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h1, 4'h5);
    if (!last_reject || effect_count != 0) $fatal(1, "mismatched attempt was not blocked");
    $display("a4_identity_mismatch blocked=1 effect_count=%0d", effect_count);

    send_command(1'b0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h0, 4'h5);
    if (!last_permit || effect_count != 1) $fatal(1, "exact authority did not permit one effect");
    $display("a4_exact_authority permit=1 effect_count=%0d", effect_count);

    send_command(1'b0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h0, 4'h5);
    if (!last_reject || effect_count != 1) $fatal(1, "spent authority replay was not blocked");
    $display("a4_replay blocked=1 effect_count=%0d spent_depth=%0d", effect_count, SPENT_DEPTH);

    load_token(1'b1, 4'h1, 4'h2, 4'h3, 4'h4, 4'h1, 4'h5);
    send_command(1'b1, 4'h1, 4'h2, 4'h3, 4'h4, 4'h1, 4'h5);
    if (!last_reject || effect_count != 1) $fatal(1, "recovery boundary did not block command");
    $display("a4_recovery blocked=1 effect_count=%0d", effect_count);

    send_command(1'b0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h1, 4'h5);
    if (!last_permit || effect_count != 2) $fatal(1, "fresh attempt did not permit effect");
    $display("a4_fresh_attempt permit=1 effect_count=%0d", effect_count);

    load_token(1'b1, 4'h1, 4'h2, 4'h3, 4'h4, 4'h1, 4'h5);
    if (!last_load_reject) $fatal(1, "spent token reload was not rejected");
    $display("a4_spent_reload blocked=1 recent_spent=%b", spent_valid_o);

    load_token(1'b1, 4'h1, 4'h2, 4'h3, 4'h4, 4'h0, 4'h5);
    if (!last_load_reject) $fatal(1, "older recent spent token reload was not rejected");
    $display("a4_recent_history_replay blocked=1 recent_spent=%b", spent_valid_o);

    load_token(1'b1, 4'h1, 4'h2, 4'h3, 4'h4, 4'h2, 4'h5);
    if (!last_load_accept) $fatal(1, "fresh second attempt token did not load");
    send_command(1'b0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h2, 4'h5);
    if (!last_permit || effect_count != 3) $fatal(1, "fresh second attempt did not execute");
    $display("a4_second_fresh_attempt permit=1 effect_count=%0d", effect_count);

    $display("ASTRA_CAPU_V1_A4_RTL_AUTHORITY_SHIM_PASS");
    $finish;
  end
endmodule
