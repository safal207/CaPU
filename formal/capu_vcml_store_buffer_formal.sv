module capu_vcml_store_buffer_formal;
    localparam int ADDR_WIDTH = 4;
    localparam int DATA_WIDTH = 8;
    localparam int TRANSITION_ID_WIDTH = 8;
    localparam int PARENT_REF_WIDTH = 8;
    localparam int AUTHORIZATION_REF_WIDTH = 4;
    localparam int POLICY_EPOCH_WIDTH = 4;
    localparam int SPENT_AUTHORIZATION_SLOTS = 4;
    localparam int SPENT_COUNT_WIDTH = $clog2(SPENT_AUTHORIZATION_SLOTS + 1);
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
    (* anyseq *) reg root_authorized;
    (* anyseq *) reg [AUTHORIZATION_REF_WIDTH-1:0] root_authorization_ref;
    (* anyseq *) reg [POLICY_EPOCH_WIDTH-1:0] root_policy_epoch;
    (* anyseq *) reg causal_valid, commit_request, flush;

    wire buffer_valid;
    wire [ADDR_WIDTH-1:0] buffered_addr;
    wire [DATA_WIDTH-1:0] buffered_data;
    wire [15:0] buffered_ctag;
    wire buffered_ctag_valid;
    wire [TRANSITION_ID_WIDTH-1:0] buffered_transition_id;
    wire [PARENT_REF_WIDTH-1:0] buffered_parent_ref;
    wire buffered_root_authorized;
    wire [AUTHORIZATION_REF_WIDTH-1:0] buffered_root_authorization_ref;
    wire [POLICY_EPOCH_WIDTH-1:0] buffered_root_policy_epoch;
    wire memory_write_enable;
    wire [ADDR_WIDTH-1:0] memory_write_addr;
    wire [DATA_WIDTH-1:0] memory_write_data;
    wire vcml_event_valid;
    wire [15:0] retired_ctag;
    wire [TRANSITION_ID_WIDTH-1:0] retired_transition_id;
    wire [PARENT_REF_WIDTH-1:0] retired_parent_ref;
    wire retired_root_authorized;
    wire [AUTHORIZATION_REF_WIDTH-1:0] retired_root_authorization_ref;
    wire [POLICY_EPOCH_WIDTH-1:0] retired_root_policy_epoch;
    wire ctag_semantic_accept, sealed_chain, continuation_blocked;
    wire causal_head_valid, generation_policy_accept, generation_exhausted;
    wire root_authorization_accept, parent_policy_accept, issue_rejected;
    wire authorization_ref_fresh, authorization_replay_detected;
    wire authorization_capacity_exhausted, retired_authorization_ref_spent;
    wire [SPENT_COUNT_WIDTH-1:0] spent_authorization_count;
    wire [TRANSITION_ID_WIDTH-1:0] causal_head_transition_id;
    wire [3:0] causal_head_gen;

    capu_vcml_store_buffer #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
        .TRANSITION_ID_WIDTH(TRANSITION_ID_WIDTH),
        .PARENT_REF_WIDTH(PARENT_REF_WIDTH),
        .AUTHORIZATION_REF_WIDTH(AUTHORIZATION_REF_WIDTH),
        .POLICY_EPOCH_WIDTH(POLICY_EPOCH_WIDTH),
        .SPENT_AUTHORIZATION_SLOTS(SPENT_AUTHORIZATION_SLOTS),
        .REQUIRE_WRITE_CLASS(1'b1)
    ) dut (
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
        .authorization_ref_fresh(authorization_ref_fresh),
        .authorization_replay_detected(authorization_replay_detected),
        .authorization_capacity_exhausted(authorization_capacity_exhausted),
        .spent_authorization_count(spent_authorization_count),
        .retired_authorization_ref_spent(retired_authorization_ref_spent),
        .parent_policy_accept(parent_policy_accept), .issue_rejected(issue_rejected)
    );

    reg ghost_commit = 1'b0;
    reg [ADDR_WIDTH-1:0] ghost_addr = '0;
    reg [DATA_WIDTH-1:0] ghost_data = '0;
    reg [15:0] ghost_ctag = '0;
    reg ghost_ctag_valid = 1'b0;
    reg [TRANSITION_ID_WIDTH-1:0] ghost_transition_id = '0;
    reg [PARENT_REF_WIDTH-1:0] ghost_parent_ref = '0;
    reg ghost_root_authorized = 1'b0;
    reg [AUTHORIZATION_REF_WIDTH-1:0] ghost_root_authorization_ref = '0;
    reg [POLICY_EPOCH_WIDTH-1:0] ghost_root_policy_epoch = '0;

    reg prev_flush = 1'b0;
    reg prev_head_valid = 1'b0;
    reg [TRANSITION_ID_WIDTH-1:0] prev_head = '0;
    reg [3:0] prev_head_gen = 4'h0;
    reg prev_sealed = 1'b0;
    reg prev_retired_root_authorized = 1'b0;
    reg [AUTHORIZATION_REF_WIDTH-1:0] prev_retired_auth_ref = '0;
    reg [POLICY_EPOCH_WIDTH-1:0] prev_retired_policy_epoch = '0;
    reg [SPENT_COUNT_WIDTH-1:0] prev_spent_count = '0;

    reg seen_authorized_root_commit = 1'b0;
    reg seen_unauthorized_root_reject = 1'b0;
    reg seen_zero_ref_root_reject = 1'b0;
    reg seen_replay_root_reject = 1'b0;
    reg seen_normal_continuation = 1'b0;
    reg seen_sealed_commit = 1'b0;
    reg seen_authorized_root_under_seal = 1'b0;
    reg seen_epoch_exhaustion = 1'b0;
    reg seen_authorized_root_after_exhaustion = 1'b0;
    reg seen_spent_capacity_full = 1'b0;
    reg seen_capacity_reject = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            ghost_commit <= 0;
            ghost_addr <= '0; ghost_data <= '0; ghost_ctag <= '0; ghost_ctag_valid <= 0;
            ghost_transition_id <= '0; ghost_parent_ref <= '0; ghost_root_authorized <= 0;
            ghost_root_authorization_ref <= '0; ghost_root_policy_epoch <= '0;
            prev_flush <= 0; prev_head_valid <= 0; prev_head <= '0;
            prev_head_gen <= 4'h0; prev_sealed <= 0; prev_retired_root_authorized <= 0;
            prev_retired_auth_ref <= '0; prev_retired_policy_epoch <= '0; prev_spent_count <= '0;
            seen_authorized_root_commit <= 0; seen_unauthorized_root_reject <= 0;
            seen_zero_ref_root_reject <= 0; seen_replay_root_reject <= 0;
            seen_normal_continuation <= 0; seen_sealed_commit <= 0;
            seen_authorized_root_under_seal <= 0; seen_epoch_exhaustion <= 0;
            seen_authorized_root_after_exhaustion <= 0; seen_spent_capacity_full <= 0;
            seen_capacity_reject <= 0;
        end else begin
            assert(memory_write_enable == ghost_commit);
            assert(vcml_event_valid == memory_write_enable);
            assert(spent_authorization_count <= SPENT_AUTHORIZATION_SLOTS);
            assert(authorization_capacity_exhausted
                   == (spent_authorization_count == SPENT_AUTHORIZATION_SLOTS));

            if (buffered_ctag_valid) begin
                assert(buffered_ctag[15:12] != DOM_RESERVED);
                assert(buffered_ctag[11:8] == CLASS_WRITE);
                if (buffered_root_authorized)
                    assert(buffered_root_authorization_ref != '0);
                else begin
                    assert(buffered_root_authorization_ref == '0);
                    assert(buffered_root_policy_epoch == '0);
                end
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
                assert(retired_root_authorized == ghost_root_authorized);
                assert(retired_root_authorization_ref == ghost_root_authorization_ref);
                assert(retired_root_policy_epoch == ghost_root_policy_epoch);
                assert(!buffer_valid);

                if ((ghost_parent_ref == '0) && (ghost_ctag[7:4] == 4'h0)) begin
                    assert(ghost_root_authorized);
                    assert(ghost_root_authorization_ref != '0);
                    assert(retired_root_authorized);
                    assert(retired_root_authorization_ref != '0);
                    assert(retired_authorization_ref_spent);
                    assert(spent_authorization_count == prev_spent_count + 1'b1);
                end else begin
                    assert(!ghost_root_authorized);
                    assert(ghost_root_authorization_ref == '0);
                    assert(ghost_root_policy_epoch == '0);
                    assert(spent_authorization_count == prev_spent_count);
                end
            end else begin
                assert(spent_authorization_count == prev_spent_count);
            end

            // A fresh explicit root is admitted only with a nonzero, unspent
            // reference while local no-eviction capacity remains available.
            if (issue_valid && gate_allow && execute_ok && ctag_semantic_accept
                && !buffer_valid && explicit_new_cause && parent_policy_accept) begin
                assert(root_authorized);
                assert(root_authorization_ref != '0);
                assert(authorization_ref_fresh);
                assert(!authorization_replay_detected);
                assert(!authorization_capacity_exhausted);
                assert(root_authorization_accept);
                assert(store_parent_ref == '0);
                assert(store_ctag[7:4] == 4'h0);
                assert(generation_policy_accept);
            end

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

            if (issue_valid && explicit_new_cause && !root_authorized) begin
                assert(!root_authorization_accept);
                assert(!parent_policy_accept);
                assert(issue_rejected);
                seen_unauthorized_root_reject <= 1'b1;
            end

            if (issue_valid && explicit_new_cause && root_authorized
                && root_authorization_ref == '0) begin
                assert(!root_authorization_accept);
                assert(!parent_policy_accept);
                assert(issue_rejected);
                seen_zero_ref_root_reject <= 1'b1;
            end

            if (issue_valid && explicit_new_cause && authorization_replay_detected) begin
                assert(!authorization_ref_fresh);
                assert(!root_authorization_accept);
                assert(!parent_policy_accept);
                assert(issue_rejected);
                seen_replay_root_reject <= 1'b1;
            end

            if (issue_valid && explicit_new_cause && root_authorized
                && root_authorization_ref != '0 && authorization_capacity_exhausted) begin
                assert(!root_authorization_accept);
                assert(!parent_policy_accept);
                assert(issue_rejected);
                if (authorization_ref_fresh)
                    seen_capacity_reject <= 1'b1;
            end

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

            if (prev_flush) begin
                assert(causal_head_valid == prev_head_valid);
                assert(causal_head_transition_id == prev_head);
                assert(causal_head_gen == prev_head_gen);
                assert(sealed_chain == prev_sealed);
                assert(retired_root_authorized == prev_retired_root_authorized);
                assert(retired_root_authorization_ref == prev_retired_auth_ref);
                assert(retired_root_policy_epoch == prev_retired_policy_epoch);
                assert(spent_authorization_count == prev_spent_count);
                assert(!vcml_event_valid);
            end

            if (memory_write_enable) begin
                if ((ghost_parent_ref == '0) && (ghost_ctag[7:4] == 4'h0)
                    && ghost_root_authorized && ghost_root_authorization_ref != '0)
                    seen_authorized_root_commit <= 1'b1;
                else
                    seen_normal_continuation <= 1'b1;
                if (ghost_ctag[0])
                    seen_sealed_commit <= 1'b1;
            end

            if (seen_authorized_root_commit && authorization_replay_detected && issue_rejected)
                seen_replay_root_reject <= 1'b1;

            if (seen_sealed_commit && sealed_chain && buffer_valid
                && buffered_parent_ref == '0 && buffered_ctag[7:4] == 4'h0
                && buffered_root_authorized && buffered_root_authorization_ref != '0)
                seen_authorized_root_under_seal <= 1'b1;

            if (causal_head_valid && causal_head_gen == 4'hF)
                seen_epoch_exhaustion <= 1'b1;

            if (seen_epoch_exhaustion && generation_exhausted && buffer_valid
                && buffered_parent_ref == '0 && buffered_ctag[7:4] == 4'h0
                && buffered_root_authorized && buffered_root_authorization_ref != '0)
                seen_authorized_root_after_exhaustion <= 1'b1;

            if (authorization_capacity_exhausted)
                seen_spent_capacity_full <= 1'b1;

            cover(seen_authorized_root_commit);
            cover(seen_unauthorized_root_reject);
            cover(seen_zero_ref_root_reject);
            cover(seen_authorized_root_commit && seen_replay_root_reject);
            cover(seen_authorized_root_commit && seen_normal_continuation && causal_head_valid);
            cover(seen_sealed_commit && seen_authorized_root_under_seal && sealed_chain);
            cover(seen_epoch_exhaustion && seen_authorized_root_after_exhaustion);
            cover(seen_spent_capacity_full);
            cover(seen_spent_capacity_full && seen_capacity_reject);

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
            ghost_root_authorized <= buffered_root_authorized;
            ghost_root_authorization_ref <= buffered_root_authorization_ref;
            ghost_root_policy_epoch <= buffered_root_policy_epoch;

            prev_flush <= flush;
            prev_head_valid <= causal_head_valid;
            prev_head <= causal_head_transition_id;
            prev_head_gen <= causal_head_gen;
            prev_sealed <= sealed_chain;
            prev_retired_root_authorized <= retired_root_authorized;
            prev_retired_auth_ref <= retired_root_authorization_ref;
            prev_retired_policy_epoch <= retired_root_policy_epoch;
            prev_spent_count <= spent_authorization_count;
        end
    end
endmodule
