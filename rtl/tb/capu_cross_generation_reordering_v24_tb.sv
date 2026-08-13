`timescale 1ns/1ps
module capu_cross_generation_reordering_v24_tb;
  logic clk=0,rst_n=0,recovery_begin=0,restore_valid=0;
  logic shootdown_launch_valid=0;
  logic [3:0] launch_generation=0,delivery0_generation=0,delivery1_generation=0,ack0_generation=0,ack1_generation=0;
  logic [2:0] launch_asid=0,delivery0_asid=0,delivery1_asid=0,ack0_asid=0,ack1_asid=0;
  logic [3:0] launch_epoch=0,delivery0_epoch=0,delivery1_epoch=0,ack0_epoch=0,ack1_epoch=0;
  logic [3:0] launch_vpn=0,delivery0_vpn=0,delivery1_vpn=0,ack0_vpn=0,ack1_vpn=0;
  logic [1:0] launch_required_harts=0;
  logic delivery0_valid=0,delivery1_valid=0,ack0_valid=0,ack1_valid=0;

  logic shootdown_launch_accept,shootdown_launch_rejected,shootdown_pending,last_retired_valid;
  logic [3:0] pending_generation,last_retired_generation;
  logic [2:0] pending_asid;
  logic [3:0] pending_epoch,pending_vpn;
  logic [1:0] required_harts,delivered_bitmap,ack_bitmap,quarantined_delivery_bitmap,quarantined_ack_bitmap;
  logic [2:0] quarantine_events;
  logic delivery0_accept,delivery0_quarantined,delivery1_accept,delivery1_quarantined;
  logic ack0_accept,ack0_rejected,ack0_quarantined,ack1_accept,ack1_rejected,ack1_quarantined;
  logic quorum_complete,global_translation_authority_ready,speculation_kill;

  capu_cross_generation_reordering_v24 dut(.*);
  always #5 clk=~clk;

  task automatic launch(input [3:0] gen,input bit expect_accept);
    begin
      @(negedge clk); launch_generation=gen; launch_asid=3'd2; launch_epoch=4'd7; launch_vpn=4'd9; launch_required_harts=2'b11; shootdown_launch_valid=1;
      #1;
      if(expect_accept && !shootdown_launch_accept) $fatal(1,"launch expected accept");
      if(!expect_accept && !shootdown_launch_rejected) $fatal(1,"launch expected reject");
      @(posedge clk); #1; shootdown_launch_valid=0;
    end
  endtask

  task automatic d0(input [3:0] gen,input bit accept,input bit quarantine);
    begin
      @(negedge clk); delivery0_generation=gen;delivery0_asid=3'd2;delivery0_epoch=4'd7;delivery0_vpn=4'd9;delivery0_valid=1;#1;
      if(delivery0_accept!==accept || delivery0_quarantined!==quarantine) $fatal(1,"d0 mismatch");
      @(posedge clk);#1;delivery0_valid=0;
    end
  endtask
  task automatic d1(input [3:0] gen,input bit accept,input bit quarantine);
    begin
      @(negedge clk); delivery1_generation=gen;delivery1_asid=3'd2;delivery1_epoch=4'd7;delivery1_vpn=4'd9;delivery1_valid=1;#1;
      if(delivery1_accept!==accept || delivery1_quarantined!==quarantine) $fatal(1,"d1 mismatch");
      @(posedge clk);#1;delivery1_valid=0;
    end
  endtask
  task automatic a0(input [3:0] gen,input bit accept,input bit quarantine,input bit rejected);
    begin
      @(negedge clk); ack0_generation=gen;ack0_asid=3'd2;ack0_epoch=4'd7;ack0_vpn=4'd9;ack0_valid=1;#1;
      if(ack0_accept!==accept || ack0_quarantined!==quarantine || ack0_rejected!==rejected) $fatal(1,"a0 mismatch");
      @(posedge clk);#1;ack0_valid=0;
    end
  endtask
  task automatic a1(input [3:0] gen,input bit accept,input bit quarantine,input bit rejected);
    begin
      @(negedge clk); ack1_generation=gen;ack1_asid=3'd2;ack1_epoch=4'd7;ack1_vpn=4'd9;ack1_valid=1;#1;
      if(ack1_accept!==accept || ack1_quarantined!==quarantine || ack1_rejected!==rejected) $fatal(1,"a1 mismatch");
      @(posedge clk);#1;ack1_valid=0;
    end
  endtask

  initial begin
    repeat(2) @(posedge clk); rst_n=1;

    launch(4'd5,1);
    d0(4'd5,1,0); a0(4'd5,1,0,0);
    d1(4'd5,1,0);
    @(negedge clk); ack1_generation=4'd5;ack1_asid=3'd2;ack1_epoch=4'd7;ack1_vpn=4'd9;ack1_valid=1;#1;
    if(!ack1_accept || !quorum_complete) $fatal(1,"generation 5 quorum expected");
    @(posedge clk);#1;ack1_valid=0;
    if(!last_retired_valid || last_retired_generation!=4'd5 || !global_translation_authority_ready) $fatal(1,"gen5 retire failed");
    $display("generation_n retired=5 authority_reopened=1");

    launch(4'd6,1);
    if(pending_generation!=4'd6 || delivered_bitmap!=0 || ack_bitmap!=0) $fatal(1,"gen6 launch state");

    d0(4'd5,0,1);
    if(delivered_bitmap[0] || !quarantined_delivery_bitmap[0] || quarantine_events==0) $fatal(1,"stale delivery mutated gen6");
    $display("late_generation_n_delivery quarantined=1 current_generation=6 no_authority_mutation=1");

    a1(4'd5,0,1,0);
    if(ack_bitmap[1] || !quarantined_ack_bitmap[1]) $fatal(1,"stale ack mutated gen6");
    $display("late_generation_n_ack quarantined=1 current_generation=6 no_authority_mutation=1");

    a0(4'd6,0,0,1);
    if(ack_bitmap[0]) $fatal(1,"current ack without delivery mutated state");
    $display("reordered_current_ack_before_delivery rejected=1");

    d0(4'd6,1,0); a0(4'd6,1,0,0);
    d1(4'd6,1,0);
    @(negedge clk); ack1_generation=4'd6;ack1_asid=3'd2;ack1_epoch=4'd7;ack1_vpn=4'd9;ack1_valid=1;#1;
    if(!ack1_accept || !quorum_complete) $fatal(1,"generation 6 quorum expected");
    @(posedge clk);#1;ack1_valid=0;
    if(last_retired_generation!=4'd6 || !global_translation_authority_ready) $fatal(1,"gen6 retire failed");
    $display("generation_n_plus_1 completed_only_from_generation_6_evidence=1 authority_reopened=1");

    launch(4'd6,0);
    $display("generation_reuse rejected=1 last_retired=6");

    launch(4'd7,1);
    @(negedge clk); recovery_begin=1; @(posedge clk); #1; recovery_begin=0;
    if(shootdown_pending || delivered_bitmap!=0 || ack_bitmap!=0 || quarantined_delivery_bitmap!=0 || quarantined_ack_bitmap!=0 || quarantine_events!=0) $fatal(1,"recovery did not destroy in-flight state");
    $display("recovery in_flight_quarantine_state_destroyed=1");

    $display("CAPU_VCML_CROSS_GENERATION_V24_PASS");
    $finish;
  end
endmodule
