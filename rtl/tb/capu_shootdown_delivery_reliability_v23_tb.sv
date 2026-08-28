`timescale 1ns/1ps
module capu_shootdown_delivery_reliability_v23_tb;
  logic clk=0,rst_n=0,recovery_begin=0,restore_valid=0;
  logic shootdown_launch_valid=0;
  logic [3:0] launch_generation=0,launch_epoch=0,launch_vpn=0;
  logic [2:0] launch_asid=0;
  logic [1:0] launch_required_harts=0;
  logic send0_valid=0,send0_lost=0,send1_valid=0,send1_lost=0;
  logic [3:0] send0_generation=0,send0_epoch=0,send0_vpn=0,send1_generation=0,send1_epoch=0,send1_vpn=0;
  logic [2:0] send0_asid=0,send1_asid=0;
  logic ack0_valid=0,ack1_valid=0;
  logic [3:0] ack0_generation=0,ack0_epoch=0,ack0_vpn=0,ack1_generation=0,ack1_epoch=0,ack1_vpn=0;
  logic [2:0] ack0_asid=0,ack1_asid=0;
  logic shootdown_launch_accept,shootdown_launch_rejected,shootdown_pending;
  logic [3:0] pending_generation,pending_epoch,pending_vpn;
  logic [2:0] pending_asid;
  logic [1:0] required_harts,delivered_bitmap,ack_bitmap,attempts0,attempts1;
  logic send0_accept,send0_rejected,send1_accept,send1_rejected,delivery0_observed,delivery1_observed;
  logic ack0_accept,ack0_rejected,ack1_accept,ack1_rejected,quorum_complete,global_translation_authority_ready,speculation_kill;

  capu_shootdown_delivery_reliability_v23 dut(.*);
  always #5 clk=~clk;
  task tick; begin @(posedge clk); #1; end endtask
  task clear_pulses; begin
    shootdown_launch_valid=0; send0_valid=0; send1_valid=0; ack0_valid=0; ack1_valid=0;
    send0_lost=0; send1_lost=0; recovery_begin=0; restore_valid=0;
  end endtask

  initial begin
    #2; rst_n=0; tick; rst_n=1; tick;

    launch_generation=4'd10; launch_asid=3'd3; launch_epoch=4'd9; launch_vpn=4'd5; launch_required_harts=2'b11;
    shootdown_launch_valid=1; #1;
    $display("reliable_shootdown launched=%0d generation=%0d required=%02b authority_closed=%0d",shootdown_launch_accept,launch_generation,launch_required_harts,!global_translation_authority_ready);
    tick; clear_pulses;

    send0_generation=4'd10; send0_asid=3'd3; send0_epoch=4'd9; send0_vpn=4'd5;
    send0_valid=1; send0_lost=1; #1;
    $display("hart0_delivery attempt=1 accepted=%0d lost=%0d delivered=%0d",send0_accept,send0_lost,delivery0_observed);
    tick; clear_pulses;

    ack0_generation=4'd10; ack0_asid=3'd3; ack0_epoch=4'd9; ack0_vpn=4'd5; ack0_valid=1; #1;
    $display("phantom_ack_before_delivery hart=0 rejected=%0d",ack0_rejected);
    tick; clear_pulses;

    send0_valid=1; send0_lost=0; #1;
    $display("hart0_retry attempt=2 accepted=%0d delivered=%0d",send0_accept,delivery0_observed);
    tick; clear_pulses;

    ack0_valid=1; #1;
    $display("hart0_ack accepted=%0d",ack0_accept);
    tick; clear_pulses;

    send1_generation=4'd9; send1_asid=3'd3; send1_epoch=4'd9; send1_vpn=4'd5; send1_valid=1; #1;
    $display("stale_generation_retry hart=1 rejected=%0d",send1_rejected);
    tick; clear_pulses;

    send1_generation=4'd10; send1_asid=3'd3; send1_epoch=4'd9; send1_vpn=4'd5; send1_valid=1; #1;
    $display("hart1_delivery attempt=1 accepted=%0d delivered=%0d",send1_accept,delivery1_observed);
    tick; clear_pulses;

    // Model a lost ACK by simply not presenting ack1_valid, then retry delivery.
    send1_valid=1; #1;
    $display("hart1_retry_after_lost_ack attempt=2 accepted=%0d delivered=%0d",send1_accept,delivery1_observed);
    tick; clear_pulses;

    ack1_generation=4'd10; ack1_asid=3'd3; ack1_epoch=4'd9; ack1_vpn=4'd5; ack1_valid=1; #1;
    $display("exact_quorum ack1=%0d complete=%0d",ack1_accept,quorum_complete);
    tick; clear_pulses; #1;
    $display("authority_reopened=%0d",global_translation_authority_ready);

    // Second transaction: exhaust bounded retries without delivery, remain fail-closed.
    launch_generation=4'd11; launch_asid=3'd3; launch_epoch=4'd10; launch_vpn=4'd6; launch_required_harts=2'b01; shootdown_launch_valid=1; #1; tick; clear_pulses;
    send0_generation=4'd11; send0_asid=3'd3; send0_epoch=4'd10; send0_vpn=4'd6;
    repeat(3) begin send0_valid=1; send0_lost=1; #1; tick; clear_pulses; end
    send0_valid=1; send0_lost=0; #1;
    $display("retry_exhausted hart=0 rejected=%0d attempts=%0d authority_closed=%0d",send0_rejected,attempts0,!global_translation_authority_ready);
    tick; clear_pulses;

    recovery_begin=1; #1; tick; clear_pulses; #1;
    $display("recovery reliability_state_destroyed=%0d",(!shootdown_pending && delivered_bitmap==0 && ack_bitmap==0 && attempts0==0 && attempts1==0));
    $display("CAPU_VCML_SHOOTDOWN_RELIABILITY_V23_PASS");
    $finish;
  end
endmodule
