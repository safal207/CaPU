module capu_shootdown_delivery_reliability_v23_formal;
  (* gclk *) reg clk;
  (* anyseq *) logic rst_n,recovery_begin,restore_valid,shootdown_launch_valid;
  (* anyseq *) logic send0_valid,send0_lost,send1_valid,send1_lost,ack0_valid,ack1_valid;
  (* anyseq *) logic [3:0] launch_generation,send0_generation,send1_generation,ack0_generation,ack1_generation;
  (* anyseq *) logic [2:0] launch_asid,send0_asid,send1_asid,ack0_asid,ack1_asid;
  (* anyseq *) logic [3:0] launch_epoch,send0_epoch,send1_epoch,ack0_epoch,ack1_epoch;
  (* anyseq *) logic [3:0] launch_vpn,send0_vpn,send1_vpn,ack0_vpn,ack1_vpn;
  (* anyseq *) logic [1:0] launch_required_harts;

  logic shootdown_launch_accept,shootdown_launch_rejected,shootdown_pending;
  logic [3:0] pending_generation,pending_epoch,pending_vpn;
  logic [2:0] pending_asid;
  logic [1:0] required_harts,delivered_bitmap,ack_bitmap,attempts0,attempts1;
  logic send0_accept,send0_rejected,send1_accept,send1_rejected,delivery0_observed,delivery1_observed;
  logic ack0_accept,ack0_rejected,ack1_accept,ack1_rejected,quorum_complete;
  logic global_translation_authority_ready,speculation_kill;

  capu_shootdown_delivery_reliability_v23 dut(.*);

  reg past_valid=0;
  always @(posedge clk) past_valid <= 1'b1;
  always @(*) begin
    if(!past_valid) assume(!rst_n);
    else assume(rst_n);
  end

  always @(posedge clk) if(past_valid && rst_n) begin
    assert(!(shootdown_launch_accept && shootdown_launch_rejected));
    assert(!(send0_accept && send0_rejected));
    assert(!(send1_accept && send1_rejected));
    assert(!(ack0_accept && ack0_rejected));
    assert(!(ack1_accept && ack1_rejected));

    if(shootdown_pending) begin
      assert(!global_translation_authority_ready);
      assert((ack_bitmap & ~required_harts) == 2'b00);
      assert((ack_bitmap & ~delivered_bitmap) == 2'b00);
    end

    if(send0_accept) begin
      assert(shootdown_pending && required_harts[0] && !ack_bitmap[0]);
      assert(attempts0 < 2'd3);
      assert(send0_generation==pending_generation && send0_asid==pending_asid && send0_epoch==pending_epoch && send0_vpn==pending_vpn);
    end
    if(send1_accept) begin
      assert(shootdown_pending && required_harts[1] && !ack_bitmap[1]);
      assert(attempts1 < 2'd3);
      assert(send1_generation==pending_generation && send1_asid==pending_asid && send1_epoch==pending_epoch && send1_vpn==pending_vpn);
    end

    if(delivery0_observed) assert(send0_accept && !send0_lost);
    if(delivery1_observed) assert(send1_accept && !send1_lost);

    if(ack0_accept) begin
      assert(shootdown_pending && required_harts[0] && delivered_bitmap[0] && !ack_bitmap[0]);
      assert(ack0_generation==pending_generation && ack0_asid==pending_asid && ack0_epoch==pending_epoch && ack0_vpn==pending_vpn);
    end
    if(ack1_accept) begin
      assert(shootdown_pending && required_harts[1] && delivered_bitmap[1] && !ack_bitmap[1]);
      assert(ack1_generation==pending_generation && ack1_asid==pending_asid && ack1_epoch==pending_epoch && ack1_vpn==pending_vpn);
    end

    if(quorum_complete) begin
      assert(shootdown_pending);
      assert(required_harts != 2'b00);
      assert((((ack_bitmap | {ack1_accept,ack0_accept}) & required_harts) == required_harts));
    end

    if(attempts0 == 2'd3 && shootdown_pending && required_harts[0] && !ack_bitmap[0])
      assert(!global_translation_authority_ready);
    if(attempts1 == 2'd3 && shootdown_pending && required_harts[1] && !ack_bitmap[1])
      assert(!global_translation_authority_ready);

    if($past(recovery_begin || restore_valid)) begin
      assert(!shootdown_pending);
      assert(required_harts==0 && delivered_bitmap==0 && ack_bitmap==0 && attempts0==0 && attempts1==0);
    end

    if($past(delivery0_observed) && !$past(quorum_complete) && !$past(recovery_begin) && !$past(restore_valid))
      assert(delivered_bitmap[0]);
    if($past(delivery1_observed) && !$past(quorum_complete) && !$past(recovery_begin) && !$past(restore_valid))
      assert(delivered_bitmap[1]);

    if(recovery_begin || restore_valid || shootdown_launch_valid || shootdown_pending || send0_rejected || send1_rejected || ack0_rejected || ack1_rejected || quorum_complete)
      assert(speculation_kill);
  end

  always @(posedge clk) if(past_valid && rst_n) begin
    cover(shootdown_launch_accept);
    cover(send0_accept && send0_lost);
    cover(delivery0_observed);
    cover(ack0_rejected && !delivered_bitmap[0]);
    cover(ack0_accept);
    cover(send1_accept && !send1_lost);
    cover(ack1_accept);
    cover(quorum_complete);
    cover(global_translation_authority_ready && $past(quorum_complete));
    cover(attempts0 == 2'd3 && shootdown_pending && !delivered_bitmap[0]);
  end
endmodule
