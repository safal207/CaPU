`timescale 1ns/1ps
module capu_queue_epoch_wrap_incarnation_v33_tb;
  localparam ID_WIDTH=2;
  localparam [1:0] U=2'b00, X=2'b01, C=2'b10, N=2'b11;

  logic clk=0,rst_n=0,recovery_begin=0;
  logic submit_valid=0; logic [1:0] submit_incarnation=0,submit_queue_epoch=0,submit_command_id=1,submit_execution_epoch=2,submit_effect_id=3;
  logic checkpoint_capture_valid=0;
  logic issue_valid=0; logic [1:0] issue_incarnation=0,issue_queue_epoch=0,issue_command_id=1,issue_execution_epoch=2,issue_effect_id=3;
  logic resolution_valid=0,resolution_committed=0; logic [1:0] resolution_incarnation=0,resolution_queue_epoch=0,resolution_command_id=1,resolution_execution_epoch=2,resolution_effect_id=3;
  logic restore_valid=0;
  logic retire_valid=0; logic [1:0] retire_incarnation=0,retire_queue_epoch=0,retire_command_id=1,retire_execution_epoch=2,retire_effect_id=3;

  logic runtime_ready,submit_accept,slot_reuse_accept,epoch_wrap_accept,incarnation_exhausted,slot_pending;
  logic [1:0] live_incarnation,live_queue_epoch,live_command_id,live_execution_epoch,live_effect_id,effect_state;
  logic checkpoint_capture_accept,checkpoint_valid,checkpoint_pending;
  logic [1:0] checkpoint_incarnation,checkpoint_queue_epoch,checkpoint_command_id,checkpoint_execution_epoch,checkpoint_effect_id,checkpoint_effect_state;
  logic issue_accept,issue_rejected,resolution_accept,resolution_rejected,restore_accept,restore_rejected,retire_accept,retire_rejected;
  logic replay_authority,evidence_required,issue_receipt,negative_receipt,completion_receipt;
  logic durable_slot_valid;
  logic [1:0] durable_incarnation,durable_queue_epoch,durable_command_id,durable_execution_epoch,durable_effect_id;
  logic last_retired_valid;
  logic [1:0] last_retired_incarnation,last_retired_queue_epoch;
  logic stale_evidence_quarantine_accept,stale_evidence_quarantined,speculation_kill;

  capu_queue_epoch_wrap_incarnation_v33 #(.ID_WIDTH(ID_WIDTH)) dut(.*);
  always #5 clk=~clk;

  task automatic fail(input string msg); begin $display("FAIL: %s",msg); $fatal(1); end endtask

  task automatic submit_identity(input [1:0] inc,input [1:0] e,input bit expect_accept,input bit expect_wrap);
    begin
      @(negedge clk); submit_incarnation=inc; submit_queue_epoch=e; submit_valid=1; #1;
      if(submit_accept!==expect_accept) fail("submit_accept mismatch");
      if(epoch_wrap_accept!==expect_wrap) fail("epoch_wrap_accept mismatch");
      @(posedge clk); #1; submit_valid=0;
    end
  endtask

  task automatic issue_identity(input [1:0] inc,input [1:0] e);
    begin
      @(negedge clk); issue_incarnation=inc; issue_queue_epoch=e; issue_valid=1; #1;
      if(!issue_accept) fail("issue rejected");
      @(posedge clk); #1; issue_valid=0;
      if(effect_state!=X || !issue_receipt) fail("issue did not create UNKNOWN witness");
    end
  endtask

  task automatic resolve_identity(input [1:0] inc,input [1:0] e,input bit committed,input bit expect_accept);
    begin
      @(negedge clk); resolution_incarnation=inc; resolution_queue_epoch=e; resolution_committed=committed; resolution_valid=1; #1;
      if(resolution_accept!==expect_accept) fail("resolution_accept mismatch");
      @(posedge clk); #1; resolution_valid=0;
    end
  endtask

  task automatic retire_identity(input [1:0] inc,input [1:0] e);
    begin
      @(negedge clk); retire_incarnation=inc; retire_queue_epoch=e; retire_valid=1; #1;
      if(!retire_accept) fail("retire rejected");
      @(posedge clk); #1; retire_valid=0;
      if(slot_pending || durable_slot_valid || !last_retired_valid ||
         last_retired_incarnation!=inc || last_retired_queue_epoch!=e)
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

  task automatic commit_and_retire(input [1:0] inc,input [1:0] e);
    begin
      submit_identity(inc,e,1, (last_retired_valid && last_retired_queue_epoch==2'b11));
      issue_identity(inc,e);
      resolve_identity(inc,e,1,1);
      if(effect_state!=C || !completion_receipt) fail("completion receipt missing");
      retire_identity(inc,e);
    end
  endtask

  integer e;
  initial begin
    repeat(2) @(posedge clk); rst_n=1; @(posedge clk); #1;

    // Establish a real historical epoch-0 transaction in incarnation 1 and
    // retain its checkpoint so that the same numeric epoch can reappear later.
    submit_identity(2'd1,2'd0,1,0);
    checkpoint_now();
    $display("inc1_epoch0_checkpoint pending=%0d incarnation=%0d epoch=%0d state=UNISSUED",checkpoint_pending,checkpoint_incarnation,checkpoint_queue_epoch);
    issue_identity(2'd1,2'd0);
    resolve_identity(2'd1,2'd0,1,1);
    retire_identity(2'd1,2'd0);

    // Advance exactly through the rest of incarnation 1.
    for(e=1;e<=3;e=e+1)
      commit_and_retire(2'd1,e[1:0]);

    // Numeric epoch wrap without an incarnation change is forbidden.
    submit_identity(2'd1,2'd0,0,0);

    // Exact wrap successor is incarnation 2, epoch 0.
    submit_identity(2'd2,2'd0,1,1);
    if(durable_incarnation!=2'd2 || durable_queue_epoch!=2'd0) fail("wrapped authority identity incorrect");
    $display("wrap_reuse current_incarnation=2 epoch=0 same_numeric_epoch_as_history=1 incarnation_discriminator=1");
    issue_identity(2'd2,2'd0);

    // Ancient completion evidence is numerically epoch 0 and has identical
    // command/execution/effect IDs. Only the incarnation differs.
    resolve_identity(2'd1,2'd0,1,0);
    if(effect_state!=X || !issue_receipt || !stale_evidence_quarantined)
      fail("ancient same-epoch evidence reacquired authority");
    $display("ancient_same_epoch_evidence quarantined=1 old_incarnation=1 current_incarnation=2 epoch=0 no_authority_mutation=1");

    // A checkpoint from incarnation 1 / epoch 0 cannot override the durable
    // incarnation 2 / epoch 0 slot after recovery.
    recover_restore();
    if(!slot_pending || live_incarnation!=2'd2 || live_queue_epoch!=2'd0 ||
       durable_incarnation!=2'd2 || durable_queue_epoch!=2'd0 ||
       effect_state!=X || !evidence_required)
      fail("stale pre-wrap checkpoint overrode current incarnation");
    $display("stale_pre_wrap_checkpoint current_incarnation=2 epoch=0 unknown_preserved=1 durable_identity_wins=1");

    resolve_identity(2'd2,2'd0,0,1);
    if(effect_state!=N || !negative_receipt || !replay_authority) fail("negative evidence did not reopen replay");
    issue_identity(2'd2,2'd0);
    resolve_identity(2'd2,2'd0,1,1);
    retire_identity(2'd2,2'd0);

    // Advance through incarnation 2 and then exercise a second exact wrap.
    for(e=1;e<=3;e=e+1)
      commit_and_retire(2'd2,e[1:0]);
    commit_and_retire(2'd3,2'd0);
    for(e=1;e<=3;e=e+1)
      commit_and_retire(2'd3,e[1:0]);

    // Incarnation itself is bounded in v0.33. We do not silently wrap it.
    @(negedge clk); submit_incarnation=2'd0; submit_queue_epoch=2'd0; submit_valid=1; #1;
    if(submit_accept || !incarnation_exhausted) fail("incarnation exhaustion did not fail closed");
    $display("incarnation_namespace_exhausted last_incarnation=3 last_epoch=3 wrap_to_incarnation0_epoch0_blocked=1 fail_closed=1");
    submit_valid=0;

    $display("CAPU_VCML_QUEUE_EPOCH_WRAP_INCARNATION_V33_PASS");
    #10 $finish;
  end
endmodule
