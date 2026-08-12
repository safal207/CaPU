`timescale 1ns/1ps

module capu_vcml_store_buffer_tb;
    logic clk = 1'b0, rst_n = 1'b0;
    logic issue_valid, gate_allow, execute_ok;
    logic [15:0] store_addr;
    logic [31:0] store_data;
    logic [15:0] store_ctag;
    logic store_ctag_valid;
    logic [63:0] store_transition_id, store_parent_ref;
    logic explicit_new_cause, causal_valid, commit_request, flush;

    logic buffer_valid, memory_write_enable, vcml_event_valid;
    logic [15:0] buffered_addr, buffered_ctag, memory_write_addr, retired_ctag;
    logic [31:0] buffered_data, memory_write_data;
    logic buffered_ctag_valid;
    logic [63:0] buffered_transition_id, buffered_parent_ref;
    logic [63:0] retired_transition_id, retired_parent_ref;
    logic ctag_semantic_accept, sealed_chain, continuation_blocked;
    logic causal_head_valid, generation_policy_accept, generation_exhausted;
    logic parent_policy_accept, issue_rejected;
    logic [63:0] causal_head_transition_id;
    logic [3:0] causal_head_gen;

    integer i;
    logic [63:0] last_tid;

    capu_vcml_store_buffer dut (
        .clk(clk), .rst_n(rst_n),
        .issue_valid(issue_valid), .gate_allow(gate_allow), .execute_ok(execute_ok),
        .store_addr(store_addr), .store_data(store_data),
        .store_ctag(store_ctag), .store_ctag_valid(store_ctag_valid),
        .store_transition_id(store_transition_id), .store_parent_ref(store_parent_ref),
        .explicit_new_cause(explicit_new_cause),
        .causal_valid(causal_valid), .commit_request(commit_request), .flush(flush),
        .buffer_valid(buffer_valid), .buffered_addr(buffered_addr), .buffered_data(buffered_data),
        .buffered_ctag(buffered_ctag), .buffered_ctag_valid(buffered_ctag_valid),
        .buffered_transition_id(buffered_transition_id), .buffered_parent_ref(buffered_parent_ref),
        .memory_write_enable(memory_write_enable), .memory_write_addr(memory_write_addr),
        .memory_write_data(memory_write_data), .vcml_event_valid(vcml_event_valid),
        .retired_ctag(retired_ctag), .retired_transition_id(retired_transition_id),
        .retired_parent_ref(retired_parent_ref), .ctag_semantic_accept(ctag_semantic_accept),
        .sealed_chain(sealed_chain), .continuation_blocked(continuation_blocked),
        .causal_head_valid(causal_head_valid), .causal_head_transition_id(causal_head_transition_id),
        .causal_head_gen(causal_head_gen), .generation_policy_accept(generation_policy_accept),
        .generation_exhausted(generation_exhausted),
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
        explicit_new_cause=0; causal_valid=0; commit_request=0; flush=0;
    end endtask

    task automatic issue_store(input [15:0] tag,input [63:0] tid,input [63:0] parent,input bit root); begin
        clear_inputs(); issue_valid=1; gate_allow=1; execute_ok=1;
        store_addr=tid[15:0]; store_data=32'hCA00_0000|tid[15:0]; store_ctag=tag; store_ctag_valid=1;
        store_transition_id=tid; store_parent_ref=parent; explicit_new_cause=root; step();
    end endtask

    task automatic commit_store; begin
        clear_inputs(); causal_valid=1; commit_request=1; step();
    end endtask

    initial begin
        clear_inputs(); repeat(2) @(posedge clk); rst_n=1; step();
        if (causal_head_valid || sealed_chain || buffer_valid || causal_head_gen != 4'h0)
            $fatal(1,"reset state invalid");
        $display("TRACE CAPU-V06 S0 reset head_valid=0 gen=0 sealed=0");

        // No committed head: automatic continuation fails closed.
        issue_store(make_ctag(4'h1,0),64'h01,64'h00,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"headless continuation admitted");
        $display("TRACE CAPU-V06 S1 headless_child rejected=1");

        // Existing CTAG validation remains in force.
        issue_store(16'hF200,64'h02,64'h00,1);
        if (!issue_rejected || buffer_valid) $fatal(1,"invalid CTAG root admitted");
        $display("TRACE CAPU-V06 S2 invalid_ctag rejected=1");

        // Explicit root policy is structural and fail-closed: parent=0, GEN=0.
        issue_store(make_ctag(4'h0,0),64'h03,64'h99,1);
        if (!issue_rejected || buffer_valid) $fatal(1,"nonzero-parent root admitted");
        $display("TRACE CAPU-V06 S3 malformed_root_parent rejected=1");

        issue_store(make_ctag(4'h1,0),64'h04,64'h00,1);
        if (!issue_rejected || buffer_valid) $fatal(1,"nonzero-generation root admitted");
        $display("TRACE CAPU-V06 S4 malformed_root_gen rejected=1");

        // First explicit root establishes head identity and GEN=0.
        issue_store(make_ctag(4'h0,0),64'h10,64'h00,1);
        if (!buffer_valid || !parent_policy_accept || !generation_policy_accept)
            $fatal(1,"explicit root admission failed");
        commit_store();
        if (!memory_write_enable || !causal_head_valid || causal_head_transition_id!==64'h10
            || causal_head_gen!==4'h0 || sealed_chain)
            $fatal(1,"root commit did not establish head/gen");
        $display("TRACE CAPU-V06 S5 root_committed head=10 gen=0 sealed=0");

        clear_inputs(); step();

        // Exact parent + next generation is admissible. Flush must not move head/gen.
        issue_store(make_ctag(4'h1,0),64'h11,64'h10,0);
        if (!buffer_valid || !parent_policy_accept || !generation_policy_accept)
            $fatal(1,"valid parent+generation continuation blocked");
        $display("TRACE CAPU-V06 S6 valid_parent_gen admitted=1 gen=1");
        clear_inputs(); flush=1; step();
        if (causal_head_transition_id!==64'h10 || causal_head_gen!==4'h0 || !causal_head_valid)
            $fatal(1,"flush mutated committed head/gen");

        // Same parent but stale generation is rejected before speculation.
        issue_store(make_ctag(4'h0,0),64'h12,64'h10,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"stale generation admitted");
        $display("TRACE CAPU-V06 S7 stale_gen rejected=1 head_gen=0");

        // Same parent but skipped generation is also rejected.
        issue_store(make_ctag(4'h2,0),64'h13,64'h10,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"skipped generation admitted");
        $display("TRACE CAPU-V06 S8 skipped_gen rejected=1 expected=1");

        // Correct generation cannot compensate for a wrong parent.
        issue_store(make_ctag(4'h1,0),64'h14,64'h09,0);
        if (!issue_rejected || buffer_valid) $fatal(1,"wrong parent admitted");
        $display("TRACE CAPU-V06 S9 wrong_parent rejected=1 head=10");

        // Commit GEN=1 child, then a sealed GEN=2 child.
        issue_store(make_ctag(4'h1,0),64'h20,64'h10,0);
        if (!buffer_valid) $fatal(1,"gen1 child not admitted");
        commit_store();
        if (!memory_write_enable || causal_head_transition_id!==64'h20 || causal_head_gen!==4'h1)
            $fatal(1,"gen1 child did not advance committed epoch");

        clear_inputs(); step();
        issue_store(make_ctag(4'h2,1),64'h21,64'h20,0);
        if (!buffer_valid) $fatal(1,"sealed gen2 child not admitted");
        commit_store();
        if (!memory_write_enable || !sealed_chain || causal_head_transition_id!==64'h21
            || causal_head_gen!==4'h2)
            $fatal(1,"sealed child did not commit head/gen/seal");
        $display("TRACE CAPU-V06 S10 sealed_commit head=21 gen=2 sealed=1");

        clear_inputs(); step();

        // Even exact parent + next GEN cannot auto-continue a sealed chain.
        issue_store(make_ctag(4'h3,0),64'h22,64'h21,0);
        if (!issue_rejected || buffer_valid || !continuation_blocked)
            $fatal(1,"sealed exact-parent next-gen child escaped");
        $display("TRACE CAPU-V06 S11 sealed_correct_parent_gen rejected=1");

        // Explicit GEN=0 root may speculate under seal; flush preserves head/gen/seal.
        issue_store(make_ctag(4'h0,0),64'h30,64'h00,1);
        if (!buffer_valid || !sealed_chain) $fatal(1,"new root under seal not admitted");
        clear_inputs(); flush=1; step();
        if (!sealed_chain || causal_head_transition_id!==64'h21 || causal_head_gen!==4'h2)
            $fatal(1,"flush weakened committed head/gen/seal");
        $display("TRACE CAPU-V06 S12 root_flushed old_head=21 old_gen=2 old_seal=1");

        // A root under seal still cannot lie about its starting generation.
        issue_store(make_ctag(4'h1,0),64'h30,64'h00,1);
        if (!issue_rejected || buffer_valid) $fatal(1,"bad-generation root escaped seal boundary");

        // Committed explicit root replaces head, resets local GEN to zero, opens chain.
        issue_store(make_ctag(4'h0,0),64'h31,64'h00,1);
        if (!buffer_valid) $fatal(1,"replacement root not admitted");
        commit_store();
        if (!memory_write_enable || sealed_chain || causal_head_transition_id!==64'h31
            || causal_head_gen!==4'h0)
            $fatal(1,"replacement root did not establish fresh head/gen");
        if (retired_transition_id!==64'h31 || retired_parent_ref!==64'h00 || retired_ctag[7:4]!==4'h0)
            $fatal(1,"replacement root retirement metadata mismatch");
        $display("TRACE CAPU-V06 S13 root_committed head=31 gen=0 sealed=0");

        clear_inputs(); step();

        // Drive the full 4-bit epoch to F without wrapping.
        last_tid = 64'h31;
        for (i = 1; i <= 15; i = i + 1) begin
            issue_store(make_ctag(i[3:0],0),64'h40 + i,last_tid,0);
            if (!buffer_valid || !generation_policy_accept)
                $fatal(1,"monotonic generation step not admitted");
            commit_store();
            if (!memory_write_enable || causal_head_transition_id!==(64'h40 + i)
                || causal_head_gen!==i[3:0])
                $fatal(1,"committed generation did not advance exactly");
            last_tid = 64'h40 + i;
            clear_inputs(); step();
        end

        if (!generation_exhausted || causal_head_gen!==4'hF)
            $fatal(1,"GEN=F did not mark generation exhaustion");
        $display("TRACE CAPU-V06 S14 epoch_exhausted head_gen=F");

        // F -> 0 automatic wrap is forbidden even with exact parent.
        issue_store(make_ctag(4'h0,0),64'h60,last_tid,0);
        if (!issue_rejected || buffer_valid || !continuation_blocked)
            $fatal(1,"generation wrap admitted");
        $display("TRACE CAPU-V06 S15 wrap_rejected head_gen=F");

        // Explicit root is the only local escape from exhausted epoch; flush is harmless.
        issue_store(make_ctag(4'h0,0),64'h61,64'h00,1);
        if (!buffer_valid) $fatal(1,"explicit root after exhaustion not admitted");
        clear_inputs(); flush=1; step();
        if (!generation_exhausted || causal_head_gen!==4'hF || causal_head_transition_id!==last_tid)
            $fatal(1,"flushed root changed exhausted committed epoch");
        $display("TRACE CAPU-V06 S16 exhausted_root_flush preserved=1");

        $display("CAPU_VCML_BRIDGE_V06_RTL_PASS");
        $finish;
    end
endmodule
