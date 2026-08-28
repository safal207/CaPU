module capu_generation_wrap_aba_v25_formal;
  logic clk;
  (* anyseq *) logic rst_n,recovery_begin,restore_valid;
  (* anyseq *) logic launch_valid; (* anyseq *) logic [2:0] launch_incarnation; (* anyseq *) logic [1:0] launch_generation; (* anyseq *) logic [2:0] launch_asid; (* anyseq *) logic [3:0] launch_epoch,launch_vpn; (* anyseq *) logic [1:0] launch_required_harts;
  (* anyseq *) logic delivery_valid,delivery_hart; (* anyseq *) logic [2:0] delivery_incarnation; (* anyseq *) logic [1:0] delivery_generation; (* anyseq *) logic [2:0] delivery_asid; (* anyseq *) logic [3:0] delivery_epoch,delivery_vpn;
  (* anyseq *) logic ack_valid,ack_hart; (* anyseq *) logic [2:0] ack_incarnation; (* anyseq *) logic [1:0] ack_generation; (* anyseq *) logic [2:0] ack_asid; (* anyseq *) logic [3:0] ack_epoch,ack_vpn;
  logic launch_accept,launch_rejected,pending,retired_valid; logic [2:0] retired_incarnation,pending_incarnation; logic [1:0] retired_generation,pending_generation; logic [2:0] pending_asid; logic [3:0] pending_epoch,pending_vpn; logic [1:0] required_harts,delivered_bitmap,ack_bitmap,quarantined_delivery_bitmap,quarantined_ack_bitmap; logic delivery_accept,delivery_quarantined,ack_accept,ack_quarantined,quorum_complete,global_translation_authority_ready,speculation_kill;
  capu_generation_wrap_aba_v25 dut(.*);

  logic past_valid=0;
  always @(posedge clk) begin
    past_valid <= 1;
    if(!past_valid) assume(!rst_n);
    else assume(rst_n);

    if(rst_n) begin
      assert(!(launch_accept && launch_rejected));
      assert(!(delivery_accept && delivery_quarantined));
      assert(!(ack_accept && ack_quarantined));
      if(pending) assert(!global_translation_authority_ready);
      if(delivery_accept) begin
        assert(delivery_incarnation==pending_incarnation);
        assert(delivery_generation==pending_generation);
        assert(delivery_asid==pending_asid && delivery_epoch==pending_epoch && delivery_vpn==pending_vpn);
      end
      if(ack_accept) begin
        assert(ack_incarnation==pending_incarnation);
        assert(ack_generation==pending_generation);
        assert(delivered_bitmap[ack_hart]);
        assert(!ack_bitmap[ack_hart]);
      end
      if(launch_accept && retired_valid && &retired_generation) begin
        assert(launch_generation==0);
        assert(launch_incarnation==retired_incarnation+1'b1);
      end
      if(launch_accept && retired_valid && !(&retired_generation)) begin
        assert(launch_generation==retired_generation+1'b1);
        assert(launch_incarnation==retired_incarnation);
      end
      if(delivery_valid && pending && delivery_generation==pending_generation && delivery_incarnation!=pending_incarnation)
        assert(!delivery_accept);
      if(ack_valid && pending && ack_generation==pending_generation && ack_incarnation!=pending_incarnation)
        assert(!ack_accept);
    end

    if(past_valid && $past(rst_n) && $past(recovery_begin || restore_valid)) begin
      assert(!pending);
      assert(delivered_bitmap==0 && ack_bitmap==0);
      assert(quarantined_delivery_bitmap==0 && quarantined_ack_bitmap==0);
    end

    cover(rst_n && launch_accept && retired_valid && (&retired_generation));
    cover(rst_n && delivery_quarantined && delivery_generation==pending_generation && delivery_incarnation!=pending_incarnation);
    cover(rst_n && ack_quarantined && ack_generation==pending_generation && ack_incarnation!=pending_incarnation);
    cover(rst_n && delivery_accept);
    cover(rst_n && ack_accept);
    cover(rst_n && quorum_complete);
    cover(rst_n && launch_rejected && retired_valid);
    cover(rst_n && recovery_begin && pending);
  end
endmodule
