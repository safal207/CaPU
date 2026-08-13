`timescale 1ns/1ps
module capu_dma_completion_uncertainty_v27_tb;
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
  logic completion_receipt_valid; logic [3:0] completion_receipt_command_id,completion_receipt_execution_epoch,completion_receipt_effect_id;
  logic restore_accept,restore_rejected,resolution_accept,resolution_rejected,retire_accept,retire_rejected,dma_replay_authority,speculation_kill;

  capu_dma_completion_uncertainty_v27 dut(.*);
  always #5 clk=~clk;
  task tick; begin @(posedge clk); #1; end endtask

  task drive_issue; begin
    dma_issue_valid=1; dma_issue_command_id=4'd7; dma_issue_execution_epoch=4'd4; dma_issue_effect_id=4'd10; #1;
    if(!dma_issue_accept) $fatal(1,"exact DMA issue rejected");
    tick; dma_issue_valid=0;
  end endtask

  task drive_resolution(input logic committed); begin
    resolution_valid=1; resolution_committed=committed;
    resolution_command_id=4'd7; resolution_execution_epoch=4'd4; resolution_effect_id=4'd10; #1;
    if(!resolution_accept) $fatal(1,"exact resolution rejected");
    tick; resolution_valid=0;
  end endtask

  initial begin
    submit_valid=0; checkpoint_capture_valid=0; dma_issue_valid=0; resolution_valid=0; resolution_committed=0; restore_valid=0; retire_valid=0;
    submit_command_id=0; submit_execution_epoch=0; submit_effect_id=0;
    dma_issue_command_id=0; dma_issue_execution_epoch=0; dma_issue_effect_id=0;
    resolution_command_id=0; resolution_execution_epoch=0; resolution_effect_id=0;
    retire_command_id=0; retire_execution_epoch=0; retire_effect_id=0;

    #2; rst_n=0; tick; rst_n=1;

    submit_valid=1; submit_command_id=4'd7; submit_execution_epoch=4'd4; submit_effect_id=4'd10; #1;
    if(!submit_accept) $fatal(1,"submit rejected");
    tick; submit_valid=0;
    $display("command_submit accepted=1 command=7 execution_epoch=4 effect=10");

    checkpoint_capture_valid=1; #1;
    if(!checkpoint_capture_accept) $fatal(1,"checkpoint capture rejected");
    tick; checkpoint_capture_valid=0;
    if(checkpoint_completion_state!=2'b00 || checkpoint_dma_issued) $fatal(1,"checkpoint not pre-issue");
    $display("pre_issue_checkpoint captured=1 completion=NOT_COMMITTED dma_issued=0");

    drive_issue();
    if(completion_state!=2'b01 || !evidence_required || !issue_receipt_valid || !dma_issued) $fatal(1,"issue did not enter UNKNOWN");
    $display("dma_issue accepted=1 completion=UNKNOWN durable_issue_witness=1");

    dma_issue_valid=1; dma_issue_command_id=4'd7; dma_issue_execution_epoch=4'd4; dma_issue_effect_id=4'd10; #1;
    if(!dma_issue_rejected || dma_issue_accept) $fatal(1,"UNKNOWN replay accepted");
    dma_issue_valid=0;
    $display("unknown_live_replay rejected=1 no_guess_replay=1");

    retire_valid=1; retire_command_id=4'd7; retire_execution_epoch=4'd4; retire_effect_id=4'd10; #1;
    if(!retire_rejected || retire_accept) $fatal(1,"UNKNOWN retire accepted");
    retire_valid=0;
    $display("unknown_live_retire rejected=1 no_guess_commit=1");

    recovery_begin=1; tick; recovery_begin=0;
    if(runtime_ready || command_pending || !checkpoint_valid || !issue_receipt_valid) $fatal(1,"recovery persistence failure");
    $display("recovery volatile_state_cleared=1 pre_issue_checkpoint_preserved=1 issue_witness_preserved=1");

    restore_valid=1; #1;
    if(!restore_accept) $fatal(1,"restore rejected");
    tick; restore_valid=0;
    if(!runtime_ready || !command_pending || completion_state!=2'b01 || !evidence_required || dma_replay_authority) $fatal(1,"restore did not preserve uncertainty");
    $display("stale_checkpoint_restore accepted=1 completion=UNKNOWN evidence_required=1 replay_authority=0 retire_authority=0");

    dma_issue_valid=1; dma_issue_command_id=4'd7; dma_issue_execution_epoch=4'd4; dma_issue_effect_id=4'd10; #1;
    if(!dma_issue_rejected || dma_issue_accept) $fatal(1,"post-restore UNKNOWN replay accepted");
    dma_issue_valid=0;
    $display("post_restore_unknown_replay rejected=1 require_discriminating_evidence=1");

    resolution_valid=1; resolution_committed=1; resolution_command_id=4'd7; resolution_execution_epoch=4'd4; resolution_effect_id=4'd11; #1;
    if(!resolution_rejected || resolution_accept) $fatal(1,"foreign evidence accepted");
    resolution_valid=0;
    $display("foreign_completion_evidence rejected=1 exact_identity_required=1");

    drive_resolution(1'b0);
    if(completion_state!=2'b00 || evidence_required || dma_issued || issue_receipt_valid || !dma_replay_authority) $fatal(1,"NOT_COMMITTED resolution failed");
    $display("exact_evidence_not_committed accepted=1 replay_authority_reopened=1");

    drive_issue();
    if(completion_state!=2'b01 || !evidence_required) $fatal(1,"retry did not return UNKNOWN");
    $display("retry_issue accepted=1 completion=UNKNOWN");

    drive_resolution(1'b1);
    if(completion_state!=2'b10 || !effect_spent || !completion_receipt_valid || evidence_required || dma_replay_authority) $fatal(1,"COMMITTED resolution failed");
    $display("exact_evidence_committed accepted=1 durable_completion_receipt=1 effect_spent=1 replay_authority=0");

    dma_issue_valid=1; dma_issue_command_id=4'd7; dma_issue_execution_epoch=4'd4; dma_issue_effect_id=4'd10; #1;
    if(!dma_issue_rejected || dma_issue_accept) $fatal(1,"committed effect replayed");
    dma_issue_valid=0;
    $display("post_commit_dma_replay rejected=1 exactly_once_effect=1");

    retire_valid=1; retire_command_id=4'd7; retire_execution_epoch=4'd4; retire_effect_id=4'd10; #1;
    if(!retire_accept) $fatal(1,"committed command did not retire");
    tick; retire_valid=0;
    if(command_pending) $fatal(1,"retire did not clear command");
    $display("command_retire accepted=1 completion_evidence_resolved=COMMITTED");

    recovery_begin=1; tick; recovery_begin=0;
    restore_valid=1; #1;
    if(!restore_accept) $fatal(1,"second stale restore rejected");
    tick; restore_valid=0;
    if(completion_state!=2'b10 || evidence_required || dma_replay_authority || !completion_receipt_valid) $fatal(1,"completion receipt did not dominate stale checkpoint");
    $display("late_stale_checkpoint_restore completion_receipt_wins=1 completion=COMMITTED replay_authority=0");

    $display("CAPU_VCML_DMA_COMPLETION_UNCERTAINTY_V27_PASS");
    $finish;
  end
endmodule
