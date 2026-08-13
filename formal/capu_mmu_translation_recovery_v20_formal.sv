module capu_mmu_translation_recovery_v20_formal;
    localparam int CRW=3, CEW=3, CCW=4, BPW=8, RW=3, AW=2, TEW=3, VW=3, PW=3, OW=2, FCW=3;
    localparam int VAW=VW+OW, PAW=PW+OW;
    localparam int PAYW=BPW+RW+AW+TEW+VW+PW+4+1+VAW+FCW;

    (* gclk *) reg clk;
    (* anyseq *) logic rst_n,recovery_begin,restore_valid,snapshot_commitment_verified;
    (* anyseq *) logic [CRW-1:0] snapshot_checkpoint_ref,current_anchor_ref,candidate_checkpoint_ref,persisted_checkpoint_ref,ack_checkpoint_ref;
    (* anyseq *) logic [CEW-1:0] snapshot_checkpoint_epoch,current_anchor_epoch,candidate_checkpoint_epoch,persisted_checkpoint_epoch,ack_checkpoint_epoch;
    (* anyseq *) logic [CCW-1:0] snapshot_checkpoint_commitment,current_anchor_commitment,candidate_checkpoint_commitment,persisted_checkpoint_commitment,ack_checkpoint_commitment;
    (* anyseq *) logic [PAYW-1:0] snapshot_checkpoint_payload,current_anchor_payload,candidate_checkpoint_payload,committed_checkpoint_payload,persisted_checkpoint_payload,ack_checkpoint_payload;
    (* anyseq *) logic [BPW-1:0] restore_base_payload;
    (* anyseq *) logic [RW-1:0] restore_root;
    (* anyseq *) logic [AW-1:0] restore_asid;
    (* anyseq *) logic [TEW-1:0] restore_translation_epoch;
    (* anyseq *) logic [VW-1:0] restore_vpn;
    (* anyseq *) logic [PW-1:0] restore_ppn;
    (* anyseq *) logic restore_perm_r,restore_perm_w,restore_perm_x,restore_perm_u,restore_fault_pending;
    (* anyseq *) logic [VAW-1:0] restore_fault_vaddr,access_vaddr;
    (* anyseq *) logic [FCW-1:0] restore_fault_cause;
    (* anyseq *) logic current_anchor_valid,checkpoint_prepare_valid,candidate_commitment_verified,checkpoint_abort,snapshot_persisted_valid,anchor_commit_ack_valid;
    (* anyseq *) logic access_valid,fault_clear_valid,effect_issue_valid,effect_commit_valid;
    (* anyseq *) logic [1:0] access_kind,access_privilege;

    logic checkpoint_prepare_accept,checkpoint_prepare_rejected,checkpoint_snapshot_persist_accept,checkpoint_snapshot_persist_rejected;
    logic checkpoint_anchor_commit_request,checkpoint_commit_event,checkpoint_candidate_pending,checkpoint_snapshot_durable;
    logic checkpoint_restore_accept,checkpoint_restore_rejected,checkpoint_restore_mismatch;
    logic [PAYW-1:0] checkpoint_request_payload;
    logic live_execution_ready;
    logic [RW-1:0] live_root;
    logic [AW-1:0] live_asid;
    logic [TEW-1:0] live_translation_epoch;
    logic [VW-1:0] live_vpn;
    logic [PW-1:0] live_ppn;
    logic live_perm_r,live_perm_w,live_perm_x,live_perm_u,live_fault_pending;
    logic [VAW-1:0] live_fault_vaddr;
    logic [FCW-1:0] live_fault_cause;
    logic translation_access_accept,page_fault,stale_or_foreign_translation_rejected,fault_clear_accept;
    logic [PAW-1:0] translated_paddr;
    logic speculative_effect_pending,visible_effect,speculation_kill;

    capu_mmu_translation_recovery_v20 #(
      .CHECKPOINT_REF_WIDTH(CRW),.CHECKPOINT_EPOCH_WIDTH(CEW),.CHECKPOINT_COMMITMENT_WIDTH(CCW),.BASE_PAYLOAD_WIDTH(BPW),
      .ROOT_WIDTH(RW),.ASID_WIDTH(AW),.TRANSLATION_EPOCH_WIDTH(TEW),.VPN_WIDTH(VW),.PPN_WIDTH(PW),
      .PAGE_OFFSET_WIDTH(OW),.FAULT_CAUSE_WIDTH(FCW)
    ) dut (.*);

    reg past_valid=0;
    always @(posedge clk) past_valid <= 1;
    always @(*) begin
        if (!past_valid) assume(!rst_n);
        else assume(rst_n);
        assume(access_kind <= 2);
    end

    always @(posedge clk) if (past_valid && rst_n) begin
        assert(!(checkpoint_restore_accept && checkpoint_restore_rejected));
        assert(checkpoint_restore_mismatch == stale_or_foreign_translation_rejected);
        if (checkpoint_restore_accept) begin
            assert(!checkpoint_restore_mismatch);
            assert(snapshot_checkpoint_payload == current_anchor_payload);
            assert(snapshot_checkpoint_payload == {restore_base_payload,restore_root,restore_asid,restore_translation_epoch,restore_vpn,restore_ppn,restore_perm_r,restore_perm_w,restore_perm_x,restore_perm_u,restore_fault_pending,restore_fault_vaddr,restore_fault_cause});
        end
        assert(!(translation_access_accept && page_fault));
        if (translation_access_accept) begin
            assert(live_execution_ready && !live_fault_pending);
            assert(access_vaddr[VAW-1:OW] == live_vpn);
            assert(translated_paddr == {live_ppn,access_vaddr[OW-1:0]});
        end
        if (page_fault) begin
            assert(!visible_effect);
            assert(speculation_kill);
        end
        if (recovery_begin || restore_valid) begin
            assert(!visible_effect);
            assert(speculation_kill);
        end
        if ($past(page_fault) && !$past(recovery_begin) && !$past(restore_valid)) begin
            assert(live_fault_pending);
            assert(!speculative_effect_pending);
        end
        if ($past(recovery_begin)) begin
            assert(!live_execution_ready);
        end
        assert(!(checkpoint_prepare_accept && checkpoint_prepare_rejected));
        if (checkpoint_prepare_accept)
            assert(candidate_checkpoint_payload == committed_checkpoint_payload);
    end

    always @(posedge clk) if (past_valid && rst_n) begin
        cover(checkpoint_restore_accept);
        cover(checkpoint_restore_rejected);
        cover(translation_access_accept);
        cover(page_fault);
        cover(page_fault && speculative_effect_pending);
        cover(fault_clear_accept);
        cover(checkpoint_prepare_accept);
        cover(checkpoint_prepare_rejected);
    end
endmodule
