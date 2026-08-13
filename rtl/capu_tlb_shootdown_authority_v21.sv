module capu_tlb_shootdown_authority_v21 #(
    parameter int ASID_WIDTH=3,
    parameter int EPOCH_WIDTH=4,
    parameter int VPN_WIDTH=4,
    parameter int PPN_WIDTH=4,
    parameter int PAGE_OFFSET_WIDTH=2
) (
    input logic clk,
    input logic rst_n,
    input logic recovery_begin,
    input logic restore_valid,
    input logic restore_tlb_valid,
    input logic [ASID_WIDTH-1:0] restore_asid,
    input logic [EPOCH_WIDTH-1:0] restore_epoch,
    input logic [VPN_WIDTH-1:0] restore_vpn,
    input logic [PPN_WIDTH-1:0] restore_ppn,
    input logic restore_r, restore_w, restore_x, restore_u,
    input logic fill_valid,
    input logic [ASID_WIDTH-1:0] fill_asid,
    input logic [EPOCH_WIDTH-1:0] fill_epoch,
    input logic [VPN_WIDTH-1:0] fill_vpn,
    input logic [PPN_WIDTH-1:0] fill_ppn,
    input logic fill_r, fill_w, fill_x, fill_u,
    input logic lookup_valid,
    input logic [ASID_WIDTH-1:0] live_asid,
    input logic [EPOCH_WIDTH-1:0] live_epoch,
    input logic [VPN_WIDTH-1:0] lookup_vpn,
    input logic [PAGE_OFFSET_WIDTH-1:0] lookup_offset,
    input logic access_write,
    input logic access_exec,
    input logic access_user,
    input logic shootdown_valid,
    input logic [ASID_WIDTH-1:0] shootdown_asid,
    input logic [EPOCH_WIDTH-1:0] shootdown_epoch,
    input logic [VPN_WIDTH-1:0] shootdown_vpn,
    input logic shootdown_ack_valid,
    input logic [ASID_WIDTH-1:0] ack_asid,
    input logic [EPOCH_WIDTH-1:0] ack_epoch,
    input logic [VPN_WIDTH-1:0] ack_vpn,
    output logic tlb_valid,
    output logic tlb_hit,
    output logic stale_rejected,
    output logic permission_rejected,
    output logic shootdown_pending,
    output logic shootdown_ack_accept,
    output logic shootdown_ack_rejected,
    output logic [PPN_WIDTH+PAGE_OFFSET_WIDTH-1:0] paddr,
    output logic speculation_kill
);
    logic [ASID_WIDTH-1:0] tlb_asid;
    logic [EPOCH_WIDTH-1:0] tlb_epoch;
    logic [VPN_WIDTH-1:0] tlb_vpn;
    logic [PPN_WIDTH-1:0] tlb_ppn;
    logic tlb_r,tlb_w,tlb_x,tlb_u;
    logic [ASID_WIDTH-1:0] pending_asid;
    logic [EPOCH_WIDTH-1:0] pending_epoch;
    logic [VPN_WIDTH-1:0] pending_vpn;
    logic fresh_match, permission_ok, ack_exact;

    assign fresh_match = tlb_valid && tlb_asid==live_asid && tlb_epoch==live_epoch && tlb_vpn==lookup_vpn;
    assign permission_ok = (!access_write || tlb_w) && (!access_exec || tlb_x) && (!access_user || tlb_u) && ((access_write||access_exec) || tlb_r);
    assign tlb_hit = lookup_valid && fresh_match && permission_ok && !shootdown_pending && !recovery_begin && !restore_valid;
    assign stale_rejected = lookup_valid && tlb_valid && (!fresh_match) && !recovery_begin && !restore_valid;
    assign permission_rejected = lookup_valid && fresh_match && !permission_ok && !recovery_begin && !restore_valid;
    assign paddr = {tlb_ppn,lookup_offset};
    assign ack_exact = shootdown_pending && ack_asid==pending_asid && ack_epoch==pending_epoch && ack_vpn==pending_vpn;
    assign shootdown_ack_accept = shootdown_ack_valid && ack_exact;
    assign shootdown_ack_rejected = shootdown_ack_valid && !ack_exact;
    assign speculation_kill = recovery_begin || restore_valid || shootdown_valid || shootdown_ack_accept || stale_rejected || permission_rejected;

    always_ff @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        tlb_valid<=1'b0; tlb_asid<='0; tlb_epoch<='0; tlb_vpn<='0; tlb_ppn<='0;
        tlb_r<=1'b0; tlb_w<=1'b0; tlb_x<=1'b0; tlb_u<=1'b0;
        shootdown_pending<=1'b0; pending_asid<='0; pending_epoch<='0; pending_vpn<='0;
      end else begin
        if(recovery_begin) begin
          tlb_valid<=1'b0; shootdown_pending<=1'b0;
        end else if(restore_valid) begin
          tlb_valid<=restore_tlb_valid;
          tlb_asid<=restore_asid; tlb_epoch<=restore_epoch; tlb_vpn<=restore_vpn; tlb_ppn<=restore_ppn;
          tlb_r<=restore_r; tlb_w<=restore_w; tlb_x<=restore_x; tlb_u<=restore_u;
          shootdown_pending<=1'b0;
        end else begin
          if(fill_valid && !shootdown_pending) begin
            tlb_valid<=1'b1; tlb_asid<=fill_asid; tlb_epoch<=fill_epoch; tlb_vpn<=fill_vpn; tlb_ppn<=fill_ppn;
            tlb_r<=fill_r; tlb_w<=fill_w; tlb_x<=fill_x; tlb_u<=fill_u;
          end
          if(shootdown_valid && !shootdown_pending) begin
            shootdown_pending<=1'b1; pending_asid<=shootdown_asid; pending_epoch<=shootdown_epoch; pending_vpn<=shootdown_vpn;
            if(tlb_valid && tlb_asid==shootdown_asid && tlb_vpn==shootdown_vpn && tlb_epoch<=shootdown_epoch) tlb_valid<=1'b0;
          end
          if(shootdown_ack_accept) shootdown_pending<=1'b0;
        end
      end
    end
endmodule
