`timescale 1ns/1ps

module capu_mmu_translation_recovery_v20_tb;
    localparam int CRW=4, CEW=4, CCW=8, BPW=12, RW=4, AW=3, TEW=4, VW=4, PW=4, OW=2, FCW=3;
    localparam int VAW=VW+OW, PAW=PW+OW;
    localparam int PAYW=BPW+RW+AW+TEW+VW+PW+4+1+VAW+FCW;

    logic clk=0, rst_n=0;
    always #5 clk = ~clk;

    logic recovery_begin, restore_valid, snapshot_commitment_verified;
    logic [CRW-1:0] snapshot_checkpoint_ref;
    logic [CEW-1:0] snapshot_checkpoint_epoch;
    logic [CCW-1:0] snapshot_checkpoint_commitment;
    logic [PAYW-1:0] snapshot_checkpoint_payload;
    logic [BPW-1:0] restore_base_payload;
    logic [RW-1:0] restore_root;
    logic [AW-1:0] restore_asid;
    logic [TEW-1:0] restore_translation_epoch;
    logic [VW-1:0] restore_vpn;
    logic [PW-1:0] restore_ppn;
    logic restore_perm_r,restore_perm_w,restore_perm_x,restore_perm_u;
    logic restore_fault_pending;
    logic [VAW-1:0] restore_fault_vaddr;
    logic [FCW-1:0] restore_fault_cause;

    logic current_anchor_valid;
    logic [CRW-1:0] current_anchor_ref;
    logic [CEW-1:0] current_anchor_epoch;
    logic [CCW-1:0] current_anchor_commitment;
    logic [PAYW-1:0] current_anchor_payload;

    logic checkpoint_prepare_valid,candidate_commitment_verified,checkpoint_abort;
    logic [CRW-1:0] candidate_checkpoint_ref;
    logic [CEW-1:0] candidate_checkpoint_epoch;
    logic [CCW-1:0] candidate_checkpoint_commitment;
    logic [PAYW-1:0] candidate_checkpoint_payload,committed_checkpoint_payload;
    logic snapshot_persisted_valid;
    logic [CRW-1:0] persisted_checkpoint_ref;
    logic [CEW-1:0] persisted_checkpoint_epoch;
    logic [CCW-1:0] persisted_checkpoint_commitment;
    logic [PAYW-1:0] persisted_checkpoint_payload;
    logic anchor_commit_ack_valid;
    logic [CRW-1:0] ack_checkpoint_ref;
    logic [CEW-1:0] ack_checkpoint_epoch;
    logic [CCW-1:0] ack_checkpoint_commitment;
    logic [PAYW-1:0] ack_checkpoint_payload;

    logic access_valid;
    logic [VAW-1:0] access_vaddr;
    logic [1:0] access_kind,access_privilege;
    logic fault_clear_valid,effect_issue_valid,effect_commit_valid;

    logic checkpoint_prepare_accept,checkpoint_prepare_rejected;
    logic checkpoint_snapshot_persist_accept,checkpoint_snapshot_persist_rejected;
    logic checkpoint_anchor_commit_request,checkpoint_commit_event,checkpoint_candidate_pending,checkpoint_snapshot_durable;
    logic checkpoint_restore_accept,checkpoint_restore_rejected,checkpoint_restore_mismatch;
    logic [PAYW-1:0] checkpoint_request_payload;
    logic live_execution_ready;
    logic [RW-1:0] live_root;
    logic [AW-1:0] live_asid;
    logic [TEW-1:0] live_translation_epoch;
    logic [VW-1:0] live_vpn;
    logic [PW-1:0] live_ppn;
    logic live_perm_r,live_perm_w,live_perm_x,live_perm_u;
    logic live_fault_pending;
    logic [VAW-1:0] live_fault_vaddr;
    logic [FCW-1:0] live_fault_cause;
    logic translation_access_accept,page_fault;
    logic [PAW-1:0] translated_paddr;
    logic stale_or_foreign_translation_rejected,fault_clear_accept,speculative_effect_pending,visible_effect,speculation_kill;

    function automatic [PAYW-1:0] pack_payload(
        input [BPW-1:0] base,
        input [RW-1:0] root,
        input [AW-1:0] asid,
        input [TEW-1:0] tepoch,
        input [VW-1:0] vpn,
        input [PW-1:0] ppn,
        input pr,input pw,input px,input pu,
        input fp,
        input [VAW-1:0] fv,
        input [FCW-1:0] fc
    );
        pack_payload={base,root,asid,tepoch,vpn,ppn,pr,pw,px,pu,fp,fv,fc};
    endfunction

    task automatic tick;
        begin @(posedge clk); #1; end
    endtask

    capu_mmu_translation_recovery_v20 #(
        .CHECKPOINT_REF_WIDTH(CRW),.CHECKPOINT_EPOCH_WIDTH(CEW),.CHECKPOINT_COMMITMENT_WIDTH(CCW),
        .BASE_PAYLOAD_WIDTH(BPW),.ROOT_WIDTH(RW),.ASID_WIDTH(AW),.TRANSLATION_EPOCH_WIDTH(TEW),
        .VPN_WIDTH(VW),.PPN_WIDTH(PW),.PAGE_OFFSET_WIDTH(OW),.FAULT_CAUSE_WIDTH(FCW)
    ) dut (.*);

    initial begin
        recovery_begin=0; restore_valid=0; snapshot_commitment_verified=0;
        snapshot_checkpoint_ref=0; snapshot_checkpoint_epoch=0; snapshot_checkpoint_commitment=0; snapshot_checkpoint_payload=0;
        restore_base_payload=0; restore_root=0; restore_asid=0; restore_translation_epoch=0; restore_vpn=0; restore_ppn=0;
        restore_perm_r=0; restore_perm_w=0; restore_perm_x=0; restore_perm_u=0; restore_fault_pending=0; restore_fault_vaddr=0; restore_fault_cause=0;
        current_anchor_valid=0; current_anchor_ref=0; current_anchor_epoch=0; current_anchor_commitment=0; current_anchor_payload=0;
        checkpoint_prepare_valid=0; candidate_checkpoint_ref=0; candidate_checkpoint_epoch=0; candidate_checkpoint_commitment=0;
        candidate_checkpoint_payload=0; candidate_commitment_verified=0; committed_checkpoint_payload=0; checkpoint_abort=0;
        snapshot_persisted_valid=0; persisted_checkpoint_ref=0; persisted_checkpoint_epoch=0; persisted_checkpoint_commitment=0; persisted_checkpoint_payload=0;
        anchor_commit_ack_valid=0; ack_checkpoint_ref=0; ack_checkpoint_epoch=0; ack_checkpoint_commitment=0; ack_checkpoint_payload=0;
        access_valid=0; access_vaddr=0; access_kind=0; access_privilege=0; fault_clear_valid=0; effect_issue_valid=0; effect_commit_valid=0;

        repeat(2) tick(); rst_n=1; tick();

        // Exact checkpoint restore: one memory view is authoritative.
        restore_base_payload=12'hA51; restore_root=4'h3; restore_asid=3'h5; restore_translation_epoch=4'h7;
        restore_vpn=4'h4; restore_ppn=4'h9; restore_perm_r=1; restore_perm_w=0; restore_perm_x=1; restore_perm_u=1;
        restore_fault_pending=0; restore_fault_vaddr=0; restore_fault_cause=0;
        current_anchor_valid=1; current_anchor_ref=4'h2; current_anchor_epoch=4'h5; current_anchor_commitment=8'hC3;
        current_anchor_payload=pack_payload(restore_base_payload,restore_root,restore_asid,restore_translation_epoch,restore_vpn,restore_ppn,1,0,1,1,0,0,0);
        snapshot_checkpoint_ref=current_anchor_ref; snapshot_checkpoint_epoch=current_anchor_epoch;
        snapshot_checkpoint_commitment=current_anchor_commitment; snapshot_checkpoint_payload=current_anchor_payload; snapshot_commitment_verified=1;
        restore_valid=1; #1;
        if (!checkpoint_restore_accept) $fatal(1,"exact restore rejected");
        tick(); restore_valid=0;
        if (!live_execution_ready || live_root!=4'h3 || live_asid!=3'h5 || live_translation_epoch!=4'h7) $fatal(1,"restore state mismatch");
        $display("exact_restore memory_view=1 root=%0h asid=%0h epoch=%0h",live_root,live_asid,live_translation_epoch);

        // Exact read translation.
        access_valid=1; access_vaddr=6'b010010; access_kind=0; access_privilege=0; #1;
        if (!translation_access_accept || translated_paddr!=6'b100110 || page_fault) $fatal(1,"exact translation failed");
        $display("translation_hit exact=1 paddr=%0h",translated_paddr);
        tick(); access_valid=0;

        // A pending speculative effect cannot cross a precise permission fault.
        effect_issue_valid=1; tick(); effect_issue_valid=0;
        if (!speculative_effect_pending) $fatal(1,"effect not pending");
        access_valid=1; access_vaddr=6'b010011; access_kind=1; access_privilege=0; effect_commit_valid=1; #1;
        if (!page_fault || visible_effect || !speculation_kill) $fatal(1,"fault boundary leaked effect");
        tick(); access_valid=0; effect_commit_valid=0;
        if (!live_fault_pending || live_fault_cause!=3'd2 || speculative_effect_pending) $fatal(1,"fault state mismatch");
        $display("permission_fault precise=1 speculation_killed=1 cause=%0d",live_fault_cause);

        fault_clear_valid=1; #1; if (!fault_clear_accept) $fatal(1,"fault clear rejected"); tick(); fault_clear_valid=0;
        if (live_fault_pending) $fatal(1,"fault not cleared");

        // Same v0.19 state with foreign translation root must fail exact restore.
        restore_root=4'h6; restore_valid=1; #1;
        if (!checkpoint_restore_rejected || !stale_or_foreign_translation_rejected) $fatal(1,"foreign root accepted");
        $display("foreign_translation_root rejected=1");
        tick(); restore_valid=0; restore_root=4'h3;

        // Foreign ASID and stale translation epoch are independently bound.
        restore_asid=3'h2; restore_valid=1; #1;
        if (!checkpoint_restore_rejected) $fatal(1,"foreign asid accepted");
        $display("foreign_asid rejected=1");
        tick(); restore_valid=0; restore_asid=3'h5;
        restore_translation_epoch=4'h6; restore_valid=1; #1;
        if (!checkpoint_restore_rejected) $fatal(1,"stale epoch accepted");
        $display("stale_translation_epoch rejected=1");
        tick(); restore_valid=0; restore_translation_epoch=4'h7;

        // Old/fault-context bytes cannot be mixed with an otherwise valid checkpoint.
        restore_fault_pending=1; restore_fault_vaddr=6'h12; restore_fault_cause=3'd1; restore_valid=1; #1;
        if (!checkpoint_restore_rejected) $fatal(1,"foreign fault context accepted");
        $display("foreign_fault_context rejected=1");
        tick(); restore_valid=0; restore_fault_pending=0; restore_fault_vaddr=0; restore_fault_cause=0;

        // Stale candidate payload is rejected before persistence/authority.
        committed_checkpoint_payload=current_anchor_payload;
        candidate_checkpoint_ref=4'h3; candidate_checkpoint_epoch=4'h6; candidate_checkpoint_commitment=8'hD4; candidate_commitment_verified=1;
        candidate_checkpoint_payload=pack_payload(12'hA51,4'h3,3'h5,4'h6,4'h4,4'h9,1,0,1,1,0,0,0);
        checkpoint_prepare_valid=1; #1;
        if (!checkpoint_prepare_rejected || checkpoint_prepare_accept) $fatal(1,"stale candidate accepted");
        $display("stale_candidate rejected=1");
        tick(); checkpoint_prepare_valid=0;

        // Exact current memory view can pass prepare -> persist -> authority ack.
        candidate_checkpoint_payload=committed_checkpoint_payload; checkpoint_prepare_valid=1; #1;
        if (!checkpoint_prepare_accept) $fatal(1,"exact prepare rejected");
        tick(); checkpoint_prepare_valid=0;
        persisted_checkpoint_ref=candidate_checkpoint_ref; persisted_checkpoint_epoch=candidate_checkpoint_epoch;
        persisted_checkpoint_commitment=candidate_checkpoint_commitment; persisted_checkpoint_payload=candidate_checkpoint_payload;
        snapshot_persisted_valid=1; #1; if (!checkpoint_snapshot_persist_accept) $fatal(1,"persist rejected");
        tick(); snapshot_persisted_valid=0;
        ack_checkpoint_ref=candidate_checkpoint_ref; ack_checkpoint_epoch=candidate_checkpoint_epoch;
        ack_checkpoint_commitment=candidate_checkpoint_commitment; ack_checkpoint_payload=candidate_checkpoint_payload;
        anchor_commit_ack_valid=1; #1; if (!checkpoint_commit_event) $fatal(1,"authority ack rejected");
        $display("checkpoint_authority exact_memory_view=1");
        tick(); anchor_commit_ack_valid=0;

        recovery_begin=1; #1; if (!speculation_kill) $fatal(1,"recovery not barrier"); tick(); recovery_begin=0;
        if (live_execution_ready) $fatal(1,"runtime remained ready after recovery");
        $display("recovery_priority runtime_closed=1");
        $display("CAPU_VCML_MMU_TRANSLATION_V20_PASS");
        $finish;
    end
endmodule
