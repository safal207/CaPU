module capu_vcml_store_buffer_formal;
    localparam int ADDR_WIDTH = 4;
    localparam int DATA_WIDTH = 8;
    localparam int TRANSITION_ID_WIDTH = 8;
    localparam int PARENT_REF_WIDTH = 8;
    localparam logic [3:0] DOM_RESERVED = 4'hF;
    localparam logic [3:0] CLASS_WRITE  = 4'h2;

    (* gclk *) reg clk;
    reg rst_n = 1'b0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg issue_valid, gate_allow, execute_ok;
    (* anyseq *) reg [ADDR_WIDTH-1:0] store_addr;
    (* anyseq *) reg [DATA_WIDTH-1:0] store_data;
    (* anyseq *) reg [15:0] store_ctag;
    (* anyseq *) reg store_ctag_valid;
    (* anyseq *) reg [TRANSITION_ID_WIDTH-1:0] store_transition_id;
    (* anyseq *) reg [PARENT_REF_WIDTH-1:0] store_parent_ref;
    (* anyseq *) reg explicit_new_cause;
    (* anyseq *) reg causal_valid, commit_request, flush;

    wire buffer_valid;
    wire [ADDR_WIDTH-1:0] buffered_addr;
    wire [DATA_WIDTH-1:0] buffered_data;
    wire [15:0] buffered_ctag;
    wire buffered_ctag_valid;
    wire [TRANSITION_ID_WIDTH-1:0] buffered_transition_id;
    wire [PARENT_REF_WIDTH-1:0] buffered_parent_ref;
    wire memory_write_enable;
    wire [ADDR_WIDTH-1:0] memory_write_addr;
    wire [DATA_WIDTH-1:0] memory_write_data;
    wire vcml_event_valid;
    wire [15:0] retired_ctag;
    wire [TRANSITION_ID_WIDTH-1:0] retired_transition_id;
    wire [PARENT_REF_WIDTH-1:0] retired_parent_ref;
    wire ctag_semantic_accept, sealed_chain, continuation_blocked;
    wire causal_head_valid, generation_policy_accept, generation_exhausted;
    wire parent_policy_accept, issue_rejected;
    wire [TRANSITION_ID_WIDTH-1:0] causal_head_transition_id;
    wire [3:0] causal_head_gen;

    capu_vcml_store_buffer #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
        .TRANSITION_ID_WIDTH(TRANSITION_ID_WIDTH),
        .PARENT_REF_WIDTH(PARENT_REF_WIDTH), .REQUIRE_WRITE_CLASS(1'b1)
    ) dut (
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

    reg ghost_commit = 1'b0;
    reg [ADDR_WIDTH-1:0] ghost_addr = '0;
    reg [DATA_WIDTH-1:0] ghost_data = '0;
    reg [15:0] ghost_ctag = '0;
    reg ghost_ctag_valid = 1'b0;
    reg [TRANSITION_ID_WIDTH-1:0] ghost_transition_id = '0;
    reg [PARENT_REF_WIDTH-1:0] ghost_parent_ref = '0;

    reg prev_flush = 1'b0;
    reg prev_head_valid = 1'b0;
    reg [TRANSITION_ID_WIDTH-1:0] prev_head = '0;
    reg [3:0] prev_head_gen = 4'h0;
    reg prev_sealed = 1'b0;

    reg seen_root_commit = 1'b0;
    reg seen_normal_continuation = 1'b0;
    reg seen_sealed_commit = 1'b0;
    reg seen_explicit_root_under_seal = 1'b0;
    reg seen_epoch_exhaustion = 1'b0;
    reg seen_exhausted_reject = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            ghost_commit <= 0;
            ghost_addr <= '0; ghost_data <= '0; ghost_ctag <= '0; ghost_ctag_valid <= 0;
            ghost_transition_id <= '0; ghost_parent_ref <= '0;
            prev_flush <= 0; prev_head_valid <= 0; prev_head <= '0;
            prev_head_gen <= 4'h0; prev_sealed <= 0;
            seen_root_commit <= 0; seen_normal_continuation <= 0;
            seen_sealed_commit <= 0; seen_explicit_root_under_seal <= 0;
            seen_epoch_exhaustion <= 0; seen_exhausted_reject <= 0;
        end else begin
            // Existing causal-retirement boundary remains exact.
            assert(memory_write_enable == ghost_commit);
            assert(vcml_event_valid == memory_write_enable);

            if (buffered_ctag_valid) begin
                assert(buffered_ctag[15:12] != DOM_RESERVED);
                assert(buffered_ctag[11:8] == CLASS_WRITE);
            end

            if (memory_write_enable) begin
                assert(ghost_ctag_valid);
                assert(ghost_ctag[15:12] != DOM_RESERVED);
                assert(ghost_ctag[11:8] == CLASS_WRITE);
                assert(memory_write_addr == ghost_addr);
                assert(memory_write_data == ghost_data);
                assert(retired_ctag == ghost_ctag);
                assert(retired_transition_id == ghost_transition_id);
                assert(retired_parent_ref == ghost_parent_ref);
                assert(!buffer_valid);
            end

            // v0.6 normal continuation requires exact parent identity plus the
            // next committed 4-bit generation. F -> 0 wrap is forbidden.
            if (issue_valid && gate_allow && execute_ok && ctag_semantic_accept
                && !buffer_valid && !explicit_new_cause && parent_policy_accept) begin
                assert(causal_head_valid);
                assert(!sealed_chain);
                assert(!generation_exhausted);
                assert(causal_head_gen != 4'hF);
                assert(store_parent_ref == causal_head_transition_id);
                assert(store_ctag[7:4] == (causal_head_gen + 4'h1));
                assert(generation_policy_accept);
            end

            // Explicit root policy deliberately starts a fresh local epoch.
            if (issue_valid && gate_allow && execute_ok && ctag_semantic_accept
                && !buffer_valid && explicit_new_cause && parent_policy_accept) begin
                assert(store_parent_ref == '0);
                assert(store_ctag[7:4] == 4'h0);
                assert(generation_policy_accept);
            end

            // Seal and generation exhaustion independently block automatic child admission.
            if (sealed_chain && issue_valid && !explicit_new_cause) begin
                assert(!parent_policy_accept);
                assert(issue_rejected);
            end

            if (generation_exhausted && issue_valid && !explicit_new_cause) begin
                assert(!parent_policy_accept);
                assert(!generation_policy_accept);
                assert(issue_rejected);
                assert(continuation_blocked);
            end

            // Flush is speculative-only: committed head identity, GEN, and SEAL survive.
            if (prev_flush) begin
                assert(causal_head_valid == prev_head_valid);
                assert(causal_head_transition_id == prev_head);
                assert(causal_head_gen == prev_head_gen);
                assert(sealed_chain == prev_sealed);
            end

            // Reachability bookkeeping based on committed/observable state.
            if (memory_write_enable) begin
                if ((ghost_parent_ref == '0) && (ghost_ctag[7:4] == 4'h0))
                    seen_root_commit <= 1'b1;
                else
                    seen_normal_continuation <= 1'b1;
                if (ghost_ctag[0])
                    seen_sealed_commit <= 1'b1;
            end

            if (seen_sealed_commit && sealed_chain && buffer_valid
                && buffered_parent_ref == '0 && buffered_ctag[7:4] == 4'h0)
                seen_explicit_root_under_seal <= 1'b1;

            if (causal_head_valid && causal_head_gen == 4'hF)
                seen_epoch_exhaustion <= 1'b1;

            if (generation_exhausted && issue_valid && !explicit_new_cause && issue_rejected)
                seen_exhausted_reject <= 1'b1;

            // Non-vacuity: ordinary successor, root-under-seal, and exhausted-epoch
            // rejection must all be reachable in the bounded model.
            cover(seen_root_commit && seen_normal_continuation && causal_head_valid);
            cover(seen_sealed_commit && seen_explicit_root_under_seal && sealed_chain);
            cover(seen_epoch_exhaustion && seen_exhausted_reject && generation_exhausted);

            ghost_commit <= buffer_valid
                         && causal_valid
                         && buffered_ctag_valid
                         && commit_request
                         && !flush;
            ghost_addr <= buffered_addr;
            ghost_data <= buffered_data;
            ghost_ctag <= buffered_ctag;
            ghost_ctag_valid <= buffered_ctag_valid;
            ghost_transition_id <= buffered_transition_id;
            ghost_parent_ref <= buffered_parent_ref;

            prev_flush <= flush;
            prev_head_valid <= causal_head_valid;
            prev_head <= causal_head_transition_id;
            prev_head_gen <= causal_head_gen;
            prev_sealed <= sealed_chain;
        end
    end
endmodule
