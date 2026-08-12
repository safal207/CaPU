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

    logic buffer_valid, memory_write_enable, vcml_event_valid;
    logic [15:0] buffered_addr, buffered_ctag, memory_write_addr, retired_ctag;
    logic [31:0] buffered_data, memory_write_data;
    logic buffered_ctag_valid, buffered_root_authorized, retired_root_authorized;
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

    capu_vcml_store_buffer dut (
        .clk(clk), .rst_n(rst_n),
        .issue_valid(issue_valid), .gate_allow(gate_allow), .execute_ok(execute_ok),
        .store_addr(store_addr), .store_data(store_data),
        .store_ctag(store_ctag), .store_ctag_valid(store_ctag_valid),
        .store_transition_id(store_transition_id), .store_parent_ref(store_parent_ref),
        .explicit_new_cause(explicit_new_cause), .root_authorized(root_authorized),
        .causal_valid(causal_valid), .commit_request(commit_request), .flush(flush),
        .buffer_valid(buffer_valid), .buffered_addr(buffered_addr), .buffered_data(buffered_data),
        .buffered_ctag(buffered_ctag), .buffered_ctag_valid(buffered_ctag_valid),
        .buffered_transition_id(buffered_transition_id), .buffered_parent_ref(buffered_parent_ref),
        .buffered_root_authorized(buffered_root_authorized),
        .memory_write_enable(memory_write_enable), .memory_write_addr(memory_write_addr),
        .memory_write_data(memory_write_data), .vcml_event_valid(vcml_event_valid),
        .retired_ctag(retired_ctag), .retired_transition_id(retired_transition_id),
        .retired_parent_ref(retired_parent_ref), .retired_root_authorized(retired_root_authorized),
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
        explicit_new_cause=0; root_authorized=0; causal_valid=0; commit_request=0; flush=0;
    end endtask

    task automatic issue_store(
        input [15:0] tag,
        input [63:0] tid,
        input [63:0] parent,
        input bit root,
        input bit authorized
    ); begin
        clear_inputs(); issue_valid=1; gate_allow=1; execute_ok=1;
        store_addr=tid[15:0]; store_data=32'hCA00_0000|tid[15:0]; store_ctag=tag; store_ctag_valid=1;
        store_transition_id=tid; store_parent_ref=parent;
        explicit_new_cause=root; root_authorized=authorized; step();
    end endtask

    task automatic commit_store; begin
        clear_inputs(); causal_valid=1; commit_request=1; step();
    end endtask

    initial begin
        clear_inputs(); repeat(2) @(posedge clk); rst_n=1; step();
        if (causal_head_valid || sealed_chain || buffer_valid || causal_head_gen != 4'h0
            || retired_root_authorized)
            $fatal(1,"reset state invalid");
        $display("TRACE CAPU-V07 S0 reset head_valid=0 gen=0 sealed=0");

        // No committed head: automatic continuation still fails closed and does
        // not need/use the root authorization sideband.
        issue_store(make_ctag(4'h1,0),64'h01,64'h00,0,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"headless continuation admitted");
        $display("TRACE CAPU-V07 S1 headless_child rejected=1");

        // Existing CTAG/root structure checks remain in force even when upstream
        // says the root is authorized.
        issue_store(16'hF200,64'h02,64'h00,1,1);
        if (!issue_rejected || buffer_valid) $fatal(1,"invalid CTAG root admitted");
        $display("TRACE CAPU-V07 S2 invalid_ctag rejected=1");

        issue_store(make_ctag(4'h0,0),64'h03,64'h99,1,1);
        if (!issue_rejected || buffer_valid) $fatal(1,"nonzero-parent root admitted");
        $display("TRACE CAPU-V07 S3 malformed_root_parent rejected=1");

        issue_store(make_ctag(4'h1,0),64'h04,64'h00,1,1);
        if (!issue_rejected || buffer_valid) $fatal(1,"nonzero-generation root admitted");
        $display("TRACE CAPU-V07 S4 malformed_root_gen rejected=1");

        // v0.7 trust boundary: structure alone is no longer sufficient.
        issue_store(make_ctag(4'h0,0),64'h05,64'h00,1,0);
        if (!issue_rejected || buffer_valid || root_authorization_accept)
            $fatal(1,"unauthorized initial root admitted");
        $display("TRACE CAPU-V07 S5 unauthorized_root rejected=1");

        // Authorized initial root establishes head identity, GEN=0 and retirement
        // evidence that is qualified by vcml_event_valid.
        issue_store(make_ctag(4'h0,0),64'h10,64'h00,1,1);
        if (!buffer_valid || !parent_policy_accept || !generation_policy_accept
            || !root_authorization_accept || !buffered_root_authorized)
            $fatal(1,"authorized explicit root admission failed");
        commit_store();
        if (!memory_write_enable || !vcml_event_valid || !causal_head_valid
            || causal_head_transition_id!==64'h10 || causal_head_gen!==4'h0 || sealed_chain
            || !retired_root_authorized)
            $fatal(1,"authorized root commit did not establish evidence/head/gen");
        $display("TRACE CAPU-V07 S6 authorized_root_committed head=10 gen=0 auth=1");

        clear_inputs(); step();

        // Normal continuation requires no root authorization. The root-auth bit
        // in the speculative metadata remains zero.
        issue_store(make_ctag(4'h1,0),64'h11,64'h10,0,0);
        if (!buffer_valid || !parent_policy_accept || !generation_policy_accept
            || buffered_root_authorized)
            $fatal(1,"valid continuation without root authorization blocked/mislabeled");
        $display("TRACE CAPU-V07 S7 continuation_auth0 admitted=1 gen=1");
        clear_inputs(); flush=1; step();
        if (causal_head_transition_id!==64'h10 || causal_head_gen!==4'h0 || !causal_head_valid)
            $fatal(1,"flush mutated committed head/gen");

        issue_store(make_ctag(4'h0,0),64'h12,64'h10,0,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"stale generation admitted");
        $display("TRACE CAPU-V07 S8 stale_gen rejected=1 head_gen=0");

        issue_store(make_ctag(4'h2,0),64'h13,64'h10,0,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"skipped generation admitted");
        $display("TRACE CAPU-V07 S9 skipped_gen rejected=1 expected=1");

        issue_store(make_ctag(4'h1,0),64'h14,64'h09,0,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"wrong parent admitted");
        $display("TRACE CAPU-V07 S10 wrong_parent rejected=1 head=10");

        // Commit a continuation with root_authorized=0. Its retirement record
        // must not inherit the prior root authorization fact.
        issue_store(make_ctag(4'h1,0),64'h20,64'h10,0,0);
        if (!buffer_valid) $fatal(1,"gen1 child not admitted");
        commit_store();
        if (!memory_write_enable || causal_head_transition_id!==64'h20 || causal_head_gen!==4'h1
            || retired_root_authorized)
            $fatal(1,"continuation retirement carried root authorization");

        clear_inputs(); step();
        issue_store(make_ctag(4'h2,1),64'h21,64'h20,0,0);
        if (!buffer_valid) $fatal(1,"sealed gen2 child not admitted");
        commit_store();
        if (!memory_write_enable || !sealed_chain || causal_head_transition_id!==64'h21
            || causal_head_gen!==4'h2 || retired_root_authorized)
            $fatal(1,"sealed continuation retirement mismatch");
        $display("TRACE CAPU-V07 S11 sealed_commit head=21 gen=2 sealed=1");

        clear_inputs(); step();

        issue_store(make_ctag(4'h3,0),64'h22,64'h21,0,0);
        if (!issue_rejected || buffer_valid || !continuation_blocked)
            $fatal(1,"sealed exact-parent next-gen child escaped");
        $display("TRACE CAPU-V07 S12 sealed_correct_parent_gen rejected=1");

        // An unauthorized replacement root is blocked even though a new root is
        // exactly what a sealed chain structurally requires.
        issue_store(make_ctag(4'h0,0),64'h2F,64'h00,1,0);
        if (!issue_rejected || buffer_valid)
            $fatal(1,"unauthorized replacement root under seal admitted");
        $display("TRACE CAPU-V07 S13 unauthorized_root_under_seal rejected=1");

        // Authorized root may speculate under seal, but flush cannot replace
        // committed state or emit a fresh authorization event.
        prior_retired_auth = retired_root_authorized;
        issue_store(make_ctag(4'h0,0),64'h30,64'h00,1,1);
        if (!buffer_valid || !sealed_chain || !buffered_root_authorized)
            $fatal(1,"authorized root under seal not admitted");
        clear_inputs(); flush=1; step();
        if (!sealed_chain || causal_head_transition_id!==64'h21 || causal_head_gen!==4'h2
            || vcml_event_valid || retired_root_authorized!==prior_retired_auth)
            $fatal(1,"flushed authorized root changed committed/evidence state");
        $display("TRACE CAPU-V07 S14 authorized_root_flush no_event=1 old_head=21 old_gen=2");

        // Committed authorized root replaces head, resets GEN and carries root
        // authorization evidence at the retirement boundary.
        issue_store(make_ctag(4'h0,0),64'h31,64'h00,1,1);
        if (!buffer_valid || !buffered_root_authorized) $fatal(1,"replacement root not admitted");
        commit_store();
        if (!memory_write_enable || !vcml_event_valid || sealed_chain
            || causal_head_transition_id!==64'h31 || causal_head_gen!==4'h0
            || !retired_root_authorized)
            $fatal(1,"authorized replacement root did not establish fresh epoch");
        if (retired_transition_id!==64'h31 || retired_parent_ref!==64'h00 || retired_ctag[7:4]!==4'h0)
            $fatal(1,"replacement root retirement metadata mismatch");
        $display("TRACE CAPU-V07 S15 authorized_replacement_root head=31 gen=0 auth=1");

        clear_inputs(); step();

        // Drive the complete local 4-bit epoch to F using continuations with
        // root_authorized=0. They remain legitimate because root authorization
        // is a root-only trust boundary.
        last_tid = 64'h31;
        for (i = 1; i <= 15; i = i + 1) begin
            issue_store(make_ctag(i[3:0],0),64'h40 + i,last_tid,0,0);
            if (!buffer_valid || !generation_policy_accept || buffered_root_authorized)
                $fatal(1,"monotonic continuation not admitted cleanly");
            commit_store();
            if (!memory_write_enable || causal_head_transition_id!==(64'h40 + i)
                || causal_head_gen!==i[3:0] || retired_root_authorized)
                $fatal(1,"committed continuation generation/auth mismatch");
            last_tid = 64'h40 + i;
            clear_inputs(); step();
        end

        if (!generation_exhausted || causal_head_gen!==4'hF)
            $fatal(1,"GEN=F did not mark generation exhaustion");
        $display("TRACE CAPU-V07 S16 epoch_exhausted head_gen=F");

        issue_store(make_ctag(4'h0,0),64'h60,last_tid,0,0);
        if (!issue_rejected || buffer_valid || !continuation_blocked)
            $fatal(1,"generation wrap admitted");
        $display("TRACE CAPU-V07 S17 wrap_rejected head_gen=F");

        // Even after exhaustion, structural new-root intent is insufficient.
        issue_store(make_ctag(4'h0,0),64'h61,64'h00,1,0);
        if (!issue_rejected || buffer_valid)
            $fatal(1,"unauthorized root escaped exhausted epoch");
        $display("TRACE CAPU-V07 S18 exhausted_unauthorized_root rejected=1");

        // An authorized root is the explicit local escape from exhaustion.
        issue_store(make_ctag(4'h0,0),64'h62,64'h00,1,1);
        if (!buffer_valid || !buffered_root_authorized)
            $fatal(1,"authorized root after exhaustion not admitted");
        commit_store();
        if (!memory_write_enable || !vcml_event_valid || generation_exhausted
            || causal_head_transition_id!==64'h62 || causal_head_gen!==4'h0
            || !retired_root_authorized)
            $fatal(1,"authorized root did not reset exhausted local epoch");
        $display("TRACE CAPU-V07 S19 exhausted_authorized_root_committed head=62 gen=0 auth=1");

        $display("CAPU_VCML_BRIDGE_V07_RTL_PASS");
        $finish;
    end
endmodule
