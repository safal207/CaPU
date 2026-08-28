`timescale 1ns/1ps
module capu_accelerator_effect_authority_a1_tb;
  localparam [1:0] NOT_COMMITTED = 2'b00;
  localparam [1:0] UNKNOWN = 2'b01;
  localparam [1:0] COMMITTED = 2'b10;

  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n, recovery_begin, restore_valid;
  logic request_valid; logic [7:0] request_tag;
  logic checkpoint_capture_valid;
  logic issue_valid; logic [7:0] issue_tag;
  logic evidence_valid; logic [7:0] evidence_tag; logic [1:0] evidence_completion_state;
  logic retire_valid; logic [7:0] retire_tag;

  logic runtime_ready, request_accept, request_rejected;
  logic checkpoint_capture_accept, issue_accept, issue_rejected;
  logic evidence_accept, evidence_rejected, restore_accept, restore_rejected;
  logic retire_accept, retire_rejected, request_active;
  logic [7:0] current_request_tag; logic execution_started; logic [1:0] completion_state;
  logic issue_authority, evidence_required, successor_attempt_authority;
  logic retire_authority, proof_receipt_valid, speculation_kill;
  logic checkpoint_valid, durable_request_valid_o; logic [7:0] durable_request_tag_o;
  logic durable_issue_witness_o, durable_negative_receipt_o;
  logic durable_completion_receipt_o, durable_retired_o;

  capu_accelerator_effect_authority_a1 dut (.*);

  task clear_inputs;
    begin
      recovery_begin=0; restore_valid=0; request_valid=0; request_tag=0;
      checkpoint_capture_valid=0; issue_valid=0; issue_tag=0;
      evidence_valid=0; evidence_tag=0; evidence_completion_state=UNKNOWN;
      retire_valid=0; retire_tag=0;
    end
  endtask

  task pulse_request(input [7:0] tag);
    begin
      @(negedge clk); request_valid=1; request_tag=tag; #1;
      if (!request_accept) $fatal(1,"request not accepted");
      @(posedge clk);
      @(negedge clk); request_valid=0;
    end
  endtask

  task pulse_checkpoint;
    begin
      @(negedge clk); checkpoint_capture_valid=1; #1;
      if (!checkpoint_capture_accept) $fatal(1,"checkpoint not accepted");
      @(posedge clk);
      @(negedge clk); checkpoint_capture_valid=0;
    end
  endtask

  task pulse_issue(input [7:0] tag, input bit expect_accept);
    begin
      @(negedge clk); issue_valid=1; issue_tag=tag; #1;
      if (expect_accept && !issue_accept) $fatal(1,"issue expected accept");
      if (!expect_accept && !issue_rejected) $fatal(1,"issue expected reject");
      @(posedge clk);
      @(negedge clk); issue_valid=0;
    end
  endtask

  task pulse_evidence(input [7:0] tag, input [1:0] result, input bit expect_accept);
    begin
      @(negedge clk); evidence_valid=1; evidence_tag=tag; evidence_completion_state=result; #1;
      if (expect_accept && !evidence_accept) $fatal(1,"evidence expected accept");
      if (!expect_accept && !evidence_rejected) $fatal(1,"evidence expected reject");
      @(posedge clk);
      @(negedge clk); evidence_valid=0;
    end
  endtask

  task pulse_recovery_restore;
    begin
      @(negedge clk); recovery_begin=1;
      @(posedge clk); #1; if (runtime_ready) $fatal(1,"runtime must close on recovery");
      @(negedge clk); recovery_begin=0; restore_valid=1; #1;
      if (!restore_accept) $fatal(1,"restore not accepted");
      @(posedge clk);
      @(negedge clk); restore_valid=0;
    end
  endtask

  task pulse_retire(input [7:0] tag, input bit expect_accept);
    begin
      @(negedge clk); retire_valid=1; retire_tag=tag; #1;
      if (expect_accept && !retire_accept) $fatal(1,"retire expected accept");
      if (!expect_accept && !retire_rejected) $fatal(1,"retire expected reject");
      @(posedge clk);
      @(negedge clk); retire_valid=0;
    end
  endtask

  initial begin
    clear_inputs(); rst_n=0;
    repeat (2) @(posedge clk);
    @(negedge clk); rst_n=1;

    pulse_request(8'h51);
    pulse_checkpoint();
    pulse_issue(8'h51, 1);
    if (completion_state != UNKNOWN || !evidence_required || retire_authority)
      $fatal(1,"UNKNOWN gate missing");
    pulse_retire(8'h51, 0);
    pulse_recovery_restore();
    if (completion_state != UNKNOWN || !evidence_required || current_request_tag != 8'h51)
      $fatal(1,"durable issue witness did not dominate stale checkpoint");
    $display("unknown_recovery request=51 state=UNKNOWN evidence_required=1 retire_authority=0");

    pulse_evidence(8'h52, COMMITTED, 0);
    if (completion_state != UNKNOWN || !evidence_required || proof_receipt_valid)
      $fatal(1,"foreign evidence mutated authority state");
    $display("foreign_evidence rejected=1 state_unchanged=UNKNOWN proof_receipt=0");

    pulse_evidence(8'h51, NOT_COMMITTED, 1);
    if (completion_state != NOT_COMMITTED || !successor_attempt_authority || issue_authority)
      $fatal(1,"negative evidence did not expose successor-only authority");
    pulse_issue(8'h51, 0);
    $display("negative_resolution current_attempt_closed=1 successor_attempt_authority=1 same_attempt_issue=REJECTED");

    @(negedge clk); rst_n=0;
    repeat (2) @(posedge clk);
    @(negedge clk); rst_n=1;
    pulse_request(8'hA7);
    pulse_checkpoint();
    pulse_issue(8'hA7, 1);
    pulse_recovery_restore();
    pulse_evidence(8'hA7, COMMITTED, 1);
    if (completion_state != COMMITTED || !proof_receipt_valid || !retire_authority)
      $fatal(1,"committed evidence did not close effect authority");
    pulse_retire(8'hA7, 1);
    if (!durable_retired_o || request_active) $fatal(1,"retirement not durable");
    $display("committed_resolution exact_evidence=1 proof_receipt=1 retire=ACCEPTED replay_closed=1");

    $display("CAPU_ACCELERATOR_EFFECT_AUTHORITY_A1_PASS");
    $finish;
  end
endmodule
