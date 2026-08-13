module capu_tlb_shootdown_authority_v21_formal;
  logic clk; always #1 clk=~clk;
  initial clk=0;
  logic rst_n=0; always_ff @(posedge clk) rst_n<=1'b1;
  (* anyseq *) logic recovery_begin,restore_valid,restore_tlb_valid,fill_valid,lookup_valid,access_write,access_exec,access_user,shootdown_valid,shootdown_ack_valid;
  (* anyseq *) logic [2:0] restore_asid,fill_asid,live_asid,shootdown_asid,ack_asid;
  (* anyseq *) logic [3:0] restore_epoch,fill_epoch,live_epoch,shootdown_epoch,ack_epoch;
  (* anyseq *) logic [3:0] restore_vpn,fill_vpn,lookup_vpn,shootdown_vpn,ack_vpn,restore_ppn,fill_ppn;
  (* anyseq *) logic [1:0] lookup_offset;
  (* anyseq *) logic restore_r,restore_w,restore_x,restore_u,fill_r,fill_w,fill_x,fill_u;
  logic tlb_valid,tlb_hit,stale_rejected,permission_rejected,shootdown_pending,shootdown_ack_accept,shootdown_ack_rejected,speculation_kill;
  logic [5:0] paddr;
  capu_tlb_shootdown_authority_v21 dut(.*);
  always_ff @(posedge clk) if(rst_n) begin
    assert(!(tlb_hit && stale_rejected));
    assert(!(tlb_hit && permission_rejected));
    assert(!(shootdown_ack_accept && shootdown_ack_rejected));
    if(tlb_hit) begin
      assert(dut.tlb_asid==live_asid); assert(dut.tlb_epoch==live_epoch); assert(dut.tlb_vpn==lookup_vpn);
      assert(paddr=={dut.tlb_ppn,lookup_offset});
    end
    if(shootdown_ack_accept) begin
      assert(ack_asid==dut.pending_asid); assert(ack_epoch==dut.pending_epoch); assert(ack_vpn==dut.pending_vpn);
    end
    if(recovery_begin || restore_valid || stale_rejected || permission_rejected || shootdown_valid || shootdown_ack_accept) assert(speculation_kill);
    if(shootdown_pending) assert(!tlb_hit);
    cover(tlb_hit);
    cover(stale_rejected);
    cover(permission_rejected);
    cover(shootdown_pending);
    cover(shootdown_ack_rejected);
    cover(shootdown_ack_accept);
  end
endmodule
