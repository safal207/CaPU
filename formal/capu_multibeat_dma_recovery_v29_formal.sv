module capu_multibeat_dma_recovery_v29_formal;
  logic clk;
  (* anyseq *) logic rst_n,recovery_begin;
  (* anyseq *) logic submit_valid; (* anyseq *) logic [1:0] submit_command_id,submit_execution_epoch,submit_effect_id;
  (* anyseq *) logic checkpoint_capture_valid;
  (* anyseq *) logic beat_issue_valid; (* anyseq *) logic [1:0] beat_issue_index; (* anyseq *) logic [1:0] beat_issue_command_id,beat_issue_execution_epoch,beat_issue_effect_id;
  (* anyseq *) logic resolution_valid,resolution_committed; (* anyseq *) logic [1:0] resolution_beat_index; (* anyseq *) logic [1:0] resolution_command_id,resolution_execution_epoch,resolution_effect_id;
  (* anyseq *) logic restore_valid;
  (* anyseq *) logic retire_valid; (* anyseq *) logic [1:0] retire_command_id,retire_execution_epoch,retire_effect_id;

  logic runtime_ready,submit_accept,submit_rejected,command_pending;
  logic [1:0] live_command_id,live_execution_epoch,live_effect_id;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_command_pending;
  logic [1:0] checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id;
  logic [7:0] checkpoint_beat_states;
  logic beat_issue_accept,beat_issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic [7:0] beat_states; logic [3:0] evidence_required_bitmap,beat_replay_authority;
  logic [3:0] issue_receipt_bitmap,negative_receipt_bitmap,completion_receipt_bitmap;
  logic [1:0] receipt_command_id,receipt_execution_epoch,receipt_effect_id;
  logic all_beats_committed,speculation_kill;

  localparam logic [1:0] UNISSUED=2'b00, UNKNOWN=2'b01, COMMITTED=2'b10, NOT_COMMITTED=2'b11;

  capu_multibeat_dma_recovery_v29 #(
    .CMD_WIDTH(2),.EXEC_EPOCH_WIDTH(2),.EFFECT_WIDTH(2)
  ) dut(.*);

  function automatic logic [1:0] state_at(input logic [7:0] states,input logic [1:0] idx);
    case(idx)
      2'd0: state_at=states[1:0];
      2'd1: state_at=states[3:2];
      2'd2: state_at=states[5:4];
      default: state_at=states[7:6];
    endcase
  endfunction

  logic receipt_any,receipt_match_live,receipt_match_checkpoint;
  assign receipt_any=|issue_receipt_bitmap || |negative_receipt_bitmap || |completion_receipt_bitmap;
  assign receipt_match_live=receipt_any && command_pending && receipt_command_id==live_command_id && receipt_execution_epoch==live_execution_epoch && receipt_effect_id==live_effect_id;
  assign receipt_match_checkpoint=receipt_any && checkpoint_valid && checkpoint_command_pending && receipt_command_id==checkpoint_command_id && receipt_execution_epoch==checkpoint_execution_epoch && receipt_effect_id==checkpoint_effect_id;

  logic past_valid=0;
  integer i;
  always @(posedge clk) begin
    past_valid <= 1;
    if(!past_valid) assume(!rst_n); else assume(rst_n);

    if(rst_n) begin
      assert(!(submit_accept && submit_rejected));
      assert(!(beat_issue_accept && beat_issue_rejected));
      assert(!(resolution_accept && resolution_rejected));
      assert(!(restore_accept && restore_rejected));
      assert(!(retire_accept && retire_rejected));

      assert((issue_receipt_bitmap & negative_receipt_bitmap)==0);
      assert((issue_receipt_bitmap & completion_receipt_bitmap)==0);
      assert((negative_receipt_bitmap & completion_receipt_bitmap)==0);

      for(i=0;i<4;i=i+1) begin
        if(evidence_required_bitmap[i]) begin
          assert(state_at(beat_states,i[1:0])==UNKNOWN);
          assert(!beat_replay_authority[i]);
        end
        if(receipt_match_live && issue_receipt_bitmap[i]) begin
          assert(state_at(beat_states,i[1:0])==UNKNOWN);
          assert(evidence_required_bitmap[i]);
          assert(!beat_replay_authority[i]);
        end
        if(receipt_match_live && negative_receipt_bitmap[i]) begin
          assert(state_at(beat_states,i[1:0])==NOT_COMMITTED);
        end
        if(receipt_match_live && completion_receipt_bitmap[i]) begin
          assert(state_at(beat_states,i[1:0])==COMMITTED);
          assert(!beat_replay_authority[i]);
        end
      end

      if(beat_replay_authority[1]) assert(beat_states[1:0]==COMMITTED);
      if(beat_replay_authority[2]) begin assert(beat_states[1:0]==COMMITTED); assert(beat_states[3:2]==COMMITTED); end
      if(beat_replay_authority[3]) begin assert(beat_states[1:0]==COMMITTED); assert(beat_states[3:2]==COMMITTED); assert(beat_states[5:4]==COMMITTED); end

      if(beat_issue_accept) begin
        assert(beat_issue_command_id==live_command_id);
        assert(beat_issue_execution_epoch==live_execution_epoch);
        assert(beat_issue_effect_id==live_effect_id);
        assert(beat_replay_authority[beat_issue_index]);
        assert(state_at(beat_states,beat_issue_index)==UNISSUED || state_at(beat_states,beat_issue_index)==NOT_COMMITTED);
      end

      if(resolution_accept) begin
        assert(receipt_match_live);
        assert(resolution_command_id==live_command_id);
        assert(resolution_execution_epoch==live_execution_epoch);
        assert(resolution_effect_id==live_effect_id);
        assert(state_at(beat_states,resolution_beat_index)==UNKNOWN);
        assert(issue_receipt_bitmap[resolution_beat_index]);
      end

      if(retire_accept) begin
        assert(all_beats_committed);
        assert(completion_receipt_bitmap==4'b1111);
        assert(receipt_match_live);
      end
      if(all_beats_committed) assert(beat_replay_authority==0);
    end

    if(past_valid && $past(rst_n) && $past(beat_issue_accept)) begin
      case($past(beat_issue_index))
        2'd0: begin assert(beat_states[1:0]==UNKNOWN); assert(issue_receipt_bitmap[0]); assert(!negative_receipt_bitmap[0]); end
        2'd1: begin assert(beat_states[3:2]==UNKNOWN); assert(issue_receipt_bitmap[1]); assert(!negative_receipt_bitmap[1]); end
        2'd2: begin assert(beat_states[5:4]==UNKNOWN); assert(issue_receipt_bitmap[2]); assert(!negative_receipt_bitmap[2]); end
        2'd3: begin assert(beat_states[7:6]==UNKNOWN); assert(issue_receipt_bitmap[3]); assert(!negative_receipt_bitmap[3]); end
      endcase
    end

    if(past_valid && $past(rst_n) && $past(resolution_accept)) begin
      if($past(resolution_committed)) begin
        case($past(resolution_beat_index))
          2'd0: begin assert(beat_states[1:0]==COMMITTED); assert(completion_receipt_bitmap[0]); assert(!issue_receipt_bitmap[0]); end
          2'd1: begin assert(beat_states[3:2]==COMMITTED); assert(completion_receipt_bitmap[1]); assert(!issue_receipt_bitmap[1]); end
          2'd2: begin assert(beat_states[5:4]==COMMITTED); assert(completion_receipt_bitmap[2]); assert(!issue_receipt_bitmap[2]); end
          2'd3: begin assert(beat_states[7:6]==COMMITTED); assert(completion_receipt_bitmap[3]); assert(!issue_receipt_bitmap[3]); end
        endcase
      end else begin
        case($past(resolution_beat_index))
          2'd0: begin assert(beat_states[1:0]==NOT_COMMITTED); assert(negative_receipt_bitmap[0]); assert(!issue_receipt_bitmap[0]); end
          2'd1: begin assert(beat_states[3:2]==NOT_COMMITTED); assert(negative_receipt_bitmap[1]); assert(!issue_receipt_bitmap[1]); end
          2'd2: begin assert(beat_states[5:4]==NOT_COMMITTED); assert(negative_receipt_bitmap[2]); assert(!issue_receipt_bitmap[2]); end
          2'd3: begin assert(beat_states[7:6]==NOT_COMMITTED); assert(negative_receipt_bitmap[3]); assert(!issue_receipt_bitmap[3]); end
        endcase
      end
    end

    if(past_valid && $past(rst_n) && $past(recovery_begin)) begin
      assert(!runtime_ready);
      assert(!command_pending);
      assert(beat_states==8'b0);
      assert(checkpoint_valid==$past(checkpoint_valid));
      assert(checkpoint_beat_states==$past(checkpoint_beat_states));
      assert(issue_receipt_bitmap==$past(issue_receipt_bitmap));
      assert(negative_receipt_bitmap==$past(negative_receipt_bitmap));
      assert(completion_receipt_bitmap==$past(completion_receipt_bitmap));
      assert(receipt_command_id==$past(receipt_command_id));
      assert(receipt_execution_epoch==$past(receipt_execution_epoch));
      assert(receipt_effect_id==$past(receipt_effect_id));
    end

    if(past_valid && $past(rst_n) && $past(restore_accept)) begin
      assert(runtime_ready && command_pending);
      for(i=0;i<4;i=i+1) begin
        if($past(receipt_match_checkpoint && completion_receipt_bitmap[i]))
          assert(state_at(beat_states,i[1:0])==COMMITTED);
        else if($past(receipt_match_checkpoint && issue_receipt_bitmap[i]))
          assert(state_at(beat_states,i[1:0])==UNKNOWN);
        else if($past(receipt_match_checkpoint && negative_receipt_bitmap[i]))
          assert(state_at(beat_states,i[1:0])==NOT_COMMITTED);
        else
          assert(state_at(beat_states,i[1:0])==state_at($past(checkpoint_beat_states),i[1:0]));
      end
    end

    cover(rst_n && submit_accept);
    cover(rst_n && beat_issue_accept && beat_issue_index==0);
    cover(rst_n && resolution_accept && resolution_committed && resolution_beat_index==0);
    cover(rst_n && beat_issue_accept && beat_issue_index==1);
    cover(rst_n && beat_issue_accept && beat_issue_index==2);
    cover(rst_n && checkpoint_capture_accept && beat_states[1:0]==COMMITTED && beat_states[3:2]==COMMITTED && beat_states[5:4]==UNKNOWN && beat_states[7:6]==UNISSUED);
    cover(rst_n && resolution_accept && !resolution_committed && resolution_beat_index==2);
    cover(rst_n && recovery_begin && negative_receipt_bitmap[2]);
    cover(rst_n && restore_accept && negative_receipt_bitmap[2] && checkpoint_beat_states[5:4]==UNKNOWN);
    cover(rst_n && beat_issue_accept && beat_issue_index==3);
    cover(rst_n && retire_accept);
  end
endmodule
