`timescale 1ns/1ps
module capu_multihart_shootdown_quorum_v22_tb;
  logic clk=0,rst_n=0,recovery_begin=0,restore_valid=0;
  logic shootdown_launch_valid=0;
  logic [3:0] launch_generation=0,ack0_generation=0,ack1_generation=0;
  logic [2:0] launch_asid=0,ack0_asid=0,ack1_asid=0;
  logic [3:0] launch_epoch=0,ack0_epoch=0,ack1_epoch=0;
  logic [3:0] launch_vpn=0,ack0_vpn=0,ack1_vpn=0;
  logic [1:0] launch_required_harts=0;
  logic ack0_valid=0,ack1_valid=0;
  logic shootdown_launch_accept,shootdown_launch_rejected,shootdown_pending;
  logic [3:0] pending_generation;
  logic [2:0] pending_asid;
  logic [3:0] pending_epoch,pending_vpn;
  logic [1:0] required_harts,ack_bitmap;
  logic ack0_accept,ack0_rejected,ack1_accept,ack1_rejected,quorum_complete;
  logic global_translation_authority_ready,speculation_kill;

  capu_multihart_shootdown_quorum_v22 dut(.*);
  always #5 clk=~clk;
  task tick; begin @(posedge clk); #1; end endtask

  initial begin
    repeat(2) tick; rst_n=1; tick;
    if(!global_translation_authority_ready) $fatal(1,"authority not initially ready");

    shootdown_launch_valid=1; launch_generation=4'd9; launch_asid=3'd3; launch_epoch=4'd8; launch_vpn=4'd4; launch_required_harts=2'b11;
    #1; if(!shootdown_launch_accept) $fatal(1,"shootdown launch rejected");
    tick; shootdown_launch_valid=0;
    if(!shootdown_pending || global_translation_authority_ready) $fatal(1,"pending shootdown did not close authority");
    $display("multihart_shootdown launched=1 generation=9 required=11 authority_closed=1");

    ack0_valid=1; ack0_generation=4'd8; ack0_asid=3'd3; ack0_epoch=4'd8; ack0_vpn=4'd4;
    #1; if(!ack0_rejected || ack0_accept) $fatal(1,"stale generation ack accepted");
    $display("stale_generation_ack hart=0 rejected=1");
    tick; ack0_valid=0;

    ack0_valid=1; ack0_generation=4'd9; ack0_asid=3'd3; ack0_epoch=4'd8; ack0_vpn=4'd4;
    #1; if(!ack0_accept) $fatal(1,"exact hart0 ack rejected");
    tick; ack0_valid=0;
    if(ack_bitmap!=2'b01 || !shootdown_pending || global_translation_authority_ready) $fatal(1,"partial quorum broken");
    $display("hart0_ack accepted=1 bitmap=01 quorum=0 authority_closed=1");

    ack0_valid=1; ack0_generation=4'd9; ack0_asid=3'd3; ack0_epoch=4'd8; ack0_vpn=4'd4;
    #1; if(!ack0_rejected || ack0_accept) $fatal(1,"duplicate hart0 ack accepted");
    $display("duplicate_ack hart=0 rejected=1");
    tick; ack0_valid=0;

    ack1_valid=1; ack1_generation=4'd9; ack1_asid=3'd3; ack1_epoch=4'd8; ack1_vpn=4'd5;
    #1; if(!ack1_rejected || ack1_accept) $fatal(1,"foreign VPN ack accepted");
    $display("foreign_target_ack hart=1 rejected=1");
    tick; ack1_valid=0;

    ack1_valid=1; ack1_generation=4'd9; ack1_asid=3'd3; ack1_epoch=4'd8; ack1_vpn=4'd4;
    #1; if(!ack1_accept || !quorum_complete) $fatal(1,"exact hart1 quorum completion rejected");
    $display("hart1_ack accepted=1 effective_bitmap=11 quorum=1");
    tick; ack1_valid=0; tick;
    if(shootdown_pending || !global_translation_authority_ready) $fatal(1,"authority did not reopen after exact quorum");
    $display("exact_quorum complete=1 authority_reopened=1");

    shootdown_launch_valid=1; launch_generation=4'd10; launch_required_harts=2'b11; tick; shootdown_launch_valid=0;
    ack0_valid=1; ack0_generation=4'd10; ack0_asid=3'd3; ack0_epoch=4'd8; ack0_vpn=4'd4; tick; ack0_valid=0;
    recovery_begin=1; tick; recovery_begin=0; tick;
    if(shootdown_pending || ack_bitmap!=2'b00) $fatal(1,"recovery preserved partial quorum authority");
    $display("recovery partial_quorum_destroyed=1");

    shootdown_launch_valid=1; launch_required_harts=2'b00; #1;
    if(!shootdown_launch_rejected || shootdown_launch_accept) $fatal(1,"zero-hart shootdown accepted");
    $display("zero_hart_request rejected=1");

    $display("CAPU_VCML_MULTIHART_SHOOTDOWN_V22_PASS");
    $finish;
  end
endmodule
