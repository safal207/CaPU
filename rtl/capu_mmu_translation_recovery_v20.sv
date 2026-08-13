module capu_mmu_translation_recovery_v20 #(
    parameter int CHECKPOINT_REF_WIDTH = 16,
    parameter int CHECKPOINT_EPOCH_WIDTH = 16,
    parameter int CHECKPOINT_COMMITMENT_WIDTH = 256,
    parameter int BASE_PAYLOAD_WIDTH = 256,
    parameter int ROOT_WIDTH = 12,
    parameter int ASID_WIDTH = 8,
    parameter int TRANSLATION_EPOCH_WIDTH = 8,
    parameter int VPN_WIDTH = 8,
    parameter int PPN_WIDTH = 8,
    parameter int PAGE_OFFSET_WIDTH = 4,
    parameter int FAULT_CAUSE_WIDTH = 3,
    parameter int VADDR_WIDTH = VPN_WIDTH + PAGE_OFFSET_WIDTH,
    parameter int PADDR_WIDTH = PPN_WIDTH + PAGE_OFFSET_WIDTH,
    parameter int PAYLOAD_WIDTH = BASE_PAYLOAD_WIDTH + ROOT_WIDTH + ASID_WIDTH + TRANSLATION_EPOCH_WIDTH + VPN_WIDTH + PPN_WIDTH + 4 + 1 + VADDR_WIDTH + FAULT_CAUSE_WIDTH
) (
    input  logic clk,
    input  logic rst_n,

    input  logic recovery_begin,
    input  logic restore_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] snapshot_checkpoint_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] snapshot_checkpoint_epoch,
    input  logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] snapshot_checkpoint_commitment,
    input  logic [PAYLOAD_WIDTH-1:0] snapshot_checkpoint_payload,
    input  logic snapshot_commitment_verified,

    input  logic [BASE_PAYLOAD_WIDTH-1:0] restore_base_payload,
    input  logic [ROOT_WIDTH-1:0] restore_root,
    input  logic [ASID_WIDTH-1:0] restore_asid,
    input  logic [TRANSLATION_EPOCH_WIDTH-1:0] restore_translation_epoch,
    input  logic [VPN_WIDTH-1:0] restore_vpn,
    input  logic [PPN_WIDTH-1:0] restore_ppn,
    input  logic restore_perm_r,
    input  logic restore_perm_w,
    input  logic restore_perm_x,
    input  logic restore_perm_u,
    input  logic restore_fault_pending,
    input  logic [VADDR_WIDTH-1:0] restore_fault_vaddr,
    input  logic [FAULT_CAUSE_WIDTH-1:0] restore_fault_cause,

    input  logic current_anchor_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] current_anchor_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] current_anchor_epoch,
    input  logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] current_anchor_commitment,
    input  logic [PAYLOAD_WIDTH-1:0] current_anchor_payload,

    input  logic checkpoint_prepare_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] candidate_checkpoint_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] candidate_checkpoint_epoch,
    input  logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] candidate_checkpoint_commitment,
    input  logic [PAYLOAD_WIDTH-1:0] candidate_checkpoint_payload,
    input  logic candidate_commitment_verified,
    input  logic [PAYLOAD_WIDTH-1:0] committed_checkpoint_payload,
    input  logic checkpoint_abort,

    input  logic snapshot_persisted_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] persisted_checkpoint_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] persisted_checkpoint_epoch,
    input  logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] persisted_checkpoint_commitment,
    input  logic [PAYLOAD_WIDTH-1:0] persisted_checkpoint_payload,

    input  logic anchor_commit_ack_valid,
    input  logic [CHECKPOINT_REF_WIDTH-1:0] ack_checkpoint_ref,
    input  logic [CHECKPOINT_EPOCH_WIDTH-1:0] ack_checkpoint_epoch,
    input  logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] ack_checkpoint_commitment,
    input  logic [PAYLOAD_WIDTH-1:0] ack_checkpoint_payload,

    input  logic access_valid,
    input  logic [VADDR_WIDTH-1:0] access_vaddr,
    input  logic [1:0] access_kind, // 0=read, 1=write, 2=execute
    input  logic [1:0] access_privilege,
    input  logic fault_clear_valid,

    input  logic effect_issue_valid,
    input  logic effect_commit_valid,

    output logic checkpoint_prepare_accept,
    output logic checkpoint_prepare_rejected,
    output logic checkpoint_snapshot_persist_accept,
    output logic checkpoint_snapshot_persist_rejected,
    output logic checkpoint_anchor_commit_request,
    output logic checkpoint_commit_event,
    output logic checkpoint_candidate_pending,
    output logic checkpoint_snapshot_durable,
    output logic checkpoint_restore_accept,
    output logic checkpoint_restore_rejected,
    output logic checkpoint_restore_mismatch,
    output logic [PAYLOAD_WIDTH-1:0] checkpoint_request_payload,

    output logic live_execution_ready,
    output logic [ROOT_WIDTH-1:0] live_root,
    output logic [ASID_WIDTH-1:0] live_asid,
    output logic [TRANSLATION_EPOCH_WIDTH-1:0] live_translation_epoch,
    output logic [VPN_WIDTH-1:0] live_vpn,
    output logic [PPN_WIDTH-1:0] live_ppn,
    output logic live_perm_r,
    output logic live_perm_w,
    output logic live_perm_x,
    output logic live_perm_u,
    output logic live_fault_pending,
    output logic [VADDR_WIDTH-1:0] live_fault_vaddr,
    output logic [FAULT_CAUSE_WIDTH-1:0] live_fault_cause,

    output logic translation_access_accept,
    output logic page_fault,
    output logic [PADDR_WIDTH-1:0] translated_paddr,
    output logic stale_or_foreign_translation_rejected,
    output logic fault_clear_accept,
    output logic speculative_effect_pending,
    output logic visible_effect,
    output logic speculation_kill
);

    localparam logic [FAULT_CAUSE_WIDTH-1:0] FAULT_UNMAPPED = 3'd1;
    localparam logic [FAULT_CAUSE_WIDTH-1:0] FAULT_PERMISSION = 3'd2;
    localparam logic [FAULT_CAUSE_WIDTH-1:0] FAULT_PRIVILEGE = 3'd3;

    logic pending_valid, durable, runtime_ready;
    logic [CHECKPOINT_REF_WIDTH-1:0] pending_ref;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] pending_epoch;
    logic [CHECKPOINT_COMMITMENT_WIDTH-1:0] pending_commitment;
    logic [PAYLOAD_WIDTH-1:0] pending_payload;
    logic [PAYLOAD_WIDTH-1:0] restore_exact_payload;
    logic anchor_epoch_exhausted;
    logic [CHECKPOINT_EPOCH_WIDTH-1:0] expected_candidate_epoch;
    logic candidate_exact_live_state, persisted_exact, ack_exact, anchored_snapshot_exact;
    logic vpn_match, permission_ok, privilege_ok, fault_boundary, effect_issue_accept;

    assign restore_exact_payload = {
        restore_base_payload,
        restore_root,
        restore_asid,
        restore_translation_epoch,
        restore_vpn,
        restore_ppn,
        restore_perm_r,
        restore_perm_w,
        restore_perm_x,
        restore_perm_u,
        restore_fault_pending,
        restore_fault_vaddr,
        restore_fault_cause
    };

    assign anchor_epoch_exhausted = current_anchor_valid && (&current_anchor_epoch);
    assign expected_candidate_epoch = current_anchor_valid
        ? current_anchor_epoch + {{(CHECKPOINT_EPOCH_WIDTH-1){1'b0}}, 1'b1}
        : {{(CHECKPOINT_EPOCH_WIDTH-1){1'b0}}, 1'b1};
    assign candidate_exact_live_state = candidate_checkpoint_payload == committed_checkpoint_payload;

    assign checkpoint_prepare_accept = checkpoint_prepare_valid && !recovery_begin && !restore_valid
        && !checkpoint_abort && !pending_valid && !anchor_epoch_exhausted
        && candidate_checkpoint_ref != '0 && candidate_checkpoint_commitment != '0
        && candidate_checkpoint_epoch == expected_candidate_epoch
        && candidate_commitment_verified && candidate_exact_live_state;
    assign checkpoint_prepare_rejected = checkpoint_prepare_valid && !checkpoint_prepare_accept;

    assign persisted_exact = pending_valid
        && persisted_checkpoint_ref == pending_ref
        && persisted_checkpoint_epoch == pending_epoch
        && persisted_checkpoint_commitment == pending_commitment
        && persisted_checkpoint_payload == pending_payload;
    assign checkpoint_snapshot_persist_accept = snapshot_persisted_valid && !recovery_begin
        && !restore_valid && !checkpoint_abort && persisted_exact;
    assign checkpoint_snapshot_persist_rejected = snapshot_persisted_valid && !checkpoint_snapshot_persist_accept;
    assign checkpoint_candidate_pending = pending_valid;
    assign checkpoint_snapshot_durable = durable;
    assign checkpoint_anchor_commit_request = pending_valid && durable;

    assign ack_exact = pending_valid
        && ack_checkpoint_ref == pending_ref
        && ack_checkpoint_epoch == pending_epoch
        && ack_checkpoint_commitment == pending_commitment
        && ack_checkpoint_payload == pending_payload;
    assign checkpoint_commit_event = anchor_commit_ack_valid && !recovery_begin && !restore_valid
        && !checkpoint_abort && checkpoint_anchor_commit_request && ack_exact;

    assign anchored_snapshot_exact = current_anchor_valid && snapshot_commitment_verified
        && snapshot_checkpoint_ref == current_anchor_ref
        && snapshot_checkpoint_epoch == current_anchor_epoch
        && snapshot_checkpoint_commitment == current_anchor_commitment
        && snapshot_checkpoint_payload == current_anchor_payload
        && snapshot_checkpoint_payload == restore_exact_payload;
    assign checkpoint_restore_accept = restore_valid && !recovery_begin && anchored_snapshot_exact;
    assign checkpoint_restore_rejected = restore_valid && !checkpoint_restore_accept;
    assign checkpoint_restore_mismatch = restore_valid && !anchored_snapshot_exact;
    assign stale_or_foreign_translation_rejected = checkpoint_restore_mismatch;
    assign checkpoint_request_payload = pending_payload;

    assign live_execution_ready = runtime_ready;
    assign vpn_match = access_vaddr[VADDR_WIDTH-1:PAGE_OFFSET_WIDTH] == live_vpn;
    assign permission_ok = (access_kind == 2'd0 && live_perm_r)
        || (access_kind == 2'd1 && live_perm_w)
        || (access_kind == 2'd2 && live_perm_x);
    assign privilege_ok = (access_privilege != 2'd0) || live_perm_u;

    assign translation_access_accept = access_valid && runtime_ready && !recovery_begin && !restore_valid
        && !live_fault_pending && vpn_match && permission_ok && privilege_ok;
    assign page_fault = access_valid && runtime_ready && !recovery_begin && !restore_valid
        && !live_fault_pending && !translation_access_accept;
    assign translated_paddr = translation_access_accept
        ? {live_ppn, access_vaddr[PAGE_OFFSET_WIDTH-1:0]} : '0;
    assign fault_clear_accept = fault_clear_valid && runtime_ready && live_fault_pending
        && !recovery_begin && !restore_valid;

    assign fault_boundary = recovery_begin || restore_valid || page_fault || fault_clear_accept;
    assign speculation_kill = fault_boundary;
    assign effect_issue_accept = effect_issue_valid && runtime_ready && !speculative_effect_pending
        && !fault_boundary && !live_fault_pending;
    assign visible_effect = effect_commit_valid && speculative_effect_pending && !fault_boundary
        && !live_fault_pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_valid <= 1'b0;
            durable <= 1'b0;
            pending_ref <= '0;
            pending_epoch <= '0;
            pending_commitment <= '0;
            pending_payload <= '0;
            runtime_ready <= 1'b0;
            live_root <= '0;
            live_asid <= '0;
            live_translation_epoch <= '0;
            live_vpn <= '0;
            live_ppn <= '0;
            live_perm_r <= 1'b0;
            live_perm_w <= 1'b0;
            live_perm_x <= 1'b0;
            live_perm_u <= 1'b0;
            live_fault_pending <= 1'b0;
            live_fault_vaddr <= '0;
            live_fault_cause <= '0;
            speculative_effect_pending <= 1'b0;
        end else begin
            if (recovery_begin || restore_valid || checkpoint_abort || checkpoint_commit_event) begin
                pending_valid <= 1'b0;
                durable <= 1'b0;
            end else if (checkpoint_prepare_accept) begin
                pending_valid <= 1'b1;
                durable <= 1'b0;
                pending_ref <= candidate_checkpoint_ref;
                pending_epoch <= candidate_checkpoint_epoch;
                pending_commitment <= candidate_checkpoint_commitment;
                pending_payload <= candidate_checkpoint_payload;
            end
            if (checkpoint_snapshot_persist_accept)
                durable <= 1'b1;

            if (recovery_begin) begin
                runtime_ready <= 1'b0;
                speculative_effect_pending <= 1'b0;
            end else if (checkpoint_restore_accept) begin
                runtime_ready <= 1'b1;
                live_root <= restore_root;
                live_asid <= restore_asid;
                live_translation_epoch <= restore_translation_epoch;
                live_vpn <= restore_vpn;
                live_ppn <= restore_ppn;
                live_perm_r <= restore_perm_r;
                live_perm_w <= restore_perm_w;
                live_perm_x <= restore_perm_x;
                live_perm_u <= restore_perm_u;
                live_fault_pending <= restore_fault_pending;
                live_fault_vaddr <= restore_fault_vaddr;
                live_fault_cause <= restore_fault_cause;
                speculative_effect_pending <= 1'b0;
            end else begin
                if (page_fault) begin
                    live_fault_pending <= 1'b1;
                    live_fault_vaddr <= access_vaddr;
                    if (!vpn_match)
                        live_fault_cause <= FAULT_UNMAPPED;
                    else if (!privilege_ok)
                        live_fault_cause <= FAULT_PRIVILEGE;
                    else
                        live_fault_cause <= FAULT_PERMISSION;
                end else if (fault_clear_accept) begin
                    live_fault_pending <= 1'b0;
                    live_fault_vaddr <= '0;
                    live_fault_cause <= '0;
                end

                if (fault_boundary)
                    speculative_effect_pending <= 1'b0;
                else if (effect_issue_accept)
                    speculative_effect_pending <= 1'b1;
                else if (visible_effect)
                    speculative_effect_pending <= 1'b0;
            end
        end
    end

endmodule
