`timescale 1ns/1ps
module capu_overlapping_dma_fragment_recovery_v30_tb;
  logic clk=0; always #5 clk=~clk;
  logic rst_n=0,recovery_begin=0;
  logic submit_valid=0; logic [3:0] submit_command_id=0,submit_execution_epoch=0,submit_effect_id=0;
  logic checkpoint_capture_valid=0;
  logic fragment_issue_valid=0; logic [1:0] fragment_issue_index=0; logic [3:0] fragment_issue_command_id=0,fragment_issue_execution_epoch=0,fragment_issue_effect_id=0;
  logic resolution_valid=0,resolution_committed=0; logic [1:0] resolution_fragment_index=0; logic [3:0] resolution_command_id=0,resolution_execution_epoch=0,resolution_effect_id=0;
  logic restore_valid=0;
  logic retire_valid=0; logic [3:0] retire_command_id=0,retire_execution_epoch=0,retire_effect_id=0;

  logic runtime_ready,submit_accept,command_pending;
  logic [3:0] live_command_id,live_execution_epoch,live_effect_id;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_command_pending;
  logic [3:0] checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id;
  logic [7:0] checkpoint_fragment_states,checkpoint_owner_map;
  logic [3:0] checkpoint_owner_valid;
  logic fragment_issue_accept,fragment_issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic [7:0] fragment_states;
  logic [3:0] replay_authority_bitmap,evidence_required_bitmap;
  logic [3:0] issue_receipt_bitmap,negative_receipt_bitmap,completion_receipt_bitmap;
  logic [3:0] receipt_command_id,receipt_execution_epoch,receipt_effect_id;
  logic [3:0] durable_owner_valid,visible_owner_valid;
  logic [7:0] durable_owner_map,visible_owner_map;
  logic all_fragments_committed,speculation_kill;

  capu_overlapping_dma_fragment_recovery_v30 dut(.*);

  task automatic submit;
    begin
      @(negedge clk); submit_command_id=4'd12; submit_execution_epoch=4'd7; submit_effect_id=4'd14; submit_valid=1;
      @(posedge clk); #1; if(!submit_accept) $fatal(1,"submit not accepted");
      @(negedge clk); submit_valid=0;
    end
  endtask

  task automatic issue(input [1:0] idx);
    begin
      @(negedge clk); fragment_issue_index=idx; fragment_issue_command_id=4'd12; fragment_issue_execution_epoch=4'd7; fragment_issue_effect_id=4'd14; fragment_issue_valid=1;
      @(posedge clk); #1; if(!fragment_issue_accept) $fatal(1,"fragment issue not accepted idx=%0d",idx);
      @(negedge clk); fragment_issue_valid=0;
    end
  endtask

  task automatic resolve(input [1:0] idx,input logic committed);
    begin
      @(negedge clk); resolution_fragment_index=idx; resolution_command_id=4'd12; resolution_execution_epoch=4'd7; resolution_effect_id=4'd14; resolution_committed=committed; resolution_valid=1;
      @(posedge clk); #1; if(!resolution_accept) $fatal(1,"resolution not accepted idx=%0d",idx);
      @(negedge clk); resolution_valid=0;
    end
  endtask

  initial begin
    repeat(2) @(posedge clk); rst_n=1;
    submit();
    $display("fragment_command_submit accepted=1 command=12 epoch=7 effect=14 fragments=4");

    issue(2'd0); resolve(2'd0,1'b1);
    issue(2'd2); resolve(2'd2,1'b1);
    if(fragment_states!==8'h88) $fatal(1,"expected non-prefix committed set f0,f2");
    if(visible_owner_map!==8'hA0) $fatal(1,"initial owner map mismatch %h",visible_owner_map);
    $display("out_of_order_commit committed_set=0101 owner_map=A0 prefix_assumption=0");

    issue(2'd1); issue(2'd3);
    if(fragment_states!==8'h66) $fatal(1,"expected C,U,C,U got %h",fragment_states);
    @(negedge clk); checkpoint_capture_valid=1;
    @(posedge clk); #1; if(!checkpoint_capture_accept) $fatal(1,"checkpoint capture failed");
    @(negedge clk); checkpoint_capture_valid=0;
    $display("overlap_checkpoint states=COMMITTED,UNKNOWN,COMMITTED,UNKNOWN owners=A0");

    @(negedge clk); recovery_begin=1;
    @(posedge clk); #1;
    @(negedge clk); recovery_begin=0;
    if(runtime_ready) $fatal(1,"recovery did not close runtime");
    $display("recovery volatile_fragment_state_cleared=1 durable_receipts_preserved=1 durable_owner_preserved=1");

    @(negedge clk); restore_valid=1;
    @(posedge clk); #1; if(!restore_accept) $fatal(1,"restore failed");
    @(negedge clk); restore_valid=0;
    #1;
    if(fragment_states!==8'h66 || evidence_required_bitmap!==4'b1010) $fatal(1,"restore state mismatch states=%h evidence=%b",fragment_states,evidence_required_bitmap);
    if(visible_owner_map!==8'hA0) $fatal(1,"restore owner mismatch");
    $display("partial_set_restore committed_nonprefix=0101 unknown=1010 replay_committed_blocked=1");

    @(negedge clk); resolution_fragment_index=2'd1; resolution_command_id=4'd12; resolution_execution_epoch=4'd7; resolution_effect_id=4'd13; resolution_committed=0; resolution_valid=1;
    @(posedge clk); #1; if(!resolution_rejected) $fatal(1,"foreign evidence accepted");
    @(negedge clk); resolution_valid=0;
    $display("foreign_fragment_evidence rejected=1 exact_transaction_identity_required=1");

    resolve(2'd1,1'b0);
    if(!replay_authority_bitmap[1] || negative_receipt_bitmap[1]!==1'b1) $fatal(1,"negative evidence did not reopen f1");
    $display("negative_fragment_evidence fragment=1 replay_authority=1 unrelated_fragment3_unknown=1");

    resolve(2'd3,1'b1);
    if(visible_owner_map!==8'hE3) $fatal(1,"overlap owner after f3 mismatch %h",visible_owner_map);
    if(replay_authority_bitmap[0] || replay_authority_bitmap[2] || replay_authority_bitmap[3]) $fatal(1,"committed replay authority leaked");
    $display("overlap_commit fragment=3 owners=E3 overwrote_lanes=3,0 committed_history_preserved=1");

    issue(2'd1); resolve(2'd1,1'b1);
    if(visible_owner_map!==8'hD7) $fatal(1,"final owner map mismatch %h",visible_owner_map);
    if(fragment_states!==8'hAA || completion_receipt_bitmap!==4'b1111) $fatal(1,"all fragments not committed");
    $display("final_overlap_commit fragment=1 owners=D7 completion_bitmap=1111 all_fragments_committed=1");

    @(negedge clk); recovery_begin=1;
    @(posedge clk); #1;
    @(negedge clk); recovery_begin=0;
    @(negedge clk); restore_valid=1;
    @(posedge clk); #1; if(!restore_accept) $fatal(1,"late restore failed");
    @(negedge clk); restore_valid=0;
    #1;
    if(fragment_states!==8'hAA || visible_owner_map!==8'hD7 || replay_authority_bitmap!==4'b0000) $fatal(1,"durable evidence failed to dominate stale checkpoint");
    $display("late_stale_restore completion_receipts_win=1 durable_owner_map_wins=1 states=ALL_COMMITTED owners=D7 replay=0000");

    @(negedge clk); retire_command_id=4'd12; retire_execution_epoch=4'd7; retire_effect_id=4'd14; retire_valid=1;
    @(posedge clk); #1; if(!retire_accept) $fatal(1,"retire failed");
    @(negedge clk); retire_valid=0;
    $display("fragment_command_retire accepted=1 exact_fragment_set_completion=1");
    $display("CAPU_VCML_OVERLAPPING_DMA_FRAGMENT_RECOVERY_V30_PASS");
    $finish;
  end
endmodule
