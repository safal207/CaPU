module capu_delegated_nested_trap_v19_formal;
    localparam REF_W=3,EPOCH_W=3,COMMIT_W=4,BASE_W=10,PC_W=4,PRIV_W=2,CAUSE_W=3,DEL_W=4;
    localparam CTX_W=1+1+CAUSE_W+PC_W+PRIV_W+PRIV_W;
    localparam PAYLOAD_W=BASE_W+PC_W+PRIV_W+DEL_W+2+(2*CTX_W);
    (* gclk *) reg clk; reg rst_n=0; always @(posedge clk) rst_n<=1;

    (* anyseq *) reg recovery_begin,restore_valid,snapshot_commitment_verified,current_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] snapshot_checkpoint_ref,current_anchor_ref,candidate_checkpoint_ref,persisted_checkpoint_ref,ack_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] snapshot_checkpoint_epoch,current_anchor_epoch,candidate_checkpoint_epoch,persisted_checkpoint_epoch,ack_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] snapshot_checkpoint_commitment,current_anchor_commitment,candidate_checkpoint_commitment,persisted_checkpoint_commitment,ack_checkpoint_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] snapshot_checkpoint_payload,current_anchor_payload,candidate_checkpoint_payload,committed_checkpoint_payload,persisted_checkpoint_payload,ack_checkpoint_payload;
    (* anyseq *) reg [BASE_W-1:0] restore_base_payload;
    (* anyseq *) reg [PC_W-1:0] restore_pc,restore_ctx0_return_pc,restore_ctx1_return_pc,trap_vector_pc,normal_next_pc;
    (* anyseq *) reg [PRIV_W-1:0] restore_privilege,restore_ctx0_return_privilege,restore_ctx0_target_privilege,restore_ctx1_return_privilege,restore_ctx1_target_privilege,trap_target_privilege,normal_step_privilege;
    (* anyseq *) reg [DEL_W-1:0] restore_delegation_mask;
    (* anyseq *) reg [1:0] restore_trap_depth;
    (* anyseq *) reg restore_ctx0_valid,restore_ctx0_is_interrupt,restore_ctx1_valid,restore_ctx1_is_interrupt;
    (* anyseq *) reg [CAUSE_W-1:0] restore_ctx0_cause,restore_ctx1_cause,trap_cause;
    (* anyseq *) reg checkpoint_prepare_valid,candidate_commitment_verified,checkpoint_abort,snapshot_persisted_valid,anchor_commit_ack_valid;
    (* anyseq *) reg trap_enter_valid,trap_is_interrupt,trap_return_valid,normal_step_valid,effect_issue_valid,effect_commit_valid;

    wire checkpoint_prepare_accept,checkpoint_prepare_rejected,checkpoint_snapshot_persist_accept,checkpoint_snapshot_persist_rejected;
    wire checkpoint_anchor_commit_request,checkpoint_commit_event,checkpoint_candidate_pending,checkpoint_snapshot_durable;
    wire checkpoint_restore_accept,checkpoint_restore_rejected,checkpoint_restore_mismatch,live_execution_ready;
    wire [PC_W-1:0] live_pc; wire [PRIV_W-1:0] live_privilege; wire [DEL_W-1:0] live_delegation_mask; wire [1:0] live_trap_depth;
    wire live_ctx0_valid,live_ctx0_is_interrupt; wire [CAUSE_W-1:0] live_ctx0_cause; wire [PC_W-1:0] live_ctx0_return_pc;
    wire [PRIV_W-1:0] live_ctx0_return_privilege,live_ctx0_target_privilege; wire live_ctx1_valid,live_ctx1_is_interrupt;
    wire [CAUSE_W-1:0] live_ctx1_cause; wire [PC_W-1:0] live_ctx1_return_pc; wire [PRIV_W-1:0] live_ctx1_return_privilege,live_ctx1_target_privilege;
    wire trap_enter_accept,delegation_rejected,trap_depth_overflow_rejected,trap_return_accept,trap_return_underflow_rejected;
    wire normal_step_accept,privilege_mismatch_rejected,speculative_effect_pending,visible_effect,speculation_kill;
    wire [PAYLOAD_W-1:0] checkpoint_request_payload;

    capu_delegated_nested_trap_v19 #(.CHECKPOINT_REF_WIDTH(REF_W),.CHECKPOINT_EPOCH_WIDTH(EPOCH_W),.CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W),
      .BASE_PAYLOAD_WIDTH(BASE_W),.PC_WIDTH(PC_W),.PRIV_WIDTH(PRIV_W),.CAUSE_WIDTH(CAUSE_W),.DELEGATION_WIDTH(DEL_W),.CTX_WIDTH(CTX_W),.PAYLOAD_WIDTH(PAYLOAD_W)) dut(.*);

    reg expect_outer=0,expect_inner=0,expect_return=0,expect_recovery_closed=0,expect_boundary_clear=0;
    reg [PC_W-1:0] saved_pc=0; reg [PRIV_W-1:0] saved_priv=0; reg [1:0] prior_depth=0;
    reg seen_restore=0,seen_delegation_reject=0,seen_outer=0,seen_inner=0,seen_overflow=0,seen_return=0,seen_underflow=0,seen_checkpoint=0,seen_spec_kill=0;

    always @(posedge clk) begin
      if(!rst_n) begin
        expect_outer<=0;expect_inner<=0;expect_return<=0;expect_recovery_closed<=0;expect_boundary_clear<=0;
        seen_restore<=0;seen_delegation_reject<=0;seen_outer<=0;seen_inner<=0;seen_overflow<=0;seen_return<=0;seen_underflow<=0;seen_checkpoint<=0;seen_spec_kill<=0;
      end else begin
        if(checkpoint_restore_accept) begin
          assert(snapshot_checkpoint_payload==current_anchor_payload);
          assert(snapshot_checkpoint_payload=={restore_base_payload,restore_pc,restore_privilege,restore_delegation_mask,restore_trap_depth,
            restore_ctx0_valid,restore_ctx0_is_interrupt,restore_ctx0_cause,restore_ctx0_return_pc,restore_ctx0_return_privilege,restore_ctx0_target_privilege,
            restore_ctx1_valid,restore_ctx1_is_interrupt,restore_ctx1_cause,restore_ctx1_return_pc,restore_ctx1_return_privilege,restore_ctx1_target_privilege});
          seen_restore<=1;
        end
        if(delegation_rejected) begin assert(!trap_enter_accept); seen_delegation_reject<=1; end
        if(trap_depth_overflow_rejected) begin assert(!trap_enter_accept); seen_overflow<=1; end
        if(trap_return_underflow_rejected) begin assert(!trap_return_accept); seen_underflow<=1; end
        if(privilege_mismatch_rejected) assert(!normal_step_accept);
        if((recovery_begin||restore_valid||trap_enter_accept||trap_return_accept)) assert(!visible_effect);

        if(trap_enter_accept) begin
          assert(live_trap_depth<2);
          assert(live_delegation_mask[trap_target_privilege]);
          saved_pc<=live_pc; saved_priv<=live_privilege; prior_depth<=live_trap_depth;
          if(live_trap_depth==0) expect_outer<=1; else expect_inner<=1;
          if(speculative_effect_pending) seen_spec_kill<=1;
        end
        if(expect_outer) begin
          assert(live_trap_depth==1); assert(live_ctx0_valid);
          assert(live_ctx0_return_pc==saved_pc); assert(live_ctx0_return_privilege==saved_priv);
          seen_outer<=1; expect_outer<=0;
        end
        if(expect_inner) begin
          assert(live_trap_depth==2); assert(live_ctx1_valid);
          assert(live_ctx1_return_pc==saved_pc); assert(live_ctx1_return_privilege==saved_priv);
          seen_inner<=1; expect_inner<=0;
        end
        if(trap_return_accept) begin saved_pc<=live_trap_depth==2?live_ctx1_return_pc:live_ctx0_return_pc; saved_priv<=live_trap_depth==2?live_ctx1_return_privilege:live_ctx0_return_privilege; prior_depth<=live_trap_depth; expect_return<=1; end
        if(expect_return) begin
          assert(live_pc==saved_pc); assert(live_privilege==saved_priv); assert(live_trap_depth==prior_depth-1);
          seen_return<=1; expect_return<=0;
        end
        if(checkpoint_prepare_accept) assert(candidate_checkpoint_payload==committed_checkpoint_payload);
        if(checkpoint_snapshot_persist_accept) assert(persisted_checkpoint_payload==checkpoint_request_payload);
        if(checkpoint_commit_event) begin assert(ack_checkpoint_payload==checkpoint_request_payload); seen_checkpoint<=1; end
        if(recovery_begin) expect_recovery_closed<=1;
        if(expect_recovery_closed) begin assert(!live_execution_ready); expect_recovery_closed<=0; end

        cover(seen_restore); cover(seen_delegation_reject); cover(seen_outer); cover(seen_inner); cover(seen_overflow);
        cover(seen_return); cover(seen_underflow); cover(seen_checkpoint); cover(seen_spec_kill);
      end
    end
endmodule
