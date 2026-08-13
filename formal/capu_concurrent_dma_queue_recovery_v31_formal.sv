module capu_concurrent_dma_queue_recovery_v31_formal;
  logic clk;
  (* anyseq *) logic rst_n,recovery_begin;
  (* anyseq *) logic submit_valid,submit_tx_index;
  (* anyseq *) logic [1:0] submit_command_id,submit_execution_epoch,submit_effect_id,submit_queue_epoch;
  (* anyseq *) logic checkpoint_capture_valid;
  (* anyseq *) logic fragment_issue_valid,fragment_issue_tx_index,fragment_issue_index;
  (* anyseq *) logic [1:0] fragment_issue_command_id,fragment_issue_execution_epoch,fragment_issue_effect_id,fragment_issue_queue_epoch;
  (* anyseq *) logic resolution_valid,resolution_committed,resolution_tx_index,resolution_fragment_index;
  (* anyseq *) logic [1:0] resolution_command_id,resolution_execution_epoch,resolution_effect_id,resolution_queue_epoch;
  (* anyseq *) logic restore_valid;
  (* anyseq *) logic retire_valid,retire_tx_index;
  (* anyseq *) logic [1:0] retire_command_id,retire_execution_epoch,retire_effect_id,retire_queue_epoch;

  logic runtime_ready,submit_accept;
  logic [1:0] tx_pending,tx_retired;
  logic [1:0] live_queue_epoch;
  logic [3:0] live_command_ids,live_execution_epochs,live_effect_ids;
  logic checkpoint_capture_accept,checkpoint_valid;
  logic [1:0] checkpoint_tx_pending,checkpoint_tx_retired,checkpoint_queue_epoch;
  logic [3:0] checkpoint_command_ids,checkpoint_execution_epochs,checkpoint_effect_ids;
  logic [7:0] checkpoint_fragment_states,checkpoint_owner_map;
  logic [3:0] checkpoint_owner_valid;
  logic fragment_issue_accept,fragment_issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic [7:0] fragment_states;
  logic [3:0] replay_authority_bitmap,evidence_required_bitmap,queue_blocked_bitmap;
  logic [3:0] issue_receipt_bitmap,negative_receipt_bitmap,completion_receipt_bitmap;
  logic [3:0] durable_owner_valid,visible_owner_valid;
  logic [7:0] durable_owner_map,visible_owner_map;
  logic all_tx0_fragments_committed,all_tx1_fragments_committed,speculation_kill;

  localparam [1:0] U=2'b00, X=2'b01, C=2'b10, N=2'b11;

  capu_concurrent_dma_queue_recovery_v31 #(.ID_WIDTH(2)) dut(.*);

  function automatic logic [3:0] mask(input [1:0] frag);
    begin
      case(frag)
        2'd0: mask=4'b0011;
        2'd1: mask=4'b0100;
        2'd2: mask=4'b1000;
        default: mask=4'b0110;
      endcase
    end
  endfunction

  function automatic logic lane_in_fragment(input [1:0] frag,input integer lane);
    begin lane_in_fragment=mask(frag)[lane]; end
  endfunction

  logic past_valid=0;
  integer i;
  always @(posedge clk) begin
    past_valid <= 1;
    if(!past_valid) assume(!rst_n); else assume(rst_n);

    if(rst_n) begin
      assert(!(fragment_issue_accept && fragment_issue_rejected));
      assert(!(resolution_accept && resolution_rejected));
      assert(!(restore_accept && restore_rejected));
      assert(!(retire_accept && retire_rejected));
      assert(!(tx_retired[1] && !tx_retired[0]));

      for(i=0;i<4;i=i+1) begin
        if(fragment_states[i*2 +: 2]==C) begin
          assert(!replay_authority_bitmap[i]);
          assert(!evidence_required_bitmap[i]);
          assert(completion_receipt_bitmap[i]);
        end
        if(fragment_states[i*2 +: 2]==X) begin
          assert(!replay_authority_bitmap[i]);
          assert(evidence_required_bitmap[i] || !runtime_ready || !tx_pending[i/2]);
          assert(issue_receipt_bitmap[i]);
        end
        if(durable_owner_valid[i]) begin
          assert(completion_receipt_bitmap[durable_owner_map[i*2 +: 2]]);
          assert(lane_in_fragment(durable_owner_map[i*2 +: 2],i));
        end
      end

      if(!tx_retired[0] && (fragment_states[1:0]!=C || fragment_states[3:2]!=C)) begin
        assert(queue_blocked_bitmap[3]);
        assert(!replay_authority_bitmap[3]);
      end

      if(replay_authority_bitmap[3])
        assert(tx_retired[0] || (fragment_states[1:0]==C && fragment_states[3:2]==C));

      if(fragment_issue_accept && fragment_issue_tx_index && fragment_issue_index)
        assert(!queue_blocked_bitmap[3]);

      if(retire_accept && retire_tx_index)
        assert(tx_retired[0] && all_tx1_fragments_committed && completion_receipt_bitmap[3:2]==2'b11);

      if(retire_accept && !retire_tx_index)
        assert(all_tx0_fragments_committed && completion_receipt_bitmap[1:0]==2'b11);
    end

    if(past_valid && $past(rst_n) && $past(fragment_issue_accept)) begin
      assert(fragment_states[{$past(fragment_issue_tx_index),$past(fragment_issue_index)}*2 +: 2]==X);
      assert(issue_receipt_bitmap[{$past(fragment_issue_tx_index),$past(fragment_issue_index)}]);
    end

    if(past_valid && $past(rst_n) && $past(resolution_accept)) begin
      assert(!issue_receipt_bitmap[{$past(resolution_tx_index),$past(resolution_fragment_index)}]);
      if($past(resolution_committed)) begin
        assert(fragment_states[{$past(resolution_tx_index),$past(resolution_fragment_index)}*2 +: 2]==C);
        assert(completion_receipt_bitmap[{$past(resolution_tx_index),$past(resolution_fragment_index)}]);
      end else begin
        assert(fragment_states[{$past(resolution_tx_index),$past(resolution_fragment_index)}*2 +: 2]==N);
        assert(negative_receipt_bitmap[{$past(resolution_tx_index),$past(resolution_fragment_index)}]);
      end
    end

    if(past_valid && $past(rst_n) && $past(recovery_begin)) begin
      assert(!runtime_ready && tx_pending==2'b00 && fragment_states==8'h00);
      assert(issue_receipt_bitmap==$past(issue_receipt_bitmap));
      assert(negative_receipt_bitmap==$past(negative_receipt_bitmap));
      assert(completion_receipt_bitmap==$past(completion_receipt_bitmap));
      assert(durable_owner_valid==$past(durable_owner_valid));
      assert(durable_owner_map==$past(durable_owner_map));
      assert(tx_retired==$past(tx_retired));
    end

    if(past_valid && $past(rst_n) && $past(restore_accept)) begin
      assert(runtime_ready);
      for(i=0;i<4;i=i+1) begin
        if($past(completion_receipt_bitmap[i])) assert(fragment_states[i*2 +: 2]==C);
        else if($past(issue_receipt_bitmap[i])) assert(fragment_states[i*2 +: 2]==X);
        else if($past(negative_receipt_bitmap[i])) assert(fragment_states[i*2 +: 2]==N);
        if($past(durable_owner_valid[i])) begin
          assert(visible_owner_valid[i]);
          assert(visible_owner_map[i*2 +: 2]==$past(durable_owner_map[i*2 +: 2]));
        end
      end
      if($past(tx_retired[0])) assert(!tx_pending[0]);
      if($past(tx_retired[1])) assert(!tx_pending[1]);
    end

    if(past_valid && $past(rst_n) && $past(retire_accept)) begin
      assert(tx_retired[$past(retire_tx_index)]);
      assert(!tx_pending[$past(retire_tx_index)]);
    end

    cover(rst_n && submit_accept && !submit_tx_index);
    cover(rst_n && submit_accept && submit_tx_index);
    cover(rst_n && fragment_issue_accept && fragment_issue_tx_index && !fragment_issue_index && fragment_states[1:0]==X);
    cover(rst_n && completion_receipt_bitmap[2] && fragment_states[1:0]==X);
    cover(rst_n && queue_blocked_bitmap[3]);
    cover(rst_n && all_tx0_fragments_committed && replay_authority_bitmap[3]);
    cover(rst_n && resolution_accept && resolution_tx_index && resolution_fragment_index && !resolution_committed);
    cover(rst_n && completion_receipt_bitmap==4'b1111 && durable_owner_map==8'hBC);
    cover(rst_n && restore_accept && completion_receipt_bitmap==4'b1111);
    cover(rst_n && retire_accept && !retire_tx_index);
    cover(rst_n && retire_accept && retire_tx_index);
  end
endmodule
