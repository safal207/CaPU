`timescale 1ns/1ps
module capu_queue_epoch_slot_reuse_v32_tb;
  localparam ID_WIDTH=4;
  localparam [1:0] U=2'b00, X=2'b01, C=2'b10, N=2'b11;

  logic clk=0,rst_n=0,recovery_begin=0;
  logic submit_valid=0; logic [3:0] submit_queue_epoch=0,submit_command_id=5,submit_execution_epoch=6,submit_effect_id=7;
  logic checkpoint_capture_valid=0;
  logic issue_valid=0; logic [3:0] issue_queue_epoch=0,issue_command_id=5,issue_execution_epoch=6,issue_effect_id=7;
  logic resolution_valid=0,resolution_committed=0; logic [3:0] resolution_queue_epoch=0,resolution_command_id=5,resolution_execution_epoch=6,resolution_effect_id=7;
  logic restore_valid=0;
  logic retire_valid=0; logic [3:0] retire_queue_epoch=0,retire_command_id=5,retire_execution_epoch=6,retire_effect_id=7;

  logic runtime_ready,submit_accept,slot_reuse_accept,epoch_wrap_blocked,slot_pending;
  logic [3:0] live_queue_epoch,live_command_id,live_execution_epoch,live_effect_id;
  logic [1:0] effect_state;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_pending;
  logic [3:0] checkpoint_queue_epoch,checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id;
  logic [1:0] checkpoint_effect_state;
  logic issue_accept,issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic replay_authority,evidence_required,issue_receipt,negative_receipt,completion_receipt;
  logic durable_slot_valid; logic [3:0] durable_queue_epoch,durable_command_id,durable_execution_epoch,durable_effect_id;
  logic last_retired_valid; logic [3:0] last_retired_queue_epoch; logic stale_evidence_quarantined,speculation_kill;

  capu_queue_epoch_slot_reuse_v32 #(.ID_WIDTH(ID_WIDTH)) dut(.*);
  always #5 clk=~clk;

  task automatic fail(input string msg); begin $display("FAIL: %s",msg); $fatal(1); end endtask

  task automatic submit_epoch(input [3:0] e,input bit expect_accept);
    begin
      @(negedge clk); submit_queue_epoch=e; submit_valid=1; #1;
      if(submit_accept!==expect_accept) fail("submit_accept mismatch");
      @(posedge clk); #1; submit_valid=0;
    end
  endtask

  task automatic issue_epoch(input [3:0] e);
    begin
      @(negedge clk); issue_queue_epoch=e; issue_valid=1; #1;
      if(!issue_accept) fail("issue rejected");
      @(posedge clk); #1; issue_valid=0;
      if(effect_state!=X || !issue_receipt) fail("issue did not create UNKNOWN witness");
    end
  endtask

  task automatic resolve_epoch(input [3:0] e,input bit committed,input bit expect_accept);
    begin
      @(negedge clk); resolution_queue_epoch=e; resolution_committed=committed; resolution_valid=1; #1;
      if(resolution_accept!==expect_accept) fail("resolution_accept mismatch");
      @(posedge clk); #1; resolution_valid=0;
    end
  endtask

  task automatic retire_epoch(input [3:0] e);
    begin
      @(negedge clk); retire_queue_epoch=e; retire_valid=1; #1;
      if(!retire_accept) fail("retire rejected");
      @(posedge clk); #1; retire_valid=0;
      if(slot_pending || durable_slot_valid || !last_retired_valid || last_retired_queue_epoch!=e)
        fail("retirement history incorrect");
    end
  endtask

  task automatic checkpoint_now;
    begin
      @(negedge clk); checkpoint_capture_valid=1; #1;
      if(!checkpoint_capture_accept) fail("checkpoint rejected");
      @(posedge clk); #1; checkpoint_capture_valid=0;
    end
  endtask

  task automatic recover_restore;
    begin
      @(negedge clk); recovery_begin=1;
      @(posedge clk); #1;
      if(runtime_ready || slot_pending) fail("recovery did not close runtime");
      @(negedge clk); recovery_begin=0; restore_valid=1; #1;
      if(!restore_accept) fail("restore rejected");
      @(posedge clk); #1; restore_valid=0;
    end
  endtask

  integer e;
  initial begin
    repeat(2) @(posedge clk); rst_n=1; @(posedge clk); #1;

    // Epoch 2 owns the slot first. Capture a deliberately stale checkpoint.
    submit_epoch(4'd2,1);
    checkpoint_now();
    $display("epoch2_checkpoint pending=%0d epoch=%0d state=UNISSUED",checkpoint_pending,checkpoint_queue_epoch);

    issue_epoch(4'd2);
    resolve_epoch(4'd2,1,1);
    if(effect_state!=C || !completion_receipt) fail("epoch2 commit missing");
    retire_epoch(4'd2);
    $display("epoch2_retired slot_reclaimable=1 retired_epoch=%0d",last_retired_queue_epoch);

    // Same-epoch reuse is forbidden; exact successor epoch reuse is accepted.
    submit_epoch(4'd2,0);
    submit_epoch(4'd3,1);
    if(!slot_reuse_accept && durable_queue_epoch!=4'd3) fail("epoch3 reuse not established");
    $display("epoch3_reuse same_numeric_ids=1 queue_epoch_discriminator=1 durable_epoch=%0d",durable_queue_epoch);

    issue_epoch(4'd3);

    // Ancient completion evidence from epoch 2 has identical command/effect IDs.
    // Only the old queue epoch differs; it must not mutate epoch 3 authority.
    resolve_epoch(4'd2,1,0);
    if(effect_state!=X || !issue_receipt || !stale_evidence_quarantined)
      fail("old epoch evidence reacquired authority");
    $display("late_epoch2_evidence quarantined=1 epoch3_state=UNKNOWN no_authority_mutation=1");

    // Restore a checkpoint captured before epoch 3 existed. Durable epoch-3 slot
    // identity and its issue witness must dominate it.
    recover_restore();
    if(!slot_pending || live_queue_epoch!=4'd3 || durable_queue_epoch!=4'd3 || effect_state!=X || !evidence_required)
      fail("stale checkpoint resurrected old epoch");
    $display("stale_epoch2_restore epoch3_slot_wins=1 current_epoch=%0d unknown_preserved=1",live_queue_epoch);

    resolve_epoch(4'd3,0,1);
    if(effect_state!=N || !negative_receipt || !replay_authority) fail("negative evidence did not reopen replay");
    issue_epoch(4'd3);
    resolve_epoch(4'd3,1,1);
    retire_epoch(4'd3);
    $display("epoch3_retired exact_successor_chain=1");

    // Drive the bounded epoch namespace to exhaustion. Every reuse must be the
    // exact successor, even though the numeric transaction identity is reused.
    for(e=4;e<=15;e=e+1) begin
      submit_epoch(e[3:0],1);
      issue_epoch(e[3:0]);
      resolve_epoch(e[3:0],1,1);
      retire_epoch(e[3:0]);
    end

    @(negedge clk); submit_queue_epoch=4'd0; submit_valid=1; #1;
    if(submit_accept || !epoch_wrap_blocked) fail("epoch wrap did not fail closed");
    $display("epoch_namespace_exhausted last_retired=15 wrap_to_0_blocked=1 fail_closed=1");
    submit_valid=0;

    $display("CAPU_VCML_QUEUE_EPOCH_SLOT_REUSE_V32_PASS");
    #10 $finish;
  end
endmodule
