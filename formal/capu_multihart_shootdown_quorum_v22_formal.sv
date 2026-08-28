module capu_multihart_shootdown_quorum_v22_formal;
  (* gclk *) reg clk;
  (* anyseq *) logic rst_n,recovery_begin,restore_valid,shootdown_launch_valid,ack0_valid,ack1_valid;
  (* anyseq *) logic [3:0] launch_generation,ack0_generation,ack1_generation;
  (* anyseq *) logic [2:0] launch_asid,ack0_asid,ack1_asid;
  (* anyseq *) logic [3:0] launch_epoch,ack0_epoch,ack1_epoch;
  (* anyseq *) logic [3:0] launch_vpn,ack0_vpn,ack1_vpn;
  (* anyseq *) logic [1:0] launch_required_harts;

  logic shootdown_launch_accept,shootdown_launch_rejected,shootdown_pending;
  logic [3:0] pending_generation;
  logic [2:0] pending_asid;
  logic [3:0] pending_epoch,pending_vpn;
  logic [1:0] required_harts,ack_bitmap;
  logic ack0_accept,ack0_rejected,ack1_accept,ack1_rejected,quorum_complete;
  logic global_translation_authority_ready,speculation_kill;

  capu_multihart_shootdown_quorum_v22 dut(.*);

  reg past_valid=0;
  always @(posedge clk) past_valid <= 1'b1;
  always @(*) begin
    if(!past_valid) assume(!rst_n);
    else assume(rst_n);
  end

  always @(posedge clk) if(past_valid && rst_n) begin
    assert(!(shootdown_launch_accept && shootdown_launch_rejected));
    assert(!(ack0_accept && ack0_rejected));
    assert(!(ack1_accept && ack1_rejected));

    if(shootdown_launch_accept) begin
      assert(launch_required_harts != 2'b00);
      assert(!shootdown_pending);
    end

    if(ack0_accept) begin
      assert(shootdown_pending);
      assert(required_harts[0]);
      assert(!ack_bitmap[0]);
      assert(ack0_generation == pending_generation);
      assert(ack0_asid == pending_asid);
      assert(ack0_epoch == pending_epoch);
      assert(ack0_vpn == pending_vpn);
    end

    if(ack1_accept) begin
      assert(shootdown_pending);
      assert(required_harts[1]);
      assert(!ack_bitmap[1]);
      assert(ack1_generation == pending_generation);
      assert(ack1_asid == pending_asid);
      assert(ack1_epoch == pending_epoch);
      assert(ack1_vpn == pending_vpn);
    end

    if(shootdown_pending)
      assert(!global_translation_authority_ready);

    if(quorum_complete) begin
      assert(shootdown_pending);
      assert(required_harts != 2'b00);
      assert((((ack_bitmap | {ack1_accept,ack0_accept}) & required_harts) == required_harts));
    end

    if(recovery_begin || restore_valid || shootdown_launch_valid || shootdown_pending || ack0_rejected || ack1_rejected || quorum_complete)
      assert(speculation_kill);

    if($past(recovery_begin || restore_valid)) begin
      assert(!shootdown_pending);
      assert(ack_bitmap == 2'b00);
    end

    if($past(shootdown_pending) && !$past(recovery_begin) && !$past(restore_valid) && !$past(quorum_complete) && !$past(shootdown_launch_accept)) begin
      if($past(ack0_accept)) assert(ack_bitmap[0]);
      if($past(ack1_accept)) assert(ack_bitmap[1]);
    end
  end

  always @(posedge clk) if(past_valid && rst_n) begin
    cover(shootdown_launch_accept);
    cover(ack0_rejected);
    cover(ack0_accept);
    cover(ack_bitmap == 2'b01 && shootdown_pending);
    cover(ack1_rejected);
    cover(quorum_complete);
    cover(global_translation_authority_ready && $past(quorum_complete));
  end
endmodule
