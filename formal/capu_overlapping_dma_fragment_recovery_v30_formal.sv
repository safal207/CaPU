module capu_overlapping_dma_fragment_recovery_v30_formal;
  logic clk;
  (* anyseq *) logic rst_n,recovery_begin;
  (* anyseq *) logic submit_valid; (* anyseq *) logic [1:0] submit_command_id,submit_execution_epoch,submit_effect_id;
  (* anyseq *) logic checkpoint_capture_valid;
  (* anyseq *) logic fragment_issue_valid; (* anyseq *) logic [1:0] fragment_issue_index; (* anyseq *) logic [1:0] fragment_issue_command_id,fragment_issue_execution_epoch,fragment_issue_effect_id;
  (* anyseq *) logic resolution_valid,resolution_committed; (* anyseq *) logic [1:0] resolution_fragment_index; (* anyseq *) logic [1:0] resolution_command_id,resolution_execution_epoch,resolution_effect_id;
  (* anyseq *) logic restore_valid;
  (* anyseq *) logic retire_valid; (* anyseq *) logic [1:0] retire_command_id,retire_execution_epoch,retire_effect_id;

  logic runtime_ready,submit_accept,command_pending;
  logic [1:0] live_command_id,live_execution_epoch,live_effect_id;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_command_pending;
  logic [1:0] checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id;
  logic [7:0] checkpoint_fragment_states,checkpoint_owner_map;
  logic [3:0] checkpoint_owner_valid;
  logic fragment_issue_accept,fragment_issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic [7:0] fragment_states;
  logic [3:0] replay_authority_bitmap,evidence_required_bitmap;
  logic [3:0] issue_receipt_bitmap,negative_receipt_bitmap,completion_receipt_bitmap;
  logic [1:0] receipt_command_id,receipt_execution_epoch,receipt_effect_id;
  logic [3:0] durable_owner_valid,visible_owner_valid;
  logic [7:0] durable_owner_map,visible_owner_map;
  logic all_fragments_committed,speculation_kill;

  localparam [1:0] U=2'b00, X=2'b01, C=2'b10, N=2'b11;

  capu_overlapping_dma_fragment_recovery_v30 #(.ID_WIDTH(2)) dut(.*);

  function automatic logic lane_in_fragment(input [1:0] frag,input integer lane);
    logic [3:0] mask;
    begin
      case(frag)
        2'd0: mask=4'b0011;
        2'd1: mask=4'b0110;
        2'd2: mask=4'b1100;
        default: mask=4'b1001;
      endcase
      lane_in_fragment=mask[lane];
    end
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

      for(i=0;i<4;i=i+1) begin
        if(runtime_ready && command_pending && fragment_states[i*2 +: 2]==C)
          assert(!replay_authority_bitmap[i] && !evidence_required_bitmap[i]);
        if(runtime_ready && command_pending && fragment_states[i*2 +: 2]==X)
          assert(!replay_authority_bitmap[i] && evidence_required_bitmap[i]);
        if(runtime_ready && command_pending && (fragment_states[i*2 +: 2]==U || fragment_states[i*2 +: 2]==N) && !recovery_begin && !restore_valid)
          assert(replay_authority_bitmap[i]);

        if(durable_owner_valid[i]) begin
          assert(completion_receipt_bitmap[durable_owner_map[i*2 +: 2]]);
          assert(lane_in_fragment(durable_owner_map[i*2 +: 2],i));
        end
      end

      if(fragment_issue_accept) begin
        assert(fragment_issue_command_id==live_command_id);
        assert(fragment_issue_execution_epoch==live_execution_epoch);
        assert(fragment_issue_effect_id==live_effect_id);
        assert(fragment_states[fragment_issue_index*2 +: 2]==U || fragment_states[fragment_issue_index*2 +: 2]==N);
      end

      if(resolution_accept) begin
        assert(fragment_states[resolution_fragment_index*2 +: 2]==X);
        assert(issue_receipt_bitmap[resolution_fragment_index]);
        assert(resolution_command_id==live_command_id);
        assert(resolution_execution_epoch==live_execution_epoch);
        assert(resolution_effect_id==live_effect_id);
      end

      if(retire_accept) begin
        assert(all_fragments_committed);
        assert(completion_receipt_bitmap==4'b1111);
        assert(replay_authority_bitmap==4'b0000);
      end
    end

    if(past_valid && $past(rst_n) && $past(fragment_issue_accept)) begin
      assert(fragment_states[$past(fragment_issue_index)*2 +: 2]==X);
      assert(issue_receipt_bitmap[$past(fragment_issue_index)]);
      assert(!negative_receipt_bitmap[$past(fragment_issue_index)]);
    end

    if(past_valid && $past(rst_n) && $past(resolution_accept)) begin
      assert(!issue_receipt_bitmap[$past(resolution_fragment_index)]);
      if($past(resolution_committed)) begin
        assert(fragment_states[$past(resolution_fragment_index)*2 +: 2]==C);
        assert(completion_receipt_bitmap[$past(resolution_fragment_index)]);
        assert(!replay_authority_bitmap[$past(resolution_fragment_index)]);
        for(i=0;i<4;i=i+1) begin
          if(lane_in_fragment($past(resolution_fragment_index),i)) begin
            assert(durable_owner_valid[i]);
            assert(durable_owner_map[i*2 +: 2]==$past(resolution_fragment_index));
            assert(visible_owner_valid[i]);
            assert(visible_owner_map[i*2 +: 2]==$past(resolution_fragment_index));
          end
        end
      end else begin
        assert(fragment_states[$past(resolution_fragment_index)*2 +: 2]==N);
        assert(negative_receipt_bitmap[$past(resolution_fragment_index)]);
        if(!recovery_begin && !restore_valid)
          assert(replay_authority_bitmap[$past(resolution_fragment_index)]);
      end
    end

    if(past_valid && $past(rst_n) && $past(recovery_begin)) begin
      assert(!runtime_ready && !command_pending);
      assert(fragment_states==8'h00);
      assert(issue_receipt_bitmap==$past(issue_receipt_bitmap));
      assert(negative_receipt_bitmap==$past(negative_receipt_bitmap));
      assert(completion_receipt_bitmap==$past(completion_receipt_bitmap));
      assert(durable_owner_valid==$past(durable_owner_valid));
      assert(durable_owner_map==$past(durable_owner_map));
    end

    if(past_valid && $past(rst_n) && $past(restore_accept) &&
       $past(receipt_command_id==checkpoint_command_id && receipt_execution_epoch==checkpoint_execution_epoch && receipt_effect_id==checkpoint_effect_id)) begin
      assert(runtime_ready && command_pending);
      for(i=0;i<4;i=i+1) begin
        if($past(completion_receipt_bitmap[i])) assert(fragment_states[i*2 +: 2]==C);
        else if($past(issue_receipt_bitmap[i])) assert(fragment_states[i*2 +: 2]==X);
        else if($past(negative_receipt_bitmap[i])) assert(fragment_states[i*2 +: 2]==N);
        if($past(durable_owner_valid[i])) begin
          assert(visible_owner_valid[i]);
          assert(visible_owner_map[i*2 +: 2]==$past(durable_owner_map[i*2 +: 2]));
        end
      end
    end

    cover(rst_n && submit_accept);
    cover(rst_n && fragment_issue_accept && fragment_issue_index==2'd0);
    cover(rst_n && fragment_issue_accept && fragment_issue_index==2'd2);
    cover(rst_n && completion_receipt_bitmap==4'b0101);
    cover(rst_n && evidence_required_bitmap==4'b1010 && completion_receipt_bitmap==4'b0101);
    cover(rst_n && resolution_accept && !resolution_committed);
    cover(rst_n && resolution_accept && resolution_committed && resolution_fragment_index==2'd3);
    cover(rst_n && durable_owner_valid==4'b1111 && durable_owner_map==8'hE3);
    cover(rst_n && all_fragments_committed && durable_owner_map==8'hD7);
    cover(rst_n && restore_accept && completion_receipt_bitmap==4'b1111);
    cover(rst_n && retire_accept);
  end
endmodule
