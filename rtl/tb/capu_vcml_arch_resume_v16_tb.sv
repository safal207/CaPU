`timescale 1ns/1ps

module capu_vcml_arch_resume_v16_tb;
    localparam int ADDR_W=8, DATA_W=16, TID_W=16, AUTH_W=16, POLICY_W=8, SLOTS=2, EPOCH_W=8;
    logic clk=0, rst_n=0;
    logic recovery_begin, restore_valid;
    logic [EPOCH_W-1:0] restore_arch_epoch, restore_causal_epoch;
    logic [ADDR_W-1:0] restore_pc;
    logic [DATA_W-1:0] restore_gpr0, restore_gpr1, restore_gpr2, restore_gpr3;
    logic [7:0] restore_status;
    logic [SLOTS-1:0] restore_spent_valid;
    logic [(SLOTS*AUTH_W)-1:0] restore_spent_refs;
    logic restore_causal_head_valid;
    logic [TID_W-1:0] restore_causal_head_transition_id;
    logic [3:0] restore_causal_head_gen;
    logic restore_sealed_chain;
    logic issue_valid;
    logic [ADDR_W-1:0] issue_pc;
    logic [1:0] store_addr_reg, store_data_reg;
    logic gate_allow, execute_ok;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [TID_W-1:0] store_transition_id, store_parent_ref;
    logic explicit_new_cause, root_authorized;
    logic [AUTH_W-1:0] root_authorization_ref;
    logic [POLICY_W-1:0] root_policy_epoch;
    logic causal_valid, commit_request, flush;
    logic memory_write_enable;
    logic [ADDR_W-1:0] memory_write_addr;
    logic [DATA_W-1:0] memory_write_data;
    logic vcml_event_valid, issue_rejected, speculative_buffer_valid;
    logic live_execution_ready;
    logic [EPOCH_W-1:0] live_restore_epoch;
    logic [ADDR_W-1:0] live_pc;
    logic [DATA_W-1:0] live_gpr0, live_gpr1, live_gpr2, live_gpr3;
    logic [7:0] live_status;
    logic live_causal_state_ready, live_causal_head_valid;
    logic [TID_W-1:0] live_causal_head_transition_id;
    logic [3:0] live_causal_head_gen;
    logic live_sealed_chain, live_generation_exhausted;
    logic split_state_restore_rejected, architectural_restore_accept;

    capu_vcml_store_buffer_v16 #(
        .ADDR_WIDTH(ADDR_W), .DATA_WIDTH(DATA_W),
        .TRANSITION_ID_WIDTH(TID_W), .PARENT_REF_WIDTH(TID_W),
        .AUTHORIZATION_REF_WIDTH(AUTH_W), .POLICY_EPOCH_WIDTH(POLICY_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS), .ARCH_EPOCH_WIDTH(EPOCH_W)
    ) dut (.*);

    always #5 clk=~clk;
    function automatic [15:0] write_ctag(input [3:0] gen);
        write_ctag={4'h1,4'h2,gen,3'b000,1'b0};
    endfunction
    task automatic tick; begin @(posedge clk); #1; end endtask
    task automatic clear_issue; begin
        issue_valid=0; causal_valid=0; commit_request=0; flush=0;
        explicit_new_cause=0; root_authorized=0; root_authorization_ref='0; root_policy_epoch='0;
    end endtask

    task automatic begin_recovery; begin
        recovery_begin=1; tick(); recovery_begin=0;
        if (live_execution_ready) $fatal(1,"execution remained ready across recovery_begin");
        if (speculative_buffer_valid) $fatal(1,"speculation survived recovery_begin");
    end endtask

    task automatic restore_snapshot(input [EPOCH_W-1:0] epoch, input [ADDR_W-1:0] pc,
                                    input [DATA_W-1:0] r0,input [DATA_W-1:0] r1,
                                    input [DATA_W-1:0] r2,input [DATA_W-1:0] r3,
                                    input [TID_W-1:0] head,input [3:0] gen);
        begin
            restore_arch_epoch=epoch; restore_causal_epoch=epoch; restore_pc=pc;
            restore_gpr0=r0; restore_gpr1=r1; restore_gpr2=r2; restore_gpr3=r3;
            restore_status=8'hA5; restore_causal_head_valid=1;
            restore_causal_head_transition_id=head; restore_causal_head_gen=gen;
            restore_sealed_chain=0; restore_spent_valid='0; restore_spent_refs='0;
            restore_valid=1; #1;
            if (!architectural_restore_accept) $fatal(1,"atomic restore not accepted");
            tick(); restore_valid=0; #1;
            if (!live_execution_ready || live_restore_epoch!=epoch || live_pc!=pc)
                $fatal(1,"live architectural state not restored");
            if (live_gpr0!=r0 || live_gpr1!=r1 || live_gpr2!=r2 || live_gpr3!=r3)
                $fatal(1,"live GPR state mismatch");
            if (live_causal_head_transition_id!=head || live_causal_head_gen!=gen)
                $fatal(1,"live causal state mismatch");
        end
    endtask

    initial begin
        recovery_begin=0; restore_valid=0; restore_arch_epoch=0; restore_causal_epoch=0;
        restore_pc=0; restore_gpr0=0; restore_gpr1=0; restore_gpr2=0; restore_gpr3=0;
        restore_status=0; restore_spent_valid=0; restore_spent_refs=0;
        restore_causal_head_valid=0; restore_causal_head_transition_id=0; restore_causal_head_gen=0; restore_sealed_chain=0;
        gate_allow=1; execute_ok=1; issue_pc=0; store_addr_reg=1; store_data_reg=2;
        store_ctag=write_ctag(0); store_ctag_valid=1; store_transition_id=0; store_parent_ref=0;
        clear_issue();
        repeat(2) tick(); rst_n=1; tick();

        begin_recovery();
        restore_arch_epoch=8'h11; restore_causal_epoch=8'h12; restore_pc=8'h40;
        restore_gpr0=16'h0000; restore_gpr1=16'h0080; restore_gpr2=16'h0055; restore_gpr3=16'h0000;
        restore_status=8'hA5; restore_causal_head_valid=1; restore_causal_head_transition_id=16'h2201;
        restore_causal_head_gen=4'h6; restore_sealed_chain=0; restore_spent_valid=0; restore_spent_refs=0;
        restore_valid=1; #1;
        if (!split_state_restore_rejected || architectural_restore_accept || memory_write_enable)
            $fatal(1,"split-state restore did not fail closed");
        tick(); restore_valid=0;
        if (speculative_buffer_valid) $fatal(1,"split-state barrier did not flush speculation");

        restore_snapshot(8'h21,8'h40,16'h0000,16'h0080,16'h0055,16'h0000,16'h2201,4'h6);

        issue_pc=8'h41; store_parent_ref=16'h2201; store_transition_id=16'h2202;
        store_ctag=write_ctag(4'h7); issue_valid=1; #1;
        if (!issue_rejected) $fatal(1,"wrong-PC continuation admitted");
        tick(); issue_valid=0;

        issue_pc=8'h40; store_addr_reg=2'd1; store_data_reg=2'd2;
        store_parent_ref=16'h2201; store_transition_id=16'h2202; store_ctag=write_ctag(4'h7);
        issue_valid=1; #1;
        if (issue_rejected) $fatal(1,"exact architectural+causal continuation rejected");
        tick(); issue_valid=0;
        causal_valid=1; commit_request=1; tick();
        if (!memory_write_enable || !vcml_event_valid) $fatal(1,"post-recovery store did not retire");
        if (memory_write_addr!==8'h80 || memory_write_data!==16'h0055)
            $fatal(1,"visible store did not use restored GPR state");
        if (live_causal_head_transition_id!==16'h2202 || live_causal_head_gen!==4'h7)
            $fatal(1,"causal head did not advance");
        causal_valid=0; commit_request=0; tick();
        if (live_pc!==8'h41) $fatal(1,"architectural PC did not advance exactly once");

        issue_pc=8'h41; store_parent_ref=16'h2202; store_transition_id=16'h2203; store_ctag=write_ctag(4'h8);
        issue_valid=1; tick(); issue_valid=0;
        if (!speculative_buffer_valid) $fatal(1,"expected speculative STORE was not buffered");
        begin_recovery();
        restore_snapshot(8'h22,8'h60,16'h0000,16'h0090,16'h0066,16'h0000,16'h3301,4'h2);
        causal_valid=1; commit_request=1; tick();
        if (memory_write_enable || vcml_event_valid)
            $fatal(1,"pre-recovery speculative STORE retired after different-state restore");
        causal_valid=0; commit_request=0;

        $display("CAPU_VCML_ARCH_RESUME_V16_PASS epoch=%h pc=%h head=%h gen=%h",
                 live_restore_epoch,live_pc,live_causal_head_transition_id,live_causal_head_gen);
        $finish;
    end
endmodule
