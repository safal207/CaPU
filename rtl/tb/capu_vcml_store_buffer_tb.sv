`timescale 1ns/1ps

module capu_vcml_store_buffer_tb;
    logic clk = 1'b0, rst_n = 1'b0;
    logic issue_valid, gate_allow, execute_ok;
    logic [15:0] store_addr;
    logic [31:0] store_data;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [63:0] store_transition_id, store_parent_ref;
    logic explicit_new_cause, root_authorized, causal_valid, commit_request, flush;
    logic [15:0] root_authorization_ref;
    logic [7:0] root_policy_epoch;

    logic buffer_valid, memory_write_enable, vcml_event_valid;
    logic [15:0] buffered_addr, buffered_ctag, memory_write_addr, retired_ctag;
    logic [31:0] buffered_data, memory_write_data;
    logic buffered_ctag_valid, buffered_root_authorized, retired_root_authorized;
    logic [15:0] buffered_root_authorization_ref, retired_root_authorization_ref;
    logic [7:0] buffered_root_policy_epoch, retired_root_policy_epoch;
    logic [63:0] buffered_transition_id, buffered_parent_ref;
    logic [63:0] retired_transition_id, retired_parent_ref;
    logic ctag_semantic_accept, sealed_chain, continuation_blocked;
    logic causal_head_valid, generation_policy_accept, generation_exhausted;
    logic root_authorization_accept, parent_policy_accept, issue_rejected;
    logic [63:0] causal_head_transition_id;
    logic [3:0] causal_head_gen;

    integer i;
    logic [63:0] last_tid;
    logic prior_retired_auth;
    logic [15:0] prior_retired_auth_ref;
    logic [7:0] prior_retired_policy_epoch;

    capu_vcml_store_buffer dut (
        .clk(clk), .rst_n(rst_n),
        .issue_valid(issue_valid), .gate_allow(gate_allow), .execute_ok(execute_ok),
        .store_addr(store_addr), .store_data(store_data),
        .store_ctag(store_ctag), .store_ctag_valid(store_ctag_valid),
        .store_transition_id(store_transition_id), .store_parent_ref(store_parent_ref),
        .explicit_new_cause(explicit_new_cause), .root_authorized(root_authorized),
        .root_authorization_ref(root_authorization_ref), .root_policy_epoch(root_policy_epoch),
        .causal_valid(causal_valid), .commit_request(commit_request), .flush(flush),
        .buffer_valid(buffer_valid), .buffered_addr(buffered_addr), .buffered_data(buffered_data),
        .buffered_ctag(buffered_ctag), .buffered_ctag_valid(buffered_ctag_valid),
        .buffered_transition_id(buffered_transition_id), .buffered_parent_ref(buffered_parent_ref),
        .buffered_root_authorized(buffered_root_authorized),
        .buffered_root_authorization_ref(buffered_root_authorization_ref),
        .buffered_root_policy_epoch(buffered_root_policy_epoch),
        .memory_write_enable(memory_write_enable), .memory_write_addr(memory_write_addr),
        .memory_write_data(memory_write_data), .vcml_event_valid(vcml_event_valid),
        .retired_ctag(retired_ctag), .retired_transition_id(retired_transition_id),
        .retired_parent_ref(retired_parent_ref), .retired_root_authorized(retired_root_authorized),
        .retired_root_authorization_ref(retired_root_authorization_ref),
        .retired_root_policy_epoch(retired_root_policy_epoch),
        .ctag_semantic_accept(ctag_semantic_accept),
        .sealed_chain(sealed_chain), .continuation_blocked(continuation_blocked),
        .causal_head_valid(causal_head_valid), .causal_head_transition_id(causal_head_transition_id),
        .causal_head_gen(causal_head_gen), .generation_policy_accept(generation_policy_accept),
        .generation_exhausted(generation_exhausted),
        .root_authorization_accept(root_authorization_accept),
        .parent_policy_accept(parent_policy_accept), .issue_rejected(issue_rejected)
    );

    always #5 clk = ~clk;

    function automatic [15:0] make_ctag(input [3:0] gen, input bit seal);
        begin
            make_ctag = {4'h4, 4'h2, gen, 3'b000, seal};
        end
    endfunction

    task automatic step; begin @(posedge clk); #1; end endtask

    task automatic clear_inputs; begin
        issue_valid=0; gate_allow=0; execute_ok=0; store_addr='0; store_data='0;
        store_ctag='0; store_ctag_valid=0; store_transition_id='0; store_parent_ref='0;
        explicit_new_cause=0; root_authorized=0; root_authorization_ref='0; root_policy_epoch='0;
        causal_valid=0; commit_request=0; flush=0;
    end endtask

    task automatic issue_store(
        input [15:0] tag,
        input [63:0] tid,
        input [63:0] parent,
        input bit root,
        input bit authorized,
        input [15:0] auth_ref,
        input [7:0] policy_epoch
    ); begin
        clear_inputs(); issue_valid=1; gate_allow=1; execute_ok=1;
        store_addr=tid[15:0]; store_data=32'hCA00_0000|tid[15:0]; store_ctag=tag; store_ctag_valid=1;
        store_transition_id=tid; store_parent_ref=parent;
        explicit_new_cause=root; root_authorized=authorized;
        root_authorization_ref=auth_ref; root_policy_epoch=policy_epoch; step();
    end endtask

    task automatic commit_store; begin
        clear_inputs(); causal_valid=1; commit_request=1; step();
    end endtask

    initial begin
        clear_inputs(); repeat(2) @(posedge clk); rst_n=1; step();
        if (causal_head_valid || sealed_chain || buffer_valid || causal_head_gen != 4'h0
            || retired_root_authorized || retired_root_authorization_ref != 16'h0
            || retired_root_policy_epoch != 8'h0)
            $fatal(1,"reset state invalid");
        $display("TRACE CAPU-V08 S0 reset head_valid=0 gen=0 sealed=0");

        issue_store(make_ctag(4'h1,0),64'h01,64'h00,0,0,16'h0000,8'h00);
        if (!issue_rejected || buffer_valid) $fatal(1,"headless continuation admitted");
        $display("TRACE CAPU-V08 S1 headless_child rejected=1");

        issue_store(16'hF200,64'h02,64'h00,1,1,16'hA002,8'h01);
        if (!issue_rejected || buffer_valid) $fatal(1,"invalid CTAG root admitted");
        $display("TRACE CAPU-V08 S2 invalid_ctag rejected=1");

        issue_store(make_ctag(4'h0,0),64'h03,64'h99,1,1,16'hA003,8'h01);
        if (!issue_rejected || buffer_valid) $fatal(1,"nonzero-parent root admitted");
        $display("TRACE CAPU-V08 S3 malformed_root_parent rejected=1");

        issue_store(make_ctag(4'h1,0),64'h04,64'h00,1,1,16'hA004,8'h01);
        if (!issue_rejected || buffer_valid) $fatal(1,"nonzero-generation root admitted");
        $display("TRACE CAPU-V08 S4 malformed_root_gen rejected=1");

        // Trust decision without authorization is rejected.
        issue_store(make_ctag(4'h0,0),64'h05,64'h00,1,0,16'hA005,8'h02);
        if (!issue_rejected || buffer_valid || root_authorization_accept)
            $fatal(1,"unauthorized initial root admitted");
        $display("TRACE CAPU-V08 S5 unauthorized_root rejected=1");

        // v0.8: trusted YES without a provenance reference also fails closed.
        issue_store(make_ctag(4'h0,0),64'h06,64'h00,1,1,16'h0000,8'h02);
        if (!issue_rejected || buffer_valid || root_authorization_accept)
            $fatal(1,"zero-ref authorized root admitted");
        $display("TRACE CAPU-V08 S6 zero_auth_ref rejected=1");

        // Authorized root binds the non-zero auth ref and policy epoch through retirement.
        issue_store(make_ctag(4'h0,0),64'h10,64'h00,1,1,16'hA110,8'h07);
        if (!buffer_valid || !parent_policy_accept || !generation_policy_accept
            || !root_authorization_accept || !buffered_root_authorized
            || buffered_root_authorization_ref!==16'hA110 || buffered_root_policy_epoch!==8'h07)
            $fatal(1,"authorized explicit root admission/provenance failed");
        commit_store();
        if (!memory_write_enable || !vcml_event_valid || !causal_head_valid
            || causal_head_transition_id!==64'h10 || causal_head_gen!==4'h0 || sealed_chain
            || !retired_root_authorized || retired_root_authorization_ref!==16'hA110
            || retired_root_policy_epoch!==8'h07)
            $fatal(1,"authorized root commit did not preserve provenance");
        $display("TRACE CAPU-V08 S7 authorized_root_committed head=10 auth_ref=A110 policy_epoch=07");

        clear_inputs(); step();

        // Root sideband/provenance is root-only: spurious values on a continuation are ignored.
        issue_store(make_ctag(4'h1,0),64'h11,64'h10,0,1,16'hFFFF,8'hFE);
        if (!buffer_valid || !parent_policy_accept || !generation_policy_accept
            || buffered_root_authorized || buffered_root_authorization_ref!==16'h0
            || buffered_root_policy_epoch!==8'h0)
            $fatal(1,"continuation inherited root provenance");
        $display("TRACE CAPU-V08 S8 continuation_spurious_auth ignored=1 gen=1");
        clear_inputs(); flush=1; step();
        if (causal_head_transition_id!==64'h10 || causal_head_gen!==4'h0 || !causal_head_valid)
            $fatal(1,"flush mutated committed head/gen");

        issue_store(make_ctag(4'h0,0),64'h12,64'h10,0,0,16'h0,8'h0);
        if (!issue_rejected || buffer_valid) $fatal(1,"stale generation admitted");
        $display("TRACE CAPU-V08 S9 stale_gen rejected=1 head_gen=0");

        issue_store(make_ctag(4'h2,0),64'h13,64'h10,0,0,16'h0,8'h0);
        if (!issue_rejected || buffer_valid) $fatal(1,"skipped generation admitted");
        $display("TRACE CAPU-V08 S10 skipped_gen rejected=1 expected=1");

        issue_store(make_ctag(4'h1,0),64'h14,64'h09,0,0,16'h0,8'h0);
        if (!issue_rejected || buffer_valid) $fatal(1,"wrong parent admitted");
        $display("TRACE CAPU-V08 S11 wrong_parent rejected=1 head=10");

        issue_store(make_ctag(4'h1,0),64'h20,64'h10,0,0,16'h0,8'h0);
        if (!buffer_valid) $fatal(1,"gen1 child not admitted");
        commit_store();
        if (!memory_write_enable || causal_head_transition_id!==64'h20 || causal_head_gen!==4'h1
            || retired_root_authorized || retired_root_authorization_ref!==16'h0
            || retired_root_policy_epoch!==8'h0)
            $fatal(1,"continuation retirement carried root provenance");

        clear_inputs(); step();
        issue_store(make_ctag(4'h2,1),64'h21,64'h20,0,0,16'h0,8'h0);
        if (!buffer_valid) $fatal(1,"sealed gen2 child not admitted");
        commit_store();
        if (!memory_write_enable || !sealed_chain || causal_head_transition_id!==64'h21
            || causal_head_gen!==4'h2 || retired_root_authorized
            || retired_root_authorization_ref!==16'h0 || retired_root_policy_epoch!==8'h0)
            $fatal(1,"sealed continuation retirement mismatch");
        $display("TRACE CAPU-V08 S12 sealed_commit head=21 gen=2 sealed=1");

        clear_inputs(); step();

        issue_store(make_ctag(4'h3,0),64'h22,64'h21,0,0,16'h0,8'h0);
        if (!issue_rejected || buffer_valid || !continuation_blocked)
            $fatal(1,"sealed exact-parent next-gen child escaped");
        $display("TRACE CAPU-V08 S13 sealed_correct_parent_gen rejected=1");

        issue_store(make_ctag(4'h0,0),64'h2F,64'h00,1,0,16'hA12F,8'h08);
        if (!issue_rejected || buffer_valid)
            $fatal(1,"unauthorized replacement root under seal admitted");
        $display("TRACE CAPU-V08 S14 unauthorized_root_under_seal rejected=1");

        issue_store(make_ctag(4'h0,0),64'h2E,64'h00,1,1,16'h0000,8'h08);
        if (!issue_rejected || buffer_valid)
            $fatal(1,"unreferenced replacement root under seal admitted");
        $display("TRACE CAPU-V08 S15 zero_ref_root_under_seal rejected=1");

        prior_retired_auth = retired_root_authorized;
        prior_retired_auth_ref = retired_root_authorization_ref;
        prior_retired_policy_epoch = retired_root_policy_epoch;
        issue_store(make_ctag(4'h0,0),64'h30,64'h00,1,1,16'hA130,8'h09);
        if (!buffer_valid || !sealed_chain || !buffered_root_authorized
            || buffered_root_authorization_ref!==16'hA130 || buffered_root_policy_epoch!==8'h09)
            $fatal(1,"authorized root under seal not admitted");
        clear_inputs(); flush=1; step();
        if (!sealed_chain || causal_head_transition_id!==64'h21 || causal_head_gen!==4'h2
            || vcml_event_valid || retired_root_authorized!==prior_retired_auth
            || retired_root_authorization_ref!==prior_retired_auth_ref
            || retired_root_policy_epoch!==prior_retired_policy_epoch)
            $fatal(1,"flushed authorized root changed committed/evidence state");
        $display("TRACE CAPU-V08 S16 authorized_root_flush no_event=1 provenance_preserved=1");

        issue_store(make_ctag(4'h0,0),64'h31,64'h00,1,1,16'hA131,8'h0A);
        if (!buffer_valid || !buffered_root_authorized
            || buffered_root_authorization_ref!==16'hA131 || buffered_root_policy_epoch!==8'h0A)
            $fatal(1,"replacement root not admitted");
        commit_store();
        if (!memory_write_enable || !vcml_event_valid || sealed_chain
            || causal_head_transition_id!==64'h31 || causal_head_gen!==4'h0
            || !retired_root_authorized || retired_root_authorization_ref!==16'hA131
            || retired_root_policy_epoch!==8'h0A)
            $fatal(1,"authorized replacement root did not preserve fresh provenance");
        if (retired_transition_id!==64'h31 || retired_parent_ref!==64'h00 || retired_ctag[7:4]!==4'h0)
            $fatal(1,"replacement root retirement metadata mismatch");
        $display("TRACE CAPU-V08 S17 replacement_root head=31 auth_ref=A131 policy_epoch=0A");

        clear_inputs(); step();

        last_tid = 64'h31;
        for (i = 1; i <= 15; i = i + 1) begin
            issue_store(make_ctag(i[3:0],0),64'h40 + i,last_tid,0,0,16'h0,8'h0);
            if (!buffer_valid || !generation_policy_accept || buffered_root_authorized
                || buffered_root_authorization_ref!==16'h0 || buffered_root_policy_epoch!==8'h0)
                $fatal(1,"monotonic continuation not admitted cleanly");
            commit_store();
            if (!memory_write_enable || causal_head_transition_id!==(64'h40 + i)
                || causal_head_gen!==i[3:0] || retired_root_authorized
                || retired_root_authorization_ref!==16'h0 || retired_root_policy_epoch!==8'h0)
                $fatal(1,"committed continuation generation/provenance mismatch");
            last_tid = 64'h40 + i;
            clear_inputs(); step();
        end

        if (!generation_exhausted || causal_head_gen!==4'hF)
            $fatal(1,"GEN=F did not mark generation exhaustion");
        $display("TRACE CAPU-V08 S18 epoch_exhausted head_gen=F");

        issue_store(make_ctag(4'h0,0),64'h60,last_tid,0,0,16'h0,8'h0);
        if (!issue_rejected || buffer_valid || !continuation_blocked)
            $fatal(1,"generation wrap admitted");
        $display("TRACE CAPU-V08 S19 wrap_rejected head_gen=F");

        issue_store(make_ctag(4'h0,0),64'h61,64'h00,1,0,16'hA161,8'h0B);
        if (!issue_rejected || buffer_valid)
            $fatal(1,"unauthorized root escaped exhausted epoch");
        $display("TRACE CAPU-V08 S20 exhausted_unauthorized_root rejected=1");

        issue_store(make_ctag(4'h0,0),64'h61,64'h00,1,1,16'h0000,8'h0B);
        if (!issue_rejected || buffer_valid)
            $fatal(1,"zero-ref root escaped exhausted epoch");
        $display("TRACE CAPU-V08 S21 exhausted_zero_ref_root rejected=1");

        issue_store(make_ctag(4'h0,0),64'h62,64'h00,1,1,16'hA162,8'h0C);
        if (!buffer_valid || !buffered_root_authorized
            || buffered_root_authorization_ref!==16'hA162 || buffered_root_policy_epoch!==8'h0C)
            $fatal(1,"authorized root after exhaustion not admitted");
        commit_store();
        if (!memory_write_enable || !vcml_event_valid || generation_exhausted
            || causal_head_transition_id!==64'h62 || causal_head_gen!==4'h0
            || !retired_root_authorized || retired_root_authorization_ref!==16'hA162
            || retired_root_policy_epoch!==8'h0C)
            $fatal(1,"authorized root did not reset exhausted epoch with provenance");
        $display("TRACE CAPU-V08 S22 exhausted_root_committed head=62 auth_ref=A162 policy_epoch=0C");

        $display("CAPU_VCML_BRIDGE_V08_RTL_PASS");
        $finish;
    end
endmodule
