module capu_dma_completion_uncertainty_v27_formal;
  logic clk;
  (* anyseq *) logic rst_n,recovery_begin;
  (* anyseq *) logic submit_valid; (* anyseq *) logic [3:0] submit_command_id,submit_execution_epoch,submit_effect_id;
  (* anyseq *) logic checkpoint_capture_valid;
  (* anyseq *) logic dma_issue_valid; (* anyseq *) logic [3:0] dma_issue_command_id,dma_issue_execution_epoch,dma_issue_effect_id;
  (* anyseq *) logic resolution_valid,resolution_committed; (* anyseq *) logic [3:0] resolution_command_id,resolution_execution_epoch,resolution_effect_id;
  (* anyseq *) logic restore_valid;
  (* anyseq *) logic retire_valid; (* anyseq *) logic [3:0] retire_command_id,retire_execution_epoch,retire_effect_id;

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

  logic past_valid=0;
  always @(posedge clk) begin
    past_valid <= 1;
    if(!past_valid) assume(!rst_n);
    else assume(rst_n);

    if(rst_n) begin
      assert(!(submit_accept && submit_rejected));
      assert(!(dma_issue_accept && dma_issue_rejected));
      assert(!(resolution_accept && resolution_rejected));
      assert(!(restore_accept && restore_rejected));
      assert(!(retire_accept && retire_rejected));

      if(completion_state==2'b01) begin
        assert(evidence_required);
        assert(!dma_replay_authority);
        assert(!retire_accept);
      end
      if(evidence_required) begin
        assert(completion_state==2'b01);
        assert(!dma_replay_authority);
        assert(!retire_accept);
      end
      if(dma_replay_authority) begin
        assert(runtime_ready && command_pending);
        assert(completion_state==2'b00);
        assert(!dma_issued && !evidence_required);
        assert(!issue_receipt_valid);
      end
      if(dma_issue_accept) begin
        assert(command_pending);
        assert(completion_state==2'b00);
        assert(dma_issue_command_id==live_command_id);
        assert(dma_issue_execution_epoch==live_execution_epoch);
        assert(dma_issue_effect_id==live_effect_id);
      end
      if(resolution_accept) begin
        assert(completion_state==2'b01 && evidence_required);
        assert(issue_receipt_valid);
        assert(resolution_command_id==live_command_id);
        assert(resolution_execution_epoch==live_execution_epoch);
        assert(resolution_effect_id==live_effect_id);
        assert(issue_receipt_command_id==live_command_id);
        assert(issue_receipt_execution_epoch==live_execution_epoch);
        assert(issue_receipt_effect_id==live_effect_id);
      end
      if(resolution_valid && command_pending &&
         (resolution_command_id!=live_command_id || resolution_execution_epoch!=live_execution_epoch || resolution_effect_id!=live_effect_id))
        assert(!resolution_accept);
      if(retire_accept) begin
        assert(completion_state==2'b10);
        assert(completion_receipt_valid);
        assert(completion_receipt_command_id==live_command_id);
        assert(completion_receipt_execution_epoch==live_execution_epoch);
        assert(completion_receipt_effect_id==live_effect_id);
      end
      if(effect_spent) begin
        assert(completion_state==2'b10);
        assert(!dma_replay_authority);
      end
      if(completion_receipt_valid && command_pending &&
         completion_receipt_command_id==live_command_id &&
         completion_receipt_execution_epoch==live_execution_epoch &&
         completion_receipt_effect_id==live_effect_id)
        assert(!dma_replay_authority);
    end

    if(past_valid && $past(rst_n) && $past(dma_issue_accept)) begin
      assert(dma_issued);
      assert(completion_state==2'b01);
      assert(evidence_required);
      assert(issue_receipt_valid);
    end

    if(past_valid && $past(rst_n) && $past(resolution_accept)) begin
      assert(!evidence_required);
      assert(!dma_issued);
      assert(!issue_receipt_valid);
      if($past(resolution_committed)) begin
        assert(completion_state==2'b10);
        assert(completion_receipt_valid);
        assert(!dma_replay_authority);
      end else begin
        assert(completion_state==2'b00);
        assert(!completion_receipt_valid);
        if(!recovery_begin && !restore_valid)
          assert(dma_replay_authority);
      end
    end

    if(past_valid && $past(rst_n) && $past(recovery_begin)) begin
      assert(!runtime_ready);
      assert(!command_pending);
      assert(!dma_issued);
      assert(completion_state==2'b00);
      assert(!evidence_required);
      assert(checkpoint_valid==$past(checkpoint_valid));
      assert(issue_receipt_valid==$past(issue_receipt_valid));
      assert(completion_receipt_valid==$past(completion_receipt_valid));
    end

    if(past_valid && $past(rst_n) && $past(restore_accept) &&
       $past(issue_receipt_valid && checkpoint_valid && checkpoint_command_pending &&
             issue_receipt_command_id==checkpoint_command_id &&
             issue_receipt_execution_epoch==checkpoint_execution_epoch &&
             issue_receipt_effect_id==checkpoint_effect_id) &&
       !$past(completion_receipt_valid &&
              completion_receipt_command_id==checkpoint_command_id &&
              completion_receipt_execution_epoch==checkpoint_execution_epoch &&
              completion_receipt_effect_id==checkpoint_effect_id)) begin
      assert(runtime_ready && command_pending);
      assert(completion_state==2'b01);
      assert(evidence_required);
      assert(!dma_replay_authority);
    end

    if(past_valid && $past(rst_n) && $past(restore_accept) &&
       $past(completion_receipt_valid && checkpoint_valid && checkpoint_command_pending &&
             completion_receipt_command_id==checkpoint_command_id &&
             completion_receipt_execution_epoch==checkpoint_execution_epoch &&
             completion_receipt_effect_id==checkpoint_effect_id)) begin
      assert(runtime_ready && command_pending);
      assert(completion_state==2'b10);
      assert(!evidence_required);
      assert(!dma_replay_authority);
    end

    cover(rst_n && submit_accept);
    cover(rst_n && checkpoint_capture_accept);
    cover(rst_n && dma_issue_accept);
    cover(rst_n && recovery_begin && issue_receipt_valid);
    cover(rst_n && restore_accept && issue_receipt_valid);
    cover(rst_n && resolution_accept && !resolution_committed);
    cover(rst_n && resolution_accept && resolution_committed);
    cover(rst_n && retire_accept);
    cover(rst_n && restore_accept && completion_receipt_valid);
  end
endmodule
