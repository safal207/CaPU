module capu_cross_generation_reordering_v24_formal;
  (* gclk *) reg clk;
  (* anyseq *) logic rst_n,recovery_begin,restore_valid,shootdown_launch_valid;
  (* anyseq *) logic delivery0_valid,delivery1_valid,ack0_valid,ack1_valid;
  (* anyseq *) logic [3:0] launch_generation,delivery0_generation,delivery1_generation,ack0_generation,ack1_generation;
  (* anyseq *) logic [2:0] launch_asid,delivery0_asid,delivery1_asid,ack0_asid,ack1_asid;
  (* anyseq *) logic [3:0] launch_epoch,delivery0_epoch,delivery1_epoch,ack0_epoch,ack1_epoch;
  (* anyseq *) logic [3:0] launch_vpn,delivery0_vpn,delivery1_vpn,ack0_vpn,ack1_vpn;
  (* anyseq *) logic [1:0] launch_required_harts;

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

  reg past_valid=0;
  always @(posedge clk) past_valid <= 1'b1;
  always @(*) begin
    if(!past_valid) assume(!rst_n); else assume(rst_n);
  end

  always @(posedge clk) if(past_valid && rst_n) begin
    assert(!(shootdown_launch_accept && shootdown_launch_rejected));
    assert(!(delivery0_accept && delivery0_quarantined));
    assert(!(delivery1_accept && delivery1_quarantined));
    assert(!(ack0_accept && ack0_quarantined));
    assert(!(ack1_accept && ack1_quarantined));

    if(shootdown_launch_accept) begin
      assert(launch_required_harts != 2'b00);
      assert(!shootdown_pending);
      if(last_retired_valid) begin
        assert(last_retired_generation != 4'hf);
        assert(launch_generation == last_retired_generation + 1'b1);
      end
    end

    if(shootdown_pending) assert(!global_translation_authority_ready);

    if(delivery0_accept) begin
      assert(required_harts[0] && !ack_bitmap[0]);
      assert(delivery0_generation == pending_generation);
      assert(delivery0_asid == pending_asid && delivery0_epoch == pending_epoch && delivery0_vpn == pending_vpn);
    end
    if(delivery1_accept) begin
      assert(required_harts[1] && !ack_bitmap[1]);
      assert(delivery1_generation == pending_generation);
      assert(delivery1_asid == pending_asid && delivery1_epoch == pending_epoch && delivery1_vpn == pending_vpn);
    end

    if(delivery0_quarantined) assert(shootdown_pending && !delivery0_accept);
    if(delivery1_quarantined) assert(shootdown_pending && !delivery1_accept);

    if(ack0_accept) begin
      assert(required_harts[0] && delivered_bitmap[0] && !ack_bitmap[0]);
      assert(ack0_generation == pending_generation);
      assert(ack0_asid == pending_asid && ack0_epoch == pending_epoch && ack0_vpn == pending_vpn);
    end
    if(ack1_accept) begin
      assert(required_harts[1] && delivered_bitmap[1] && !ack_bitmap[1]);
      assert(ack1_generation == pending_generation);
      assert(ack1_asid == pending_asid && ack1_epoch == pending_epoch && ack1_vpn == pending_vpn);
    end

    if(quorum_complete)
      assert(((ack_bitmap | {ack1_accept,ack0_accept}) & required_harts) == required_harts);

    if(last_retired_valid && last_retired_generation == 4'hf)
      assert(!shootdown_launch_accept);

    if($past(delivery0_quarantined) && !$past(recovery_begin) && !$past(restore_valid) && !$past(quorum_complete))
      assert(delivered_bitmap[0] == $past(delivered_bitmap[0]));
    if($past(delivery1_quarantined) && !$past(recovery_begin) && !$past(restore_valid) && !$past(quorum_complete))
      assert(delivered_bitmap[1] == $past(delivered_bitmap[1]));
    if($past(ack0_quarantined) && !$past(recovery_begin) && !$past(restore_valid) && !$past(quorum_complete))
      assert(ack_bitmap[0] == $past(ack_bitmap[0]));
    if($past(ack1_quarantined) && !$past(recovery_begin) && !$past(restore_valid) && !$past(quorum_complete))
      assert(ack_bitmap[1] == $past(ack_bitmap[1]));

    if($past(quorum_complete)) begin
      assert(last_retired_valid);
      assert(last_retired_generation == $past(pending_generation));
      assert(!shootdown_pending);
    end

    if($past(recovery_begin || restore_valid)) begin
      assert(!shootdown_pending);
      assert(delivered_bitmap == 0 && ack_bitmap == 0);
      assert(quarantined_delivery_bitmap == 0 && quarantined_ack_bitmap == 0 && quarantine_events == 0);
    end

    if(recovery_begin || restore_valid || shootdown_launch_valid || shootdown_pending || delivery0_quarantined || delivery1_quarantined || ack0_rejected || ack1_rejected || ack0_quarantined || ack1_quarantined || quorum_complete)
      assert(speculation_kill);
  end

  always @(posedge clk) if(past_valid && rst_n) begin
    cover(shootdown_launch_accept);
    cover(quorum_complete);
    cover(last_retired_valid && shootdown_pending && pending_generation == last_retired_generation + 1'b1);
    cover(delivery0_quarantined);
    cover(ack1_quarantined);
    cover(ack0_rejected);
    cover(quarantine_events != 0 && shootdown_pending);
    cover(last_retired_valid && global_translation_authority_ready);
  end
endmodule
