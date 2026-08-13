module capu_queue_epoch_slot_reuse_v32_formal;
  logic clk;
  (* anyseq *) logic rst_n,recovery_begin;
  (* anyseq *) logic submit_valid;
  (* anyseq *) logic [1:0] submit_queue_epoch,submit_command_id,submit_execution_epoch,submit_effect_id;
  (* anyseq *) logic checkpoint_capture_valid;
  (* anyseq *) logic issue_valid;
  (* anyseq *) logic [1:0] issue_queue_epoch,issue_command_id,issue_execution_epoch,issue_effect_id;
  (* anyseq *) logic resolution_valid,resolution_committed;
  (* anyseq *) logic [1:0] resolution_queue_epoch,resolution_command_id,resolution_execution_epoch,resolution_effect_id;
  (* anyseq *) logic restore_valid;
  (* anyseq *) logic retire_valid;
  (* anyseq *) logic [1:0] retire_queue_epoch,retire_command_id,retire_execution_epoch,retire_effect_id;

  logic runtime_ready,submit_accept,slot_reuse_accept,epoch_wrap_blocked,slot_pending;
  logic [1:0] live_queue_epoch,live_command_id,live_execution_epoch,live_effect_id,effect_state;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_pending;
  logic [1:0] checkpoint_queue_epoch,checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id,checkpoint_effect_state;
  logic issue_accept,issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic replay_authority,evidence_required,issue_receipt,negative_receipt,completion_receipt;
  logic durable_slot_valid;
  logic [1:0] durable_queue_epoch,durable_command_id,durable_execution_epoch,durable_effect_id;
  logic last_retired_valid;
  logic [1:0] last_retired_queue_epoch;
  logic stale_evidence_quarantined,speculation_kill;

  localparam [1:0] U=2'b00, X=2'b01, C=2'b10, N=2'b11;

  capu_queue_epoch_slot_reuse_v32 #(.ID_WIDTH(2)) dut(.*);

  logic past_valid=0;
  always @(posedge clk) begin
    past_valid <= 1'b1;
    if(!past_valid) assume(!rst_n); else assume(rst_n);

    if(rst_n) begin
      assert(!(issue_accept && issue_rejected));
      assert(!(resolution_accept && resolution_rejected));
      assert(!(restore_accept && restore_rejected));
      assert(!(retire_accept && retire_rejected));

      if(slot_pending) assert(durable_slot_valid);

      if(durable_slot_valid) begin
        assert(live_queue_epoch==durable_queue_epoch);
        assert(live_command_id==durable_command_id);
        assert(live_execution_epoch==durable_execution_epoch);
        assert(live_effect_id==durable_effect_id);
        if(last_retired_valid) begin
          assert(last_retired_queue_epoch!=2'b11);
          assert(durable_queue_epoch==last_retired_queue_epoch+1'b1);
        end
      end

      if(effect_state==X) begin
        assert(issue_receipt);
        assert(!replay_authority);
        assert(evidence_required || !runtime_ready || !slot_pending);
      end
      if(effect_state==C) begin
        assert(completion_receipt);
        assert(!issue_receipt);
        assert(!replay_authority);
      end
      if(effect_state==N) begin
        assert(negative_receipt);
        assert(!issue_receipt);
      end
      if(effect_state==U)
        assert(!issue_receipt && !negative_receipt && !completion_receipt);

      assert(!(issue_receipt && negative_receipt));
      assert(!(issue_receipt && completion_receipt));
      assert(!(negative_receipt && completion_receipt));

      if(issue_accept) begin
        assert(issue_queue_epoch==durable_queue_epoch);
        assert(issue_command_id==durable_command_id);
        assert(issue_execution_epoch==durable_execution_epoch);
        assert(issue_effect_id==durable_effect_id);
      end

      if(resolution_accept) begin
        assert(resolution_queue_epoch==durable_queue_epoch);
        assert(resolution_command_id==durable_command_id);
        assert(resolution_execution_epoch==durable_execution_epoch);
        assert(resolution_effect_id==durable_effect_id);
        assert(effect_state==X);
        assert(issue_receipt);
      end

      if(retire_accept) begin
        assert(retire_queue_epoch==durable_queue_epoch);
        assert(effect_state==C && completion_receipt);
      end

      if(submit_accept && last_retired_valid) begin
        assert(last_retired_queue_epoch!=2'b11);
        assert(submit_queue_epoch==last_retired_queue_epoch+1'b1);
      end

      if(last_retired_valid && last_retired_queue_epoch==2'b11 && !durable_slot_valid && !slot_pending)
        assert(!submit_accept);

      if(last_retired_valid && durable_slot_valid && resolution_valid &&
         resolution_queue_epoch<=last_retired_queue_epoch)
        assert(!resolution_accept);
    end

    if(past_valid && $past(rst_n) && $past(submit_accept)) begin
      assert(durable_slot_valid && slot_pending);
      assert(durable_queue_epoch==$past(submit_queue_epoch));
      assert(durable_command_id==$past(submit_command_id));
      assert(durable_execution_epoch==$past(submit_execution_epoch));
      assert(durable_effect_id==$past(submit_effect_id));
      assert(effect_state==U);
    end

    if(past_valid && $past(rst_n) && $past(issue_accept)) begin
      assert(effect_state==X && issue_receipt && !replay_authority);
    end

    if(past_valid && $past(rst_n) && $past(resolution_accept)) begin
      assert(!issue_receipt);
      if($past(resolution_committed)) begin
        assert(effect_state==C && completion_receipt && !negative_receipt);
      end else begin
        assert(effect_state==N && negative_receipt && !completion_receipt);
      end
    end

    if(past_valid && $past(rst_n) && $past(retire_accept)) begin
      assert(!slot_pending && !durable_slot_valid);
      assert(last_retired_valid);
      assert(last_retired_queue_epoch==$past(retire_queue_epoch));
      assert(effect_state==U);
    end

    if(past_valid && $past(rst_n) && $past(recovery_begin)) begin
      assert(!runtime_ready && !slot_pending && effect_state==U);
      assert(durable_slot_valid==$past(durable_slot_valid));
      assert(durable_queue_epoch==$past(durable_queue_epoch));
      assert(durable_command_id==$past(durable_command_id));
      assert(durable_execution_epoch==$past(durable_execution_epoch));
      assert(durable_effect_id==$past(durable_effect_id));
      assert(last_retired_valid==$past(last_retired_valid));
      assert(last_retired_queue_epoch==$past(last_retired_queue_epoch));
      assert(issue_receipt==$past(issue_receipt));
      assert(negative_receipt==$past(negative_receipt));
      assert(completion_receipt==$past(completion_receipt));
    end

    if(past_valid && $past(rst_n) && $past(restore_accept)) begin
      assert(runtime_ready);
      if($past(durable_slot_valid)) begin
        assert(slot_pending);
        assert(live_queue_epoch==$past(durable_queue_epoch));
        assert(live_command_id==$past(durable_command_id));
        assert(live_execution_epoch==$past(durable_execution_epoch));
        assert(live_effect_id==$past(durable_effect_id));
        if($past(completion_receipt)) assert(effect_state==C);
        else if($past(issue_receipt)) assert(effect_state==X);
        else if($past(negative_receipt)) assert(effect_state==N);
        else assert(effect_state==U);
      end else if($past(last_retired_valid)) begin
        assert(!slot_pending);
        assert(effect_state==U);
      end
    end

    if(past_valid && $past(rst_n) && $past(stale_evidence_quarantined))
      assert(stale_evidence_quarantined);

    cover(rst_n && submit_accept && !last_retired_valid);
    cover(rst_n && retire_accept && !last_retired_valid);
    cover(rst_n && submit_accept && last_retired_valid && slot_reuse_accept);
    cover(rst_n && durable_slot_valid && last_retired_valid && durable_queue_epoch==last_retired_queue_epoch+1'b1);
    cover(rst_n && stale_evidence_quarantined && durable_slot_valid);
    cover(rst_n && checkpoint_valid && last_retired_valid && durable_slot_valid && checkpoint_queue_epoch==last_retired_queue_epoch);
    cover(rst_n && restore_accept && durable_slot_valid && checkpoint_valid);
    cover(rst_n && last_retired_valid && last_retired_queue_epoch==2'b11 && epoch_wrap_blocked);
  end
endmodule
