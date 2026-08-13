module capu_queue_epoch_wrap_incarnation_v33_formal;
  logic clk;
  (* anyseq *) logic rst_n,recovery_begin,submit_valid,checkpoint_capture_valid,issue_valid;
  (* anyseq *) logic resolution_valid,resolution_committed,restore_valid,retire_valid;
  (* anyseq *) logic [1:0] submit_incarnation,submit_queue_epoch,submit_command_id,submit_execution_epoch,submit_effect_id;
  (* anyseq *) logic [1:0] issue_incarnation,issue_queue_epoch,issue_command_id,issue_execution_epoch,issue_effect_id;
  (* anyseq *) logic [1:0] resolution_incarnation,resolution_queue_epoch,resolution_command_id,resolution_execution_epoch,resolution_effect_id;
  (* anyseq *) logic [1:0] retire_incarnation,retire_queue_epoch,retire_command_id,retire_execution_epoch,retire_effect_id;
  logic runtime_ready,submit_accept,slot_reuse_accept,epoch_wrap_accept,incarnation_exhausted,slot_pending;
  logic [1:0] live_incarnation,live_queue_epoch,live_command_id,live_execution_epoch,live_effect_id,effect_state;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_pending;
  logic [1:0] checkpoint_incarnation,checkpoint_queue_epoch,checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id,checkpoint_effect_state;
  logic issue_accept,issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic replay_authority,evidence_required,issue_receipt,negative_receipt,completion_receipt,durable_slot_valid;
  logic [1:0] durable_incarnation,durable_queue_epoch,durable_command_id,durable_execution_epoch,durable_effect_id;
  logic last_retired_valid; logic [1:0] last_retired_incarnation,last_retired_queue_epoch;
  logic stale_evidence_quarantine_accept,stale_evidence_quarantined,speculation_kill;

  capu_queue_epoch_wrap_incarnation_v33 #(.ID_WIDTH(2)) dut(.*);
  logic past_valid=0;
  always @(posedge clk) begin
    past_valid<=1'b1;
    if(!past_valid) assume(!rst_n); else assume(rst_n);

    if(rst_n) begin
      if(durable_slot_valid&&last_retired_valid) begin
        if(last_retired_queue_epoch!=2'b11) begin
          assert(durable_incarnation==last_retired_incarnation);
          assert(durable_queue_epoch==last_retired_queue_epoch+1'b1);
        end else begin
          assert(last_retired_incarnation!=2'b11);
          assert(durable_incarnation==last_retired_incarnation+1'b1);
          assert(durable_queue_epoch==2'b00);
        end
      end
      if(epoch_wrap_accept)
        assert(submit_accept&&last_retired_valid&&last_retired_queue_epoch==2'b11&&last_retired_incarnation!=2'b11&&submit_incarnation==last_retired_incarnation+1'b1&&submit_queue_epoch==2'b00);
      if(last_retired_valid&&last_retired_incarnation==2'b11&&last_retired_queue_epoch==2'b11&&!durable_slot_valid&&!slot_pending) begin
        assert(!submit_accept);
        if(submit_valid&&runtime_ready&&!recovery_begin&&!restore_valid) assert(incarnation_exhausted);
      end
      if(durable_slot_valid&&resolution_valid&&resolution_queue_epoch==durable_queue_epoch&&resolution_incarnation!=durable_incarnation)
        assert(!resolution_accept);
      if(stale_evidence_quarantine_accept)
        assert(resolution_valid&&!resolution_accept&&durable_slot_valid&&((resolution_incarnation<durable_incarnation)||(resolution_incarnation==durable_incarnation&&resolution_queue_epoch<durable_queue_epoch)));
    end

    if(past_valid&&$past(rst_n)&&$past(recovery_begin)) begin
      assert(durable_slot_valid==$past(durable_slot_valid));
      assert(durable_incarnation==$past(durable_incarnation));
      assert(durable_queue_epoch==$past(durable_queue_epoch));
      assert(last_retired_incarnation==$past(last_retired_incarnation));
      assert(last_retired_queue_epoch==$past(last_retired_queue_epoch));
    end
    if(past_valid&&$past(rst_n)&&$past(restore_accept)&&$past(durable_slot_valid)) begin
      assert(live_incarnation==$past(durable_incarnation));
      assert(live_queue_epoch==$past(durable_queue_epoch));
    end
    if(past_valid&&$past(rst_n)&&$past(stale_evidence_quarantine_accept)) assert(stale_evidence_quarantined);

    cover(rst_n&&epoch_wrap_accept);
    cover(rst_n&&stale_evidence_quarantine_accept&&resolution_queue_epoch==durable_queue_epoch&&resolution_incarnation<durable_incarnation);
    cover(rst_n&&checkpoint_valid&&durable_slot_valid&&checkpoint_queue_epoch==durable_queue_epoch&&checkpoint_incarnation<durable_incarnation);
    cover(rst_n&&last_retired_valid&&last_retired_incarnation==2'b11&&last_retired_queue_epoch==2'b11&&incarnation_exhausted);
  end
endmodule
