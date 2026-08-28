`timescale 1ns/1ps
module capu_multibeat_dma_recovery_v29_tb;
  logic clk=0,rst_n=0,recovery_begin=0;
  logic submit_valid; logic [3:0] submit_command_id,submit_execution_epoch,submit_effect_id;
  logic checkpoint_capture_valid;
  logic beat_issue_valid; logic [1:0] beat_issue_index; logic [3:0] beat_issue_command_id,beat_issue_execution_epoch,beat_issue_effect_id;
  logic resolution_valid,resolution_committed; logic [1:0] resolution_beat_index; logic [3:0] resolution_command_id,resolution_execution_epoch,resolution_effect_id;
  logic restore_valid;
  logic retire_valid; logic [3:0] retire_command_id,retire_execution_epoch,retire_effect_id;
  logic runtime_ready,submit_accept,submit_rejected,command_pending;
  logic [3:0] live_command_id,live_execution_epoch,live_effect_id;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_command_pending;
  logic [3:0] checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id;
  logic [7:0] checkpoint_beat_states;
  logic beat_issue_accept,beat_issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic [7:0] beat_states; logic [3:0] evidence_required_bitmap,beat_replay_authority;
  logic [3:0] issue_receipt_bitmap,negative_receipt_bitmap,completion_receipt_bitmap;
  logic [3:0] receipt_command_id,receipt_execution_epoch,receipt_effect_id;
  logic all_beats_committed,speculation_kill;

  capu_multibeat_dma_recovery_v29 dut(.*);
  always #5 clk=~clk;
  task tick; begin @(posedge clk); #1; end endtask

  task issue_beat(input logic [1:0] idx); begin
    beat_issue_valid=1; beat_issue_index=idx;
    beat_issue_command_id=4'd11; beat_issue_execution_epoch=4'd6; beat_issue_effect_id=4'd13; #1;
    if(!beat_issue_accept) $fatal(1,"exact beat issue rejected idx=%0d",idx);
    tick; beat_issue_valid=0; #1;
  end endtask

  task resolve_beat(input logic [1:0] idx,input logic committed); begin
    resolution_valid=1; resolution_committed=committed; resolution_beat_index=idx;
    resolution_command_id=4'd11; resolution_execution_epoch=4'd6; resolution_effect_id=4'd13; #1;
    if(!resolution_accept) $fatal(1,"exact beat resolution rejected idx=%0d",idx);
    tick; resolution_valid=0; #1;
  end endtask

  task crash_and_restore; begin
    recovery_begin=1; tick; recovery_begin=0; #1;
    if(runtime_ready || command_pending || !checkpoint_valid) $fatal(1,"recovery failed");
    restore_valid=1; #1;
    if(!restore_accept) $fatal(1,"restore rejected");
    tick; restore_valid=0; #1;
  end endtask

  initial begin
    submit_valid=0; checkpoint_capture_valid=0; beat_issue_valid=0; resolution_valid=0; resolution_committed=0; restore_valid=0; retire_valid=0;
    submit_command_id=0; submit_execution_epoch=0; submit_effect_id=0;
    beat_issue_index=0; beat_issue_command_id=0; beat_issue_execution_epoch=0; beat_issue_effect_id=0;
    resolution_beat_index=0; resolution_command_id=0; resolution_execution_epoch=0; resolution_effect_id=0;
    retire_command_id=0; retire_execution_epoch=0; retire_effect_id=0;

    #2; rst_n=0; tick; rst_n=1;

    submit_valid=1; submit_command_id=4'd11; submit_execution_epoch=4'd6; submit_effect_id=4'd13; #1;
    if(!submit_accept) $fatal(1,"submit rejected");
    tick; submit_valid=0; #1;
    $display("command_submit accepted=1 command=11 execution_epoch=6 effect=13 beats=4");

    issue_beat(2'd0); resolve_beat(2'd0,1'b1);
    if(beat_states[1:0]!=2'b10 || completion_receipt_bitmap!=4'b0001 || beat_replay_authority[0]) $fatal(1,"beat0 commit failed");
    $display("beat0 committed=1 durable_completion_receipt=1 replay_blocked=1");

    issue_beat(2'd1); resolve_beat(2'd1,1'b1);
    if(beat_states[3:2]!=2'b10 || completion_receipt_bitmap!=4'b0011 || beat_replay_authority[1]) $fatal(1,"beat1 commit failed");
    $display("beat1 committed=1 durable_completion_receipt=1 replay_blocked=1");

    issue_beat(2'd2);
    if(beat_states[5:4]!=2'b01 || issue_receipt_bitmap!=4'b0100 || evidence_required_bitmap!=4'b0100 || beat_replay_authority!=4'b0000)
      $fatal(1,"beat2 did not enter UNKNOWN or tail authority leaked");
    $display("beat2 issued=1 completion=UNKNOWN evidence_required=1 tail_beat3_blocked=1");

    checkpoint_capture_valid=1; #1;
    if(!checkpoint_capture_accept) $fatal(1,"partial checkpoint capture rejected");
    tick; checkpoint_capture_valid=0; #1;
    if(checkpoint_beat_states!=8'b00011010) $fatal(1,"partial checkpoint bytes wrong: %b",checkpoint_beat_states);
    $display("partial_checkpoint beats=COMMITTED,COMMITTED,UNKNOWN,UNISSUED");

    crash_and_restore();
    if(beat_states!=8'b00011010 || evidence_required_bitmap!=4'b0100 || beat_replay_authority!=4'b0000)
      $fatal(1,"partial restore guessed unresolved state");
    $display("partial_restore committed_prefix_replay_blocked=1 unresolved_beat_requires_evidence=1 tail_blocked=1");

    resolution_valid=1; resolution_committed=1; resolution_beat_index=2'd2;
    resolution_command_id=4'd11; resolution_execution_epoch=4'd6; resolution_effect_id=4'd14; #1;
    if(!resolution_rejected || resolution_accept) $fatal(1,"foreign beat completion evidence accepted");
    resolution_valid=0;
    $display("foreign_beat_evidence rejected=1 exact_transaction_identity_required=1");

    resolve_beat(2'd2,1'b0);
    if(beat_states[5:4]!=2'b11 || negative_receipt_bitmap!=4'b0100 || issue_receipt_bitmap!=0 || !beat_replay_authority[2] || beat_replay_authority[3])
      $fatal(1,"negative beat2 evidence did not isolate replay authority");
    $display("negative_evidence beat=2 durable_negative_receipt=1 replay_authority=1 tail_blocked=1");

    crash_and_restore();
    if(beat_states[1:0]!=2'b10 || beat_states[3:2]!=2'b10 || beat_states[5:4]!=2'b11 || beat_states[7:6]!=2'b00 || !beat_replay_authority[2] || beat_replay_authority[3])
      $fatal(1,"negative receipt did not dominate stale UNKNOWN beat");
    $display("stale_partial_restore negative_receipt_wins=1 beat2=NOT_COMMITTED replay_authority=1");

    issue_beat(2'd2);
    if(beat_states[5:4]!=2'b01 || negative_receipt_bitmap[2] || !issue_receipt_bitmap[2] || beat_replay_authority!=0)
      $fatal(1,"beat2 retry did not consume old negative receipt");
    $display("beat2_retry accepted=1 old_negative_receipt_consumed=1 completion=UNKNOWN");

    crash_and_restore();
    if(beat_states[5:4]!=2'b01 || !issue_receipt_bitmap[2] || evidence_required_bitmap!=4'b0100 || beat_replay_authority!=0)
      $fatal(1,"current issue witness lost across retry crash");
    $display("retry_crash_restore current_issue_witness_wins=1 beat2=UNKNOWN replay_authority=0");

    resolve_beat(2'd2,1'b1);
    if(beat_states[5:4]!=2'b10 || completion_receipt_bitmap!=4'b0111 || !beat_replay_authority[3])
      $fatal(1,"committing beat2 did not open exact tail beat authority");
    $display("prefix_complete beat0_2_committed=1 beat3_authority=1");

    issue_beat(2'd3);
    if(beat_states[7:6]!=2'b01 || evidence_required_bitmap!=4'b1000 || beat_replay_authority!=0)
      $fatal(1,"beat3 issue failed");
    resolve_beat(2'd3,1'b1);
    if(!all_beats_committed || completion_receipt_bitmap!=4'b1111 || beat_replay_authority!=0)
      $fatal(1,"full transaction did not commit exactly");
    $display("beat3 committed=1 all_beats_committed=1 durable_completion_bitmap=1111");

    retire_valid=1; retire_command_id=4'd11; retire_execution_epoch=4'd6; retire_effect_id=4'd13; #1;
    if(!retire_accept) $fatal(1,"fully committed multi-beat command did not retire");
    tick; retire_valid=0; #1;
    $display("command_retire accepted=1 exact_multibeat_completion=1");

    crash_and_restore();
    if(!all_beats_committed || completion_receipt_bitmap!=4'b1111 || beat_replay_authority!=0 || evidence_required_bitmap!=0)
      $fatal(1,"completion receipts did not dominate stale partial checkpoint");
    $display("late_stale_partial_restore completion_receipts_win=1 all_beats=COMMITTED replay_bitmap=0000");

    $display("CAPU_VCML_MULTIBEAT_DMA_RECOVERY_V29_PASS");
    $finish;
  end
endmodule
