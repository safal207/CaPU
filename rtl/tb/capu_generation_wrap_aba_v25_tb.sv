`timescale 1ns/1ps
module capu_generation_wrap_aba_v25_tb;
  logic clk=0,rst_n=0,recovery_begin=0,restore_valid=0;
  logic launch_valid; logic [2:0] launch_incarnation; logic [1:0] launch_generation; logic [2:0] launch_asid; logic [3:0] launch_epoch,launch_vpn; logic [1:0] launch_required_harts;
  logic delivery_valid,delivery_hart; logic [2:0] delivery_incarnation; logic [1:0] delivery_generation; logic [2:0] delivery_asid; logic [3:0] delivery_epoch,delivery_vpn;
  logic ack_valid,ack_hart; logic [2:0] ack_incarnation; logic [1:0] ack_generation; logic [2:0] ack_asid; logic [3:0] ack_epoch,ack_vpn;
  logic launch_accept,launch_rejected,pending,retired_valid; logic [2:0] retired_incarnation,pending_incarnation; logic [1:0] retired_generation,pending_generation; logic [2:0] pending_asid; logic [3:0] pending_epoch,pending_vpn; logic [1:0] required_harts,delivered_bitmap,ack_bitmap,quarantined_delivery_bitmap,quarantined_ack_bitmap; logic delivery_accept,delivery_quarantined,ack_accept,ack_quarantined,quorum_complete,global_translation_authority_ready,speculation_kill;
  capu_generation_wrap_aba_v25 dut(.*);
  always #5 clk=~clk;
  task tick; begin @(posedge clk); #1; end endtask
  task launch(input [2:0] inc,input [1:0] gen); begin launch_valid=1;launch_incarnation=inc;launch_generation=gen;launch_asid=3'd2;launch_epoch=4'd9;launch_vpn=4'd6;launch_required_harts=2'b01; #1; if(!launch_accept) $fatal(1,"launch reject"); tick; launch_valid=0; end endtask
  task deliver(input [2:0] inc,input [1:0] gen); begin delivery_valid=1;delivery_hart=0;delivery_incarnation=inc;delivery_generation=gen;delivery_asid=3'd2;delivery_epoch=4'd9;delivery_vpn=4'd6; #1; tick; delivery_valid=0; end endtask
  task ack(input [2:0] inc,input [1:0] gen); begin ack_valid=1;ack_hart=0;ack_incarnation=inc;ack_generation=gen;ack_asid=3'd2;ack_epoch=4'd9;ack_vpn=4'd6; #1; tick; ack_valid=0; end endtask
  initial begin
    launch_valid=0; delivery_valid=0; ack_valid=0;
    launch_incarnation=0;launch_generation=0;launch_asid=0;launch_epoch=0;launch_vpn=0;launch_required_harts=0;
    delivery_hart=0;delivery_incarnation=0;delivery_generation=0;delivery_asid=0;delivery_epoch=0;delivery_vpn=0;
    ack_hart=0;ack_incarnation=0;ack_generation=0;ack_asid=0;ack_epoch=0;ack_vpn=0;
    #2; rst_n=0; tick; rst_n=1;

    launch(3'd1,2'd3); deliver(3'd1,2'd3); if(!delivery_accept) $fatal(1,"delivery3"); ack(3'd1,2'd3);
    if(!retired_valid || retired_generation!=2'd3 || retired_incarnation!=3'd1) $fatal(1,"retire3");
    $display("pre_wrap retired_generation=3 incarnation=1 authority_reopened=%0d",global_translation_authority_ready);

    launch(3'd2,2'd0);
    $display("wrap_launch accepted=1 generation=0 incarnation=2");

    delivery_valid=1; delivery_hart=0; delivery_incarnation=3'd1; delivery_generation=2'd0; delivery_asid=3'd2; delivery_epoch=4'd9; delivery_vpn=4'd6; #1;
    if(!delivery_quarantined || delivery_accept) $fatal(1,"historical delivery not quarantined");
    tick; delivery_valid=0;
    if(delivered_bitmap!=0 || !quarantined_delivery_bitmap[0]) $fatal(1,"delivery ABA mutation");
    $display("historical_same_generation_delivery quarantined=1 old_incarnation=1 current_incarnation=2 no_authority_mutation=1");

    ack_valid=1; ack_hart=0; ack_incarnation=3'd1; ack_generation=2'd0; ack_asid=3'd2; ack_epoch=4'd9; ack_vpn=4'd6; #1;
    if(!ack_quarantined || ack_accept) $fatal(1,"historical ack not quarantined");
    tick; ack_valid=0;
    if(ack_bitmap!=0 || !quarantined_ack_bitmap[0]) $fatal(1,"ack ABA mutation");
    $display("historical_same_generation_ack quarantined=1 old_incarnation=1 current_incarnation=2 no_authority_mutation=1");

    deliver(3'd2,2'd0); if(!delivery_accept) $fatal(1,"current delivery");
    ack(3'd2,2'd0);
    if(!retired_valid || retired_generation!=0 || retired_incarnation!=2) $fatal(1,"retire wrapped");
    $display("wrapped_generation_completed_only_from_incarnation_2_evidence=1 authority_reopened=%0d",global_translation_authority_ready);

    launch_valid=1; launch_incarnation=3'd1; launch_generation=2'd1; launch_asid=3'd2;launch_epoch=4'd9;launch_vpn=4'd6;launch_required_harts=1; #1;
    if(!launch_rejected) $fatal(1,"old incarnation reuse accepted");
    $display("old_incarnation_reuse rejected=1 retired_incarnation=2"); launch_valid=0;

    recovery_begin=1; tick; recovery_begin=0;
    if(pending || quarantined_delivery_bitmap!=0 || quarantined_ack_bitmap!=0) $fatal(1,"recovery cleanup");
    $display("recovery in_flight_aba_quarantine_destroyed=1");
    $display("CAPU_VCML_GENERATION_WRAP_ABA_V25_PASS");
    $finish;
  end
endmodule
