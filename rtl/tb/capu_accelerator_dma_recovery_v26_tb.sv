`timescale 1ns/1ps
module capu_accelerator_dma_recovery_v26_tb;
  logic clk=0,rst_n=0,recovery_begin=0;
  logic submit_valid; logic [3:0] submit_command_id,submit_execution_epoch,submit_effect_id;
  logic checkpoint_capture_valid;
  logic dma_issue_valid; logic [3:0] dma_issue_command_id,dma_issue_execution_epoch,dma_issue_effect_id;
  logic dma_commit_valid; logic [3:0] dma_commit_command_id,dma_commit_execution_epoch,dma_commit_effect_id;
  logic restore_valid;
  logic reconcile_valid; logic [3:0] reconcile_command_id,reconcile_execution_epoch,reconcile_effect_id;
  logic retire_valid; logic [3:0] retire_command_id,retire_execution_epoch,retire_effect_id;

  logic runtime_ready,submit_accept,submit_rejected,command_pending;
  logic [3:0] live_command_id,live_execution_epoch,live_effect_id;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_command_pending;
  logic [3:0] checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id;
  logic checkpoint_dma_issued,checkpoint_effect_spent;
  logic dma_issue_accept,dma_issue_rejected,dma_issued,dma_commit_accept,dma_commit_rejected,effect_spent;
  logic receipt_valid; logic [3:0] receipt_command_id,receipt_execution_epoch,receipt_effect_id;
  logic restore_accept,restore_rejected,reconcile_required,reconcile_accept,reconcile_rejected;
  logic retire_accept,retire_rejected,dma_replay_authority,speculation_kill;

  capu_accelerator_dma_recovery_v26 dut(.*);
  always #5 clk=~clk;
  task tick; begin @(posedge clk); #1; end endtask

  task set_identity;
    begin
      submit_command_id=4'd5; submit_execution_epoch=4'd3; submit_effect_id=4'd9;
      dma_issue_command_id=4'd5; dma_issue_execution_epoch=4'd3; dma_issue_effect_id=4'd9;
      dma_commit_command_id=4'd5; dma_commit_execution_epoch=4'd3; dma_commit_effect_id=4'd9;
      reconcile_command_id=4'd5; reconcile_execution_epoch=4'd3; reconcile_effect_id=4'd9;
      retire_command_id=4'd5; retire_execution_epoch=4'd3; retire_effect_id=4'd9;
    end
  endtask

  initial begin
    submit_valid=0; checkpoint_capture_valid=0; dma_issue_valid=0; dma_commit_valid=0;
    restore_valid=0; reconcile_valid=0; retire_valid=0; set_identity();
    #2; rst_n=0; tick; rst_n=1;

    submit_valid=1; #1;
    if(!submit_accept) $fatal(1,"submit rejected");
    tick; submit_valid=0;
    if(!command_pending || !runtime_ready) $fatal(1,"command not live");
    $display("command_submit accepted=1 command=5 execution_epoch=3 effect=9");

    checkpoint_capture_valid=1; #1;
    if(!checkpoint_capture_accept) $fatal(1,"checkpoint capture rejected");
    tick; checkpoint_capture_valid=0;
    if(!checkpoint_valid || checkpoint_dma_issued || checkpoint_effect_spent) $fatal(1,"bad pre-effect checkpoint");
    $display("pre_effect_checkpoint captured=1 dma_issued=0 effect_spent=0");

    dma_issue_valid=1; #1;
    if(!dma_issue_accept || !dma_replay_authority) $fatal(1,"DMA issue not authorized");
    tick; dma_issue_valid=0;
    if(!dma_issued) $fatal(1,"DMA issue state missing");
    $display("dma_issue authorized=1 command=5 effect=9");

    dma_commit_valid=1; #1;
    if(!dma_commit_accept) $fatal(1,"DMA commit rejected");
    tick; dma_commit_valid=0;
    if(!receipt_valid || !effect_spent) $fatal(1,"durable effect receipt missing");
    $display("dma_effect committed=1 durable_receipt=1 effect_spent=1");

    dma_commit_valid=1; #1;
    if(!dma_commit_rejected || dma_commit_accept) $fatal(1,"duplicate DMA commit accepted");
    dma_commit_valid=0;
    $display("duplicate_dma_commit rejected=1 exactly_once_effect=1");

    recovery_begin=1; tick; recovery_begin=0;
    if(runtime_ready || command_pending || dma_issued || effect_spent) $fatal(1,"volatile recovery state not cleared");
    if(!checkpoint_valid || !receipt_valid) $fatal(1,"durable evidence lost");
    $display("recovery volatile_state_cleared=1 checkpoint_preserved=1 receipt_preserved=1");

    restore_valid=1; #1;
    if(!restore_accept) $fatal(1,"restore rejected");
    tick; restore_valid=0;
    if(!runtime_ready || !command_pending || !reconcile_required || effect_spent) $fatal(1,"restore did not enter reconcile-required state");
    $display("stale_checkpoint_restore accepted=1 reconcile_required=1 checkpoint_effect_spent=0 durable_receipt=1");

    dma_issue_valid=1; #1;
    if(!dma_issue_rejected || dma_issue_accept || dma_replay_authority) $fatal(1,"replay authority reopened before reconcile");
    dma_issue_valid=0;
    $display("post_restore_dma_replay rejected=1 receipt_conflict_blocks_authority=1");

    retire_valid=1; #1;
    if(!retire_rejected || retire_accept) $fatal(1,"retired before reconciliation");
    retire_valid=0;
    $display("pre_reconcile_retire rejected=1");

    reconcile_effect_id=4'd8; reconcile_valid=1; #1;
    if(!reconcile_rejected || reconcile_accept) $fatal(1,"foreign reconcile accepted");
    reconcile_valid=0; reconcile_effect_id=4'd9;
    $display("foreign_reconcile rejected=1");

    reconcile_valid=1; #1;
    if(!reconcile_accept) $fatal(1,"exact reconcile rejected");
    tick; reconcile_valid=0;
    if(reconcile_required || !effect_spent) $fatal(1,"reconciliation did not mark effect spent");
    $display("exact_reconcile accepted=1 effect_spent=1 reconcile_required=0");

    dma_issue_valid=1; #1;
    if(!dma_issue_rejected || dma_issue_accept || dma_replay_authority) $fatal(1,"spent effect replayed");
    dma_issue_valid=0;
    $display("post_reconcile_dma_replay rejected=1 spent_effect_cannot_reexecute=1");

    retire_valid=1; #1;
    if(!retire_accept) $fatal(1,"retire rejected");
    tick; retire_valid=0;
    if(command_pending) $fatal(1,"command not retired");
    $display("command_retire accepted=1 exactly_once_dma_effect=1");

    submit_valid=1; #1;
    if(!submit_rejected || submit_accept) $fatal(1,"historical command identity reused");
    submit_valid=0;
    $display("historical_command_reuse rejected=1 durable_receipt_blocks_identity_reuse=1");

    $display("CAPU_VCML_ACCELERATOR_DMA_RECOVERY_V26_PASS");
    $finish;
  end
endmodule
