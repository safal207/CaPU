`timescale 1ns/1ps
module capu_durable_negative_completion_v28_tb;
  logic clk=0,rst_n=0,recovery_begin=0;
  logic submit_valid; logic [3:0] submit_command_id,submit_execution_epoch,submit_effect_id;
  logic checkpoint_capture_valid;
  logic dma_issue_valid; logic [3:0] dma_issue_command_id,dma_issue_execution_epoch,dma_issue_effect_id;
  logic resolution_valid,resolution_committed; logic [3:0] resolution_command_id,resolution_execution_epoch,resolution_effect_id;
  logic restore_valid;
  logic retire_valid; logic [3:0] retire_command_id,retire_execution_epoch,retire_effect_id;
  logic runtime_ready,submit_accept,submit_rejected,command_pending;
  logic [3:0] live_command_id,live_execution_epoch,live_effect_id;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_command_pending;
  logic [3:0] checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id;
  logic checkpoint_dma_issued; logic [1:0] checkpoint_completion_state;
  logic dma_issue_accept,dma_issue_rejected,dma_issued; logic [1:0] completion_state; logic evidence_required,effect_spent;
  logic issue_receipt_valid; logic [3:0] issue_receipt_command_id,issue_receipt_execution_epoch,issue_receipt_effect_id;
  logic negative_receipt_valid; logic [3:0] negative_receipt_command_id,negative_receipt_execution_epoch,negative_receipt_effect_id;
  logic completion_receipt_valid; logic [3:0] completion_receipt_command_id,completion_receipt_execution_epoch,completion_receipt_effect_id;
  logic restore_accept,restore_rejected,resolution_accept,resolution_rejected,retire_accept,retire_rejected,dma_replay_authority,speculation_kill;

  capu_durable_negative_completion_v28 dut(.*);
  always #5 clk=~clk;
  task tick; begin @(posedge clk); #1; end endtask

  task drive_issue; begin
    dma_issue_valid=1; dma_issue_command_id=4'd9; dma_issue_execution_epoch=4'd5; dma_issue_effect_id=4'd12; #1;
    if(!dma_issue_accept) $fatal(1,"exact DMA issue rejected");
    tick; dma_issue_valid=0;
  end endtask

  task drive_resolution(input logic committed); begin
    resolution_valid=1; resolution_committed=committed;
    resolution_command_id=4'd9; resolution_execution_epoch=4'd5; resolution_effect_id=4'd12; #1;
    if(!resolution_accept) $fatal(1,"exact resolution rejected");
    tick; resolution_valid=0;
  end endtask

  task crash_and_restore; begin
    recovery_begin=1; tick; recovery_begin=0;
    if(runtime_ready || command_pending || !checkpoint_valid) $fatal(1,"recovery failed");
    restore_valid=1; #1;
    if(!restore_accept) $fatal(1,"restore rejected");
    tick; restore_valid=0;
  end endtask

  initial begin
    submit_valid=0; checkpoint_capture_valid=0; dma_issue_valid=0; resolution_valid=0; resolution_committed=0; restore_valid=0; retire_valid=0;
    submit_command_id=0; submit_execution_epoch=0; submit_effect_id=0;
    dma_issue_command_id=0; dma_issue_execution_epoch=0; dma_issue_effect_id=0;
    resolution_command_id=0; resolution_execution_epoch=0; resolution_effect_id=0;
    retire_command_id=0; retire_execution_epoch=0; retire_effect_id=0;

    #2; rst_n=0; tick; rst_n=1;

    submit_valid=1; submit_command_id=4'd9; submit_execution_epoch=4'd5; submit_effect_id=4'd12; #1;
    if(!submit_accept) $fatal(1,"submit rejected");
    tick; submit_valid=0;
    $display("command_submit accepted=1 command=9 execution_epoch=5 effect=12");

    drive_issue();
    if(completion_state!=2'b01 || !evidence_required || !issue_receipt_valid) $fatal(1,"issue did not enter UNKNOWN");
    $display("dma_issue accepted=1 completion=UNKNOWN durable_issue_witness=1");

    checkpoint_capture_valid=1; #1;
    if(!checkpoint_capture_accept) $fatal(1,"UNKNOWN checkpoint capture rejected");
    tick; checkpoint_capture_valid=0;
    if(checkpoint_completion_state!=2'b01 || !checkpoint_dma_issued) $fatal(1,"checkpoint did not capture UNKNOWN");
    $display("unknown_checkpoint captured=1 completion=UNKNOWN dma_issued=1");

    drive_resolution(1'b0);
    if(completion_state!=2'b00 || evidence_required || dma_issued || issue_receipt_valid || !negative_receipt_valid || !dma_replay_authority)
      $fatal(1,"negative resolution did not create replayable durable evidence");
    $display("exact_evidence_not_committed accepted=1 durable_negative_receipt=1 replay_authority=1");

    recovery_begin=1; tick; recovery_begin=0;
    if(runtime_ready || command_pending || !checkpoint_valid || !negative_receipt_valid || issue_receipt_valid)
      $fatal(1,"negative receipt did not survive recovery");
    $display("recovery stale_unknown_checkpoint_preserved=1 negative_receipt_preserved=1");

    restore_valid=1; #1;
    if(!restore_accept) $fatal(1,"negative convergence restore rejected");
    tick; restore_valid=0;
    if(!runtime_ready || !command_pending || completion_state!=2'b00 || evidence_required || dma_issued || !negative_receipt_valid || !dma_replay_authority)
      $fatal(1,"durable negative receipt did not dominate stale UNKNOWN checkpoint");
    $display("stale_unknown_restore negative_receipt_wins=1 completion=NOT_COMMITTED replay_authority=1");

    drive_issue();
    if(completion_state!=2'b01 || !evidence_required || !issue_receipt_valid || negative_receipt_valid)
      $fatal(1,"retry did not consume old negative evidence");
    $display("retry_issue accepted=1 old_negative_receipt_consumed=1 completion=UNKNOWN");

    crash_and_restore();
    if(completion_state!=2'b01 || !evidence_required || !issue_receipt_valid || dma_replay_authority)
      $fatal(1,"new in-flight attempt did not restore as UNKNOWN");
    $display("retry_crash_restore current_issue_witness_wins=1 completion=UNKNOWN replay_authority=0");

    resolution_valid=1; resolution_committed=1; resolution_command_id=4'd9; resolution_execution_epoch=4'd5; resolution_effect_id=4'd13; #1;
    if(!resolution_rejected || resolution_accept) $fatal(1,"foreign completion evidence accepted");
    resolution_valid=0;
    $display("foreign_completion_evidence rejected=1 exact_identity_required=1");

    drive_resolution(1'b1);
    if(completion_state!=2'b10 || !effect_spent || !completion_receipt_valid || negative_receipt_valid || evidence_required || dma_replay_authority)
      $fatal(1,"committed resolution failed");
    $display("exact_evidence_committed accepted=1 durable_completion_receipt=1 effect_spent=1 replay_authority=0");

    retire_valid=1; retire_command_id=4'd9; retire_execution_epoch=4'd5; retire_effect_id=4'd12; #1;
    if(!retire_accept) $fatal(1,"committed command did not retire");
    tick; retire_valid=0;
    $display("command_retire accepted=1 completion=COMMITTED");

    crash_and_restore();
    if(completion_state!=2'b10 || !completion_receipt_valid || evidence_required || dma_replay_authority)
      $fatal(1,"completion receipt did not dominate stale UNKNOWN checkpoint");
    $display("late_stale_unknown_restore completion_receipt_wins=1 completion=COMMITTED replay_authority=0");

    $display("CAPU_VCML_DURABLE_NEGATIVE_COMPLETION_V28_PASS");
    $finish;
  end
endmodule
