module capu_tlb_shootdown_authority_v21_formal;
  (* gclk *) reg clk;
  (* anyseq *) logic rst_n,recovery_begin,restore_valid,restore_tlb_valid,fill_valid,lookup_valid,access_write,access_exec,access_user,shootdown_valid,shootdown_ack_valid;
  (* anyseq *) logic [2:0] restore_asid,fill_asid,live_asid,shootdown_asid,ack_asid;
  (* anyseq *) logic [3:0] restore_epoch,fill_epoch,live_epoch,shootdown_epoch,ack_epoch;
  (* anyseq *) logic [3:0] restore_vpn,fill_vpn,lookup_vpn,shootdown_vpn,ack_vpn,restore_ppn,fill_ppn;
  (* anyseq *) logic [1:0] lookup_offset;
  (* anyseq *) logic restore_r,restore_w,restore_x,restore_u,fill_r,fill_w,fill_x,fill_u;
  logic tlb_valid,tlb_hit,stale_rejected,permission_rejected,shootdown_pending,shootdown_ack_accept,shootdown_ack_rejected,speculation_kill;
  logic [5:0] paddr;
  logic [2:0] live_tlb_asid,live_shootdown_asid;
  logic [3:0] live_tlb_epoch,live_tlb_vpn,live_tlb_ppn,live_shootdown_epoch,live_shootdown_vpn;
  capu_tlb_shootdown_authority_v21 dut(.*);

  reg past_valid=0;
  always @(posedge clk) past_valid<=1'b1;
  always @(*) begin
    if(!past_valid) assume(!rst_n); else assume(rst_n);
  end

  always @(posedge clk) if(past_valid && rst_n) begin
    assert(!(tlb_hit && stale_rejected));
    assert(!(tlb_hit && permission_rejected));
    assert(!(shootdown_ack_accept && shootdown_ack_rejected));
    if(tlb_hit) begin
      assert(live_tlb_asid==live_asid);
      assert(live_tlb_epoch==live_epoch);
      assert(live_tlb_vpn==lookup_vpn);
      assert(paddr=={live_tlb_ppn,lookup_offset});
    end
    if(shootdown_ack_accept) begin
      assert(ack_asid==live_shootdown_asid);
      assert(ack_epoch==live_shootdown_epoch);
      assert(ack_vpn==live_shootdown_vpn);
    end
    if(recovery_begin || restore_valid || stale_rejected || permission_rejected || shootdown_valid || shootdown_ack_accept) assert(speculation_kill);
    if(shootdown_pending) assert(!tlb_hit);
    if($past(recovery_begin)) begin
      assert(!tlb_valid);
      assert(!shootdown_pending);
    end
  end

  always @(posedge clk) if(past_valid && rst_n) begin
    cover(tlb_hit);
    cover(stale_rejected);
    cover(permission_rejected);
    cover(shootdown_pending);
    cover(shootdown_ack_rejected);
    cover(shootdown_ack_accept);
  end
endmodule
