`timescale 1ns/1ps
module capu_concurrent_dma_queue_recovery_v31_tb;
  logic clk=0; always #5 clk=~clk;
  logic rst_n=0,recovery_begin=0;

  logic submit_valid=0,submit_tx_index=0;
  logic [3:0] submit_command_id=0,submit_execution_epoch=0,submit_effect_id=0,submit_queue_epoch=0;
  logic checkpoint_capture_valid=0;

  logic fragment_issue_valid=0,fragment_issue_tx_index=0,fragment_issue_index=0;
  logic [3:0] fragment_issue_command_id=0,fragment_issue_execution_epoch=0,fragment_issue_effect_id=0,fragment_issue_queue_epoch=0;

  logic resolution_valid=0,resolution_committed=0,resolution_tx_index=0,resolution_fragment_index=0;
  logic [3:0] resolution_command_id=0,resolution_execution_epoch=0,resolution_effect_id=0,resolution_queue_epoch=0;

  logic restore_valid=0;
  logic retire_valid=0,retire_tx_index=0;
  logic [3:0] retire_command_id=0,retire_execution_epoch=0,retire_effect_id=0,retire_queue_epoch=0;

  logic runtime_ready,submit_accept;
  logic [1:0] tx_pending,tx_retired;
  logic [3:0] live_queue_epoch;
  logic [7:0] live_command_ids,live_execution_epochs,live_effect_ids;
  logic checkpoint_capture_accept,checkpoint_valid;
  logic [1:0] checkpoint_tx_pending,checkpoint_tx_retired;
  logic [3:0] checkpoint_queue_epoch;
  logic [7:0] checkpoint_command_ids,checkpoint_execution_epochs,checkpoint_effect_ids;
  logic [7:0] checkpoint_fragment_states,checkpoint_owner_map;
  logic [3:0] checkpoint_owner_valid;
  logic fragment_issue_accept,fragment_issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic [7:0] fragment_states;
  logic [3:0] replay_authority_bitmap,evidence_required_bitmap,queue_blocked_bitmap;
  logic [3:0] issue_receipt_bitmap,negative_receipt_bitmap,completion_receipt_bitmap;
  logic [3:0] durable_owner_valid,visible_owner_valid;
  logic [7:0] durable_owner_map,visible_owner_map;
  logic all_tx0_fragments_committed,all_tx1_fragments_committed,speculation_kill;

  capu_concurrent_dma_queue_recovery_v31 dut(.*);

  function automatic [3:0] cmd(input logic tx); cmd = tx ? 4'd11 : 4'd10; endfunction
  function automatic [3:0] eff(input logic tx); eff = tx ? 4'd9 : 4'd8; endfunction

  task automatic submit_tx(input logic tx);
    begin
      @(negedge clk);
      submit_tx_index=tx; submit_command_id=cmd(tx); submit_execution_epoch=4'd4; submit_effect_id=eff(tx); submit_queue_epoch=4'd3; submit_valid=1; #1;
      if(!submit_accept) $fatal(1,"submit not accepted tx=%0d",tx);
      @(posedge clk); #1;
      if(!tx_pending[tx]) $fatal(1,"submit did not set pending tx=%0d",tx);
      @(negedge clk); submit_valid=0;
    end
  endtask

  task automatic issue(input logic tx,input logic frag);
    begin
      @(negedge clk);
      fragment_issue_tx_index=tx; fragment_issue_index=frag;
      fragment_issue_command_id=cmd(tx); fragment_issue_execution_epoch=4'd4; fragment_issue_effect_id=eff(tx); fragment_issue_queue_epoch=4'd3;
      fragment_issue_valid=1; #1;
      if(!fragment_issue_accept) $fatal(1,"fragment issue not accepted tx=%0d frag=%0d blocked=%b replay=%b",tx,frag,queue_blocked_bitmap,replay_authority_bitmap);
      @(posedge clk); #1;
      if(fragment_states[{tx,frag}*2 +: 2]!==2'b01) $fatal(1,"issued fragment not UNKNOWN tx=%0d frag=%0d",tx,frag);
      @(negedge clk); fragment_issue_valid=0;
    end
  endtask

  task automatic resolve(input logic tx,input logic frag,input logic committed);
    begin
      @(negedge clk);
      resolution_tx_index=tx; resolution_fragment_index=frag;
      resolution_command_id=cmd(tx); resolution_execution_epoch=4'd4; resolution_effect_id=eff(tx); resolution_queue_epoch=4'd3;
      resolution_committed=committed; resolution_valid=1; #1;
      if(!resolution_accept) $fatal(1,"resolution not accepted tx=%0d frag=%0d",tx,frag);
      @(posedge clk); #1;
      if(committed && fragment_states[{tx,frag}*2 +: 2]!==2'b10) $fatal(1,"commit state mismatch tx=%0d frag=%0d",tx,frag);
      if(!committed && fragment_states[{tx,frag}*2 +: 2]!==2'b11) $fatal(1,"negative state mismatch tx=%0d frag=%0d",tx,frag);
      @(negedge clk); resolution_valid=0;
    end
  endtask

  task automatic retire_tx(input logic tx);
    begin
      @(negedge clk);
      retire_tx_index=tx; retire_command_id=cmd(tx); retire_execution_epoch=4'd4; retire_effect_id=eff(tx); retire_queue_epoch=4'd3; retire_valid=1; #1;
      if(!retire_accept) $fatal(1,"retire not accepted tx=%0d",tx);
      @(posedge clk); #1;
      if(!tx_retired[tx] || tx_pending[tx]) $fatal(1,"retire state mismatch tx=%0d",tx);
      @(negedge clk); retire_valid=0;
    end
  endtask

  initial begin
    repeat(2) @(posedge clk); rst_n=1;

    submit_tx(1'b0);

    // Capture a checkpoint before the younger slot exists. This is the stale
    // checkpoint that exposed the original formal counterexample: TX1 evidence
    // may become durable later, so restore must not erase TX1 slot identity.
    @(negedge clk); checkpoint_capture_valid=1; #1;
    if(!checkpoint_capture_accept) $fatal(1,"pre-TX1 checkpoint capture not accepted");
    @(posedge clk); #1; @(negedge clk); checkpoint_capture_valid=0;
    if(checkpoint_tx_pending!==2'b01) $fatal(1,"pre-TX1 checkpoint did not capture only TX0");
    $display("pre_tx1_checkpoint tx_pending=01 younger_slot_absent=1");

    submit_tx(1'b1);
    if(tx_pending!==2'b11 || live_queue_epoch!==4'd3 || dut.durable_tx_valid!==2'b11) $fatal(1,"queue submit state mismatch");
    $display("queue_submit tx0=1 tx1=1 queue_epoch=3 order=TX0_before_TX1 durable_slots=11");

    issue(1'b0,1'b0);
    issue(1'b1,1'b0);
    resolve(1'b1,1'b0,1'b1);
    if(completion_receipt_bitmap!==4'b0100 || visible_owner_map!==8'h80) $fatal(1,"younger non-overlap commit mismatch comp=%b owners=%h",completion_receipt_bitmap,visible_owner_map);
    $display("younger_nonoverlap_commit tx1_f0=COMMITTED older_tx0_f0=UNKNOWN lane3_owner=TX1_F0 concurrent_safe=1");

    // Recover through the stale pre-TX1 checkpoint. Durable transaction-slot
    // authority must reconstruct TX1 pending/identity before its fragment
    // receipts are interpreted.
    @(negedge clk); recovery_begin=1; #1; @(posedge clk); #1; @(negedge clk); recovery_begin=0;
    @(negedge clk); restore_valid=1; #1;
    if(!restore_accept) $fatal(1,"stale pre-TX1 restore not accepted");
    @(posedge clk); #1; @(negedge clk); restore_valid=0; #1;
    if(tx_pending!==2'b11 || live_command_ids!==8'hBA || live_effect_ids!==8'h98 || fragment_states!==8'h21 || visible_owner_map!==8'h80)
      $fatal(1,"durable slot restore mismatch pending=%b cmds=%h effects=%h states=%h owners=%h",tx_pending,live_command_ids,live_effect_ids,fragment_states,visible_owner_map);
    $display("stale_pre_tx1_restore durable_tx1_slot_wins=1 tx_pending=11 tx1_identity_preserved=1 fragment_evidence_preserved=1");

    @(negedge clk);
    submit_tx_index=1; submit_command_id=4'd11; submit_execution_epoch=4'd4; submit_effect_id=4'd9; submit_queue_epoch=4'd3; submit_valid=1; #1;
    if(submit_accept) $fatal(1,"stale checkpoint allowed TX1 slot resubmission");
    @(posedge clk); #1; @(negedge clk); submit_valid=0;
    if(completion_receipt_bitmap!==4'b0100 || durable_owner_map!==8'h80) $fatal(1,"rejected resubmit mutated durable TX1 evidence");
    $display("stale_slot_resubmit rejected=1 durable_slot_identity=1 completion_evidence_preserved=1");

    @(negedge clk);
    fragment_issue_tx_index=1; fragment_issue_index=1; fragment_issue_command_id=4'd11; fragment_issue_execution_epoch=4'd4; fragment_issue_effect_id=4'd9; fragment_issue_queue_epoch=4'd3; fragment_issue_valid=1; #1;
    if(!fragment_issue_rejected || !queue_blocked_bitmap[3]) $fatal(1,"younger overlapping fragment was not queue blocked");
    @(posedge clk); #1; @(negedge clk); fragment_issue_valid=0;
    $display("younger_overlap_blocked tx1_f1=1 older_overlap_unresolved=1 no_issue_authority=1");

    resolve(1'b0,1'b0,1'b1);
    issue(1'b0,1'b1); resolve(1'b0,1'b1,1'b1);
    if(!all_tx0_fragments_committed || queue_blocked_bitmap[3]) $fatal(1,"older completion did not release overlapping younger fragment");
    $display("older_overlap_resolved tx0_completion=11 tx1_f1_queue_blocked=0");

    issue(1'b1,1'b1);
    if(fragment_states!==8'h6A || visible_owner_map!==8'h90) $fatal(1,"pre-checkpoint state mismatch states=%h owners=%h",fragment_states,visible_owner_map);

    @(negedge clk); checkpoint_capture_valid=1; #1;
    if(!checkpoint_capture_accept) $fatal(1,"checkpoint capture not accepted");
    @(posedge clk); #1; @(negedge clk); checkpoint_capture_valid=0;
    $display("queue_checkpoint states=C,C,C,UNKNOWN owners=90 tx_pending=11 tx_retired=00");

    @(negedge clk); recovery_begin=1; #1;
    if(replay_authority_bitmap!==4'b0000) $fatal(1,"replay authority leaked during recovery");
    @(posedge clk); #1; @(negedge clk); recovery_begin=0;
    if(runtime_ready) $fatal(1,"recovery did not close runtime");

    @(negedge clk); restore_valid=1; #1;
    if(!restore_accept) $fatal(1,"restore not accepted");
    @(posedge clk); #1; @(negedge clk); restore_valid=0; #1;
    if(fragment_states!==8'h6A || tx_pending!==2'b11 || evidence_required_bitmap!==4'b1000 || visible_owner_map!==8'h90)
      $fatal(1,"queue restore mismatch states=%h pending=%b evidence=%b owners=%h",fragment_states,tx_pending,evidence_required_bitmap,visible_owner_map);
    $display("queue_restore exact_tx_slots=1 younger_nonoverlap_commit_preserved=1 overlap_unknown_preserved=1 owner_provenance_preserved=1");

    @(negedge clk);
    resolution_tx_index=1; resolution_fragment_index=1; resolution_command_id=4'd11; resolution_execution_epoch=4'd4; resolution_effect_id=4'd9; resolution_queue_epoch=4'd2; resolution_committed=0; resolution_valid=1; #1;
    if(!resolution_rejected) $fatal(1,"foreign queue epoch evidence accepted");
    @(posedge clk); #1; @(negedge clk); resolution_valid=0;
    $display("foreign_queue_epoch_evidence rejected=1 exact_queue_epoch_required=1");

    resolve(1'b1,1'b1,1'b0);
    if(!replay_authority_bitmap[3] || negative_receipt_bitmap[3]!==1'b1) $fatal(1,"negative evidence did not reopen exact younger fragment");
    $display("younger_overlap_negative tx1_f1=NOT_COMMITTED replay_authority=1 older_overlap_complete=1");

    issue(1'b1,1'b1); resolve(1'b1,1'b1,1'b1);
    if(fragment_states!==8'hAA || completion_receipt_bitmap!==4'b1111 || visible_owner_map!==8'hBC)
      $fatal(1,"final completion mismatch states=%h comp=%b owners=%h",fragment_states,completion_receipt_bitmap,visible_owner_map);
    $display("all_fragments_committed tx0=11 tx1=11 owners=BC completion_bitmap=1111");

    @(negedge clk); recovery_begin=1; #1; @(posedge clk); #1; @(negedge clk); recovery_begin=0;
    @(negedge clk); restore_valid=1; #1;
    if(!restore_accept) $fatal(1,"late restore not accepted");
    @(posedge clk); #1; @(negedge clk); restore_valid=0; #1;
    if(fragment_states!==8'hAA || visible_owner_map!==8'hBC || tx_pending!==2'b11) $fatal(1,"durable evidence failed to dominate stale queue checkpoint");
    $display("late_stale_queue_restore completion_receipts_win=1 owner_provenance_wins=1 durable_tx_slots_win=1");

    @(negedge clk);
    retire_tx_index=1; retire_command_id=4'd11; retire_execution_epoch=4'd4; retire_effect_id=4'd9; retire_queue_epoch=4'd3; retire_valid=1; #1;
    if(!retire_rejected) $fatal(1,"younger transaction retired before older transaction");
    @(posedge clk); #1; @(negedge clk); retire_valid=0;
    $display("younger_retire_before_older rejected=1 queue_order_preserved=1");

    retire_tx(1'b0);
    retire_tx(1'b1);
    if(tx_retired!==2'b11 || tx_pending!==2'b00) $fatal(1,"final queue retirement mismatch retired=%b pending=%b",tx_retired,tx_pending);
    $display("ordered_retire tx0_then_tx1=1 retired_bitmap=11");

    $display("CAPU_VCML_CONCURRENT_DMA_QUEUE_RECOVERY_V31_PASS");
    $finish;
  end
endmodule
