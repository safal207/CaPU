`timescale 1ns/1ps
module capu_delegated_nested_trap_v19_tb;
    localparam REF_W=4, EPOCH_W=4, COMMIT_W=8, BASE_W=32, PC_W=8, PRIV_W=2, CAUSE_W=4, DEL_W=4;
    localparam CTX_W=1+1+CAUSE_W+PC_W+PRIV_W+PRIV_W;
    localparam PAYLOAD_W=BASE_W+PC_W+PRIV_W+DEL_W+2+(2*CTX_W);

    logic clk=0; always #5 clk=~clk;
    logic rst_n=0;
    logic recovery_begin=0, restore_valid=0;
    logic [REF_W-1:0] snapshot_checkpoint_ref='0;
    logic [EPOCH_W-1:0] snapshot_checkpoint_epoch='0;
    logic [COMMIT_W-1:0] snapshot_checkpoint_commitment='0;
    logic [PAYLOAD_W-1:0] snapshot_checkpoint_payload='0;
    logic snapshot_commitment_verified=0;
    logic [BASE_W-1:0] restore_base_payload='0;
    logic [PC_W-1:0] restore_pc='0;
    logic [PRIV_W-1:0] restore_privilege='0;
    logic [DEL_W-1:0] restore_delegation_mask='0;
    logic [1:0] restore_trap_depth='0;
    logic restore_ctx0_valid=0,restore_ctx0_is_interrupt=0;
    logic [CAUSE_W-1:0] restore_ctx0_cause='0;
    logic [PC_W-1:0] restore_ctx0_return_pc='0;
    logic [PRIV_W-1:0] restore_ctx0_return_privilege='0,restore_ctx0_target_privilege='0;
    logic restore_ctx1_valid=0,restore_ctx1_is_interrupt=0;
    logic [CAUSE_W-1:0] restore_ctx1_cause='0;
    logic [PC_W-1:0] restore_ctx1_return_pc='0;
    logic [PRIV_W-1:0] restore_ctx1_return_privilege='0,restore_ctx1_target_privilege='0;
    logic current_anchor_valid=0;
    logic [REF_W-1:0] current_anchor_ref='0;
    logic [EPOCH_W-1:0] current_anchor_epoch='0;
    logic [COMMIT_W-1:0] current_anchor_commitment='0;
    logic [PAYLOAD_W-1:0] current_anchor_payload='0;
    logic checkpoint_prepare_valid=0;
    logic [REF_W-1:0] candidate_checkpoint_ref='0;
    logic [EPOCH_W-1:0] candidate_checkpoint_epoch='0;
    logic [COMMIT_W-1:0] candidate_checkpoint_commitment='0;
    logic [PAYLOAD_W-1:0] candidate_checkpoint_payload='0,committed_checkpoint_payload='0;
    logic candidate_commitment_verified=0,checkpoint_abort=0;
    logic snapshot_persisted_valid=0;
    logic [REF_W-1:0] persisted_checkpoint_ref='0;
    logic [EPOCH_W-1:0] persisted_checkpoint_epoch='0;
    logic [COMMIT_W-1:0] persisted_checkpoint_commitment='0;
    logic [PAYLOAD_W-1:0] persisted_checkpoint_payload='0;
    logic anchor_commit_ack_valid=0;
    logic [REF_W-1:0] ack_checkpoint_ref='0;
    logic [EPOCH_W-1:0] ack_checkpoint_epoch='0;
    logic [COMMIT_W-1:0] ack_checkpoint_commitment='0;
    logic [PAYLOAD_W-1:0] ack_checkpoint_payload='0;
    logic trap_enter_valid=0,trap_is_interrupt=0;
    logic [CAUSE_W-1:0] trap_cause='0;
    logic [PC_W-1:0] trap_vector_pc='0;
    logic [PRIV_W-1:0] trap_target_privilege='0;
    logic trap_return_valid=0;
    logic normal_step_valid=0;
    logic [PC_W-1:0] normal_next_pc='0;
    logic [PRIV_W-1:0] normal_step_privilege='0;
    logic effect_issue_valid=0,effect_commit_valid=0;

    wire checkpoint_prepare_accept,checkpoint_prepare_rejected,checkpoint_snapshot_persist_accept;
    wire checkpoint_snapshot_persist_rejected,checkpoint_anchor_commit_request,checkpoint_commit_event;
    wire checkpoint_candidate_pending,checkpoint_snapshot_durable,checkpoint_restore_accept;
    wire checkpoint_restore_rejected,checkpoint_restore_mismatch,live_execution_ready;
    wire [PC_W-1:0] live_pc; wire [PRIV_W-1:0] live_privilege; wire [DEL_W-1:0] live_delegation_mask;
    wire [1:0] live_trap_depth; wire live_ctx0_valid,live_ctx0_is_interrupt;
    wire [CAUSE_W-1:0] live_ctx0_cause; wire [PC_W-1:0] live_ctx0_return_pc;
    wire [PRIV_W-1:0] live_ctx0_return_privilege,live_ctx0_target_privilege;
    wire live_ctx1_valid,live_ctx1_is_interrupt; wire [CAUSE_W-1:0] live_ctx1_cause;
    wire [PC_W-1:0] live_ctx1_return_pc; wire [PRIV_W-1:0] live_ctx1_return_privilege,live_ctx1_target_privilege;
    wire trap_enter_accept,delegation_rejected,trap_depth_overflow_rejected,trap_return_accept;
    wire trap_return_underflow_rejected,normal_step_accept,privilege_mismatch_rejected;
    wire speculative_effect_pending,visible_effect,speculation_kill; wire [PAYLOAD_W-1:0] checkpoint_request_payload;

    capu_delegated_nested_trap_v19 #(.CHECKPOINT_REF_WIDTH(REF_W),.CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
      .CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W),.BASE_PAYLOAD_WIDTH(BASE_W),.PC_WIDTH(PC_W),
      .PRIV_WIDTH(PRIV_W),.CAUSE_WIDTH(CAUSE_W),.DELEGATION_WIDTH(DEL_W),.CTX_WIDTH(CTX_W),.PAYLOAD_WIDTH(PAYLOAD_W)) dut(.*);

    function automatic [PAYLOAD_W-1:0] pack_restore;
      pack_restore={restore_base_payload,restore_pc,restore_privilege,restore_delegation_mask,restore_trap_depth,
        restore_ctx0_valid,restore_ctx0_is_interrupt,restore_ctx0_cause,restore_ctx0_return_pc,
        restore_ctx0_return_privilege,restore_ctx0_target_privilege,
        restore_ctx1_valid,restore_ctx1_is_interrupt,restore_ctx1_cause,restore_ctx1_return_pc,
        restore_ctx1_return_privilege,restore_ctx1_target_privilege};
    endfunction
    task tick; begin @(posedge clk); #1; end endtask
    task clear_pulses; begin
      restore_valid=0; checkpoint_prepare_valid=0; snapshot_persisted_valid=0; anchor_commit_ack_valid=0;
      trap_enter_valid=0; trap_return_valid=0; normal_step_valid=0; effect_issue_valid=0; effect_commit_valid=0; recovery_begin=0;
    end endtask

    initial begin
      repeat(2) tick(); rst_n=1; tick();

      restore_base_payload=32'hA1B2C3D4; restore_pc=8'h40; restore_privilege=1; restore_delegation_mask=4'b1100;
      restore_trap_depth=0; restore_ctx0_valid=0; restore_ctx1_valid=0;
      current_anchor_valid=1; current_anchor_ref=1; current_anchor_epoch=1; current_anchor_commitment=8'hA5;
      snapshot_checkpoint_ref=1; snapshot_checkpoint_epoch=1; snapshot_checkpoint_commitment=8'hA5;
      snapshot_checkpoint_payload=pack_restore(); current_anchor_payload=pack_restore(); snapshot_commitment_verified=1;
      restore_valid=1; #1;
      if(!checkpoint_restore_accept) $fatal(1,"exact restore rejected");
      tick(); clear_pulses(); #1;
      if(!live_execution_ready || live_pc!=8'h40 || live_privilege!=1 || live_trap_depth!=0) $fatal(1,"bad restore");

      trap_enter_valid=1; trap_target_privilege=1; trap_vector_pc=8'h60; trap_cause=1; #1;
      if(!delegation_rejected || trap_enter_accept) $fatal(1,"unauthorized delegation accepted");
      $display("unauthorized_delegation rejected=1"); tick(); clear_pulses();

      trap_enter_valid=1; trap_target_privilege=2; trap_vector_pc=8'h80; trap_cause=3; trap_is_interrupt=0; #1;
      if(!trap_enter_accept) $fatal(1,"outer trap rejected");
      tick(); clear_pulses(); #1;
      if(live_trap_depth!=1 || live_pc!=8'h80 || live_privilege!=2 || !live_ctx0_valid || live_ctx0_return_pc!=8'h40 || live_ctx0_return_privilege!=1) $fatal(1,"outer context wrong");
      $display("outer_trap exact_parent=1 depth=1");

      effect_issue_valid=1; #1; tick(); clear_pulses(); #1;
      if(!speculative_effect_pending) $fatal(1,"effect did not pend");
      trap_enter_valid=1; trap_target_privilege=3; trap_vector_pc=8'hA0; trap_cause=5; trap_is_interrupt=1; effect_commit_valid=1; #1;
      if(!trap_enter_accept || visible_effect) $fatal(1,"nested trap boundary leaked effect");
      tick(); clear_pulses(); #1;
      if(live_trap_depth!=2 || live_pc!=8'hA0 || live_privilege!=3 || !live_ctx1_valid || live_ctx1_return_pc!=8'h80 || live_ctx1_return_privilege!=2 || speculative_effect_pending) $fatal(1,"nested context wrong");
      $display("nested_trap exact_parent=1 depth=2 speculation_killed=1");

      trap_enter_valid=1; trap_target_privilege=3; trap_vector_pc=8'hC0; #1;
      if(!trap_depth_overflow_rejected || trap_enter_accept) $fatal(1,"third trap accepted");
      $display("depth_overflow rejected=1"); tick(); clear_pulses();

      trap_return_valid=1; #1; if(!trap_return_accept) $fatal(1,"inner return reject");
      tick(); clear_pulses(); #1;
      if(live_trap_depth!=1 || live_pc!=8'h80 || live_privilege!=2 || live_ctx1_valid) $fatal(1,"inner return wrong");
      $display("nested_return exact_parent=1 depth=1");

      trap_return_valid=1; #1; if(!trap_return_accept) $fatal(1,"outer return reject");
      tick(); clear_pulses(); #1;
      if(live_trap_depth!=0 || live_pc!=8'h40 || live_privilege!=1 || live_ctx0_valid) $fatal(1,"outer return wrong");
      $display("outer_return exact_base=1 depth=0");

      trap_return_valid=1; #1; if(!trap_return_underflow_rejected) $fatal(1,"underflow not rejected");
      $display("return_underflow rejected=1"); tick(); clear_pulses();

      normal_step_valid=1; normal_step_privilege=2; normal_next_pc=8'h41; #1;
      if(!privilege_mismatch_rejected || normal_step_accept) $fatal(1,"wrong privilege step accepted");
      $display("privilege_mismatch rejected=1"); tick(); clear_pulses();

      committed_checkpoint_payload=current_anchor_payload;
      candidate_checkpoint_ref=2; candidate_checkpoint_epoch=2; candidate_checkpoint_commitment=8'hB6;
      candidate_checkpoint_payload=current_anchor_payload ^ {{(PAYLOAD_W-4){1'b0}},4'b0100}; candidate_commitment_verified=1;
      checkpoint_prepare_valid=1; #1;
      if(!checkpoint_prepare_rejected || checkpoint_prepare_accept) $fatal(1,"delegation mutation prepare accepted");
      $display("prepare_delegation_mutation rejected=1"); tick(); clear_pulses();

      candidate_checkpoint_payload=committed_checkpoint_payload; checkpoint_prepare_valid=1; #1;
      if(!checkpoint_prepare_accept) $fatal(1,"exact prepare rejected"); tick(); clear_pulses(); #1;
      persisted_checkpoint_ref=2; persisted_checkpoint_epoch=2; persisted_checkpoint_commitment=8'hB6;
      persisted_checkpoint_payload=committed_checkpoint_payload; snapshot_persisted_valid=1; #1;
      if(!checkpoint_snapshot_persist_accept) $fatal(1,"persist rejected"); tick(); clear_pulses(); #1;
      if(!checkpoint_anchor_commit_request) $fatal(1,"no anchor request");
      ack_checkpoint_ref=2; ack_checkpoint_epoch=2; ack_checkpoint_commitment=8'hB6; ack_checkpoint_payload=committed_checkpoint_payload;
      anchor_commit_ack_valid=1; #1; if(!checkpoint_commit_event) $fatal(1,"commit reject");
      $display("checkpoint_authority exact=1"); tick(); clear_pulses();

      recovery_begin=1; #1; if(visible_effect) $fatal(1,"recovery effect leak"); tick(); clear_pulses(); #1;
      if(live_execution_ready) $fatal(1,"recovery did not close runtime");
      $display("recovery_priority runtime_closed=1");
      $display("CAPU_VCML_DELEGATED_NESTED_TRAP_V19_PASS");
      $finish;
    end
endmodule
