`timescale 1ns/1ps
module capu_tlb_shootdown_authority_v21_tb;
  logic clk=0,rst_n=0,recovery_begin=0,restore_valid=0,restore_tlb_valid=0;
  logic [2:0] restore_asid=0,fill_asid=0,live_asid=0,shootdown_asid=0,ack_asid=0;
  logic [3:0] restore_epoch=0,fill_epoch=0,live_epoch=0,shootdown_epoch=0,ack_epoch=0;
  logic [3:0] restore_vpn=0,fill_vpn=0,lookup_vpn=0,shootdown_vpn=0,ack_vpn=0;
  logic [3:0] restore_ppn=0,fill_ppn=0;
  logic restore_r=0,restore_w=0,restore_x=0,restore_u=0;
  logic fill_valid=0,fill_r=0,fill_w=0,fill_x=0,fill_u=0;
  logic lookup_valid=0; logic [1:0] lookup_offset=0; logic access_write=0,access_exec=0,access_user=0;
  logic shootdown_valid=0,shootdown_ack_valid=0;
  logic tlb_valid,tlb_hit,stale_rejected,permission_rejected,shootdown_pending,shootdown_ack_accept,shootdown_ack_rejected,speculation_kill;
  logic [5:0] paddr;
  capu_tlb_shootdown_authority_v21 dut(.*);
  always #5 clk=~clk;
  task tick; begin @(posedge clk); #1; end endtask
  initial begin
    repeat(2) tick; rst_n=1; tick;
    restore_valid=1; restore_tlb_valid=1; restore_asid=3; restore_epoch=7; restore_vpn=4; restore_ppn=9;
    restore_r=1; restore_x=1; restore_u=1; tick; restore_valid=0;
    live_asid=3; live_epoch=7; lookup_vpn=4; lookup_offset=2; lookup_valid=1; tick;
    if(!tlb_hit || paddr!={4'd9,2'd2}) $fatal(1,"fresh hit failed");
    $display("fresh_tlb_hit exact=1 paddr=%0d",paddr);
    live_epoch=8; tick;
    if(!stale_rejected || tlb_hit) $fatal(1,"stale epoch accepted");
    $display("stale_epoch rejected=1 speculation_killed=%0d",speculation_kill);
    live_epoch=7; access_write=1; tick;
    if(!permission_rejected || tlb_hit) $fatal(1,"permission mismatch accepted");
    $display("permission_mismatch rejected=1");
    access_write=0; lookup_valid=0;
    shootdown_valid=1; shootdown_asid=3; shootdown_epoch=8; shootdown_vpn=4; tick; shootdown_valid=0;
    if(tlb_valid || !shootdown_pending) $fatal(1,"shootdown did not invalidate");
    $display("shootdown targeted=1 stale_entry_invalidated=1");
    shootdown_ack_valid=1; ack_asid=2; ack_epoch=8; ack_vpn=4; tick;
    if(!shootdown_ack_rejected || !shootdown_pending) $fatal(1,"foreign ack accepted");
    $display("foreign_shootdown_ack rejected=1");
    ack_asid=3; tick;
    if(!shootdown_ack_accept) $fatal(1,"exact ack rejected");
    shootdown_ack_valid=0; tick;
    if(shootdown_pending) $fatal(1,"shootdown remained pending");
    $display("exact_shootdown_ack accepted=1");
    fill_valid=1; fill_asid=3; fill_epoch=8; fill_vpn=4; fill_ppn=10; fill_r=1; fill_x=1; fill_u=1; tick; fill_valid=0;
    live_epoch=8; lookup_valid=1; tick;
    if(!tlb_hit || paddr!={4'd10,2'd2}) $fatal(1,"refill failed");
    $display("post_shootdown_refill fresh=1");
    recovery_begin=1; tick; recovery_begin=0; lookup_valid=0;
    if(tlb_valid) $fatal(1,"TLB authority survived recovery");
    $display("recovery old_tlb_authority_destroyed=1");
    $display("CAPU_VCML_TLB_SHOOTDOWN_V21_PASS");
    $finish;
  end
endmodule
