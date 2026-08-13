module capu_accelerator_dma_recovery_v26_formal;
  logic clk;
  (* anyseq *) logic rst_n,recovery_begin;
  (* anyseq *) logic submit_valid; (* anyseq *) logic [3:0] submit_command_id,submit_execution_epoch,submit_effect_id;
  (* anyseq *) logic checkpoint_capture_valid;
  (* anyseq *) logic dma_issue_valid; (* anyseq *) logic [3:0] dma_issue_command_id,dma_issue_execution_epoch,dma_issue_effect_id;
  (* anyseq *) logic dma_commit_valid; (* anyseq *) logic [3:0] dma_commit_command_id,dma_commit_execution_epoch,dma_commit_effect_id;
  (* anyseq *) logic restore_valid;
  (* anyseq *) logic reconcile_valid; (* anyseq *) logic [3:0] reconcile_command_id,reconcile_execution_epoch,reconcile_effect_id;
  (* anyseq *) logic retire_valid; (* anyseq *) logic [3:0] retire_command_id,retire_execution_epoch,retire_effect_id;

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

  logic past_valid=0;
  always @(posedge clk) begin
    past_valid <= 1;
    if(!past_valid) assume(!rst_n);
    else assume(rst_n);

    if(rst_n) begin
      assert(!(submit_accept && submit_rejected));
      assert(!(dma_issue_accept && dma_issue_rejected));
      assert(!(dma_commit_accept && dma_commit_rejected));
      assert(!(restore_accept && restore_rejected));
      assert(!(reconcile_accept && reconcile_rejected));
      assert(!(retire_accept && retire_rejected));

      if(dma_issue_accept) begin
        assert(command_pending && runtime_ready && dma_replay_authority);
        assert(dma_issue_command_id==live_command_id);
        assert(dma_issue_execution_epoch==live_execution_epoch);
        assert(dma_issue_effect_id==live_effect_id);
        assert(!dma_issued && !effect_spent && !reconcile_required);
        assert(!(receipt_valid && receipt_command_id==live_command_id &&
                 receipt_execution_epoch==live_execution_epoch && receipt_effect_id==live_effect_id));
      end

      if(dma_commit_accept) begin
        assert(command_pending && runtime_ready && dma_issued);
        assert(!effect_spent && !receipt_valid && !reconcile_required);
        assert(dma_commit_command_id==live_command_id);
        assert(dma_commit_execution_epoch==live_execution_epoch);
        assert(dma_commit_effect_id==live_effect_id);
      end

      if(receipt_valid && command_pending &&
         receipt_command_id==live_command_id &&
         receipt_execution_epoch==live_execution_epoch &&
         receipt_effect_id==live_effect_id)
        assert(!dma_replay_authority);

      if(reconcile_required) begin
        assert(!dma_replay_authority);
        if(dma_issue_valid && dma_issue_command_id==live_command_id &&
           dma_issue_execution_epoch==live_execution_epoch && dma_issue_effect_id==live_effect_id)
          assert(!dma_issue_accept);
      end

      if(reconcile_accept) begin
        assert(reconcile_required && receipt_valid && command_pending);
        assert(reconcile_command_id==live_command_id);
        assert(reconcile_execution_epoch==live_execution_epoch);
        assert(reconcile_effect_id==live_effect_id);
      end

      if(retire_accept) begin
        assert(command_pending && effect_spent && !reconcile_required);
        assert(retire_command_id==live_command_id);
        assert(retire_execution_epoch==live_execution_epoch);
        assert(retire_effect_id==live_effect_id);
      end

      if(dma_commit_valid && receipt_valid && command_pending &&
         dma_commit_command_id==receipt_command_id &&
         dma_commit_execution_epoch==receipt_execution_epoch &&
         dma_commit_effect_id==receipt_effect_id)
        assert(!dma_commit_accept);
    end

    if(past_valid && $past(rst_n) && $past(dma_commit_accept)) begin
      assert(receipt_valid && effect_spent);
      assert(receipt_command_id==$past(live_command_id));
      assert(receipt_execution_epoch==$past(live_execution_epoch));
      assert(receipt_effect_id==$past(live_effect_id));
    end

    if(past_valid && $past(rst_n) && $past(recovery_begin)) begin
      assert(!runtime_ready && !command_pending && !dma_issued && !effect_spent && !reconcile_required);
      assert(checkpoint_valid==$past(checkpoint_valid));
      assert(receipt_valid==$past(receipt_valid));
      if($past(checkpoint_valid)) begin
        assert(checkpoint_command_id==$past(checkpoint_command_id));
        assert(checkpoint_execution_epoch==$past(checkpoint_execution_epoch));
        assert(checkpoint_effect_id==$past(checkpoint_effect_id));
      end
      if($past(receipt_valid)) begin
        assert(receipt_command_id==$past(receipt_command_id));
        assert(receipt_execution_epoch==$past(receipt_execution_epoch));
        assert(receipt_effect_id==$past(receipt_effect_id));
      end
    end

    if(past_valid && $past(rst_n) &&
       $past(restore_accept && receipt_valid && checkpoint_valid && checkpoint_command_pending &&
             !checkpoint_effect_spent && receipt_command_id==checkpoint_command_id &&
             receipt_execution_epoch==checkpoint_execution_epoch && receipt_effect_id==checkpoint_effect_id)) begin
      assert(runtime_ready && command_pending && reconcile_required && !effect_spent);
      assert(!dma_replay_authority);
    end

    if(past_valid && $past(rst_n) && $past(reconcile_accept)) begin
      assert(effect_spent && !reconcile_required && !dma_issued);
      assert(!dma_replay_authority);
    end

    if(past_valid && $past(rst_n) && $past(retire_accept))
      assert(!command_pending);

    cover(rst_n && submit_accept);
    cover(rst_n && checkpoint_capture_accept && !checkpoint_effect_spent);
    cover(rst_n && dma_issue_accept);
    cover(rst_n && dma_commit_accept);
    cover(rst_n && recovery_begin && checkpoint_valid && receipt_valid);
    cover(rst_n && restore_accept && receipt_valid && !checkpoint_effect_spent);
    cover(rst_n && reconcile_required);
    cover(rst_n && reconcile_accept);
    cover(rst_n && retire_accept);
    cover(rst_n && dma_issue_rejected && reconcile_required);
  end
endmodule
