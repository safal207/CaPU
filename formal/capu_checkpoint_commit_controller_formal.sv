module capu_checkpoint_commit_controller_formal;
    localparam int REF_W = 3;
    localparam int EPOCH_W = 3;
    localparam int STATE_W = 3;
    localparam logic [EPOCH_W-1:0] EPOCH_MAX = {EPOCH_W{1'b1}};

    (* gclk *) reg clk;
    reg rst_n = 1'b0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg current_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] current_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] current_anchor_epoch;
    (* anyseq *) reg [STATE_W-1:0] current_anchor_state_tag;

    (* anyseq *) reg checkpoint_prepare_valid;
    (* anyseq *) reg [REF_W-1:0] candidate_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] candidate_checkpoint_epoch;
    (* anyseq *) reg [STATE_W-1:0] candidate_checkpoint_state_tag;
    (* anyseq *) reg checkpoint_abort;

    (* anyseq *) reg snapshot_persisted_valid;
    (* anyseq *) reg [REF_W-1:0] persisted_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] persisted_checkpoint_epoch;
    (* anyseq *) reg [STATE_W-1:0] persisted_checkpoint_state_tag;

    (* anyseq *) reg anchor_commit_ack_valid;
    (* anyseq *) reg ack_base_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] ack_base_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_base_anchor_epoch;
    (* anyseq *) reg [STATE_W-1:0] ack_base_anchor_state_tag;
    (* anyseq *) reg [REF_W-1:0] ack_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_checkpoint_epoch;
    (* anyseq *) reg [STATE_W-1:0] ack_checkpoint_state_tag;

    wire prepare_accept, prepare_rejected;
    wire candidate_pending, candidate_invalid, epoch_exhausted, stale_base_detected;
    wire snapshot_persist_accept, snapshot_persist_rejected, snapshot_durable;
    wire anchor_commit_request, anchor_commit_ack_accept, anchor_commit_ack_rejected;
    wire checkpoint_commit_event;
    wire request_base_anchor_valid;
    wire [REF_W-1:0] request_base_anchor_ref;
    wire [EPOCH_W-1:0] request_base_anchor_epoch;
    wire [STATE_W-1:0] request_base_anchor_state_tag;
    wire [REF_W-1:0] request_checkpoint_ref;
    wire [EPOCH_W-1:0] request_checkpoint_epoch;
    wire [STATE_W-1:0] request_checkpoint_state_tag;

    capu_checkpoint_commit_controller #(
        .CHECKPOINT_REF_WIDTH(REF_W),
        .CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
        .CHECKPOINT_STATE_TAG_WIDTH(STATE_W)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .current_anchor_valid(current_anchor_valid),
        .current_anchor_ref(current_anchor_ref),
        .current_anchor_epoch(current_anchor_epoch),
        .current_anchor_state_tag(current_anchor_state_tag),
        .checkpoint_prepare_valid(checkpoint_prepare_valid),
        .candidate_checkpoint_ref(candidate_checkpoint_ref),
        .candidate_checkpoint_epoch(candidate_checkpoint_epoch),
        .candidate_checkpoint_state_tag(candidate_checkpoint_state_tag),
        .checkpoint_abort(checkpoint_abort),
        .snapshot_persisted_valid(snapshot_persisted_valid),
        .persisted_checkpoint_ref(persisted_checkpoint_ref),
        .persisted_checkpoint_epoch(persisted_checkpoint_epoch),
        .persisted_checkpoint_state_tag(persisted_checkpoint_state_tag),
        .anchor_commit_ack_valid(anchor_commit_ack_valid),
        .ack_base_anchor_valid(ack_base_anchor_valid),
        .ack_base_anchor_ref(ack_base_anchor_ref),
        .ack_base_anchor_epoch(ack_base_anchor_epoch),
        .ack_base_anchor_state_tag(ack_base_anchor_state_tag),
        .ack_checkpoint_ref(ack_checkpoint_ref),
        .ack_checkpoint_epoch(ack_checkpoint_epoch),
        .ack_checkpoint_state_tag(ack_checkpoint_state_tag),
        .prepare_accept(prepare_accept),
        .prepare_rejected(prepare_rejected),
        .candidate_pending(candidate_pending),
        .candidate_invalid(candidate_invalid),
        .epoch_exhausted(epoch_exhausted),
        .stale_base_detected(stale_base_detected),
        .snapshot_persist_accept(snapshot_persist_accept),
        .snapshot_persist_rejected(snapshot_persist_rejected),
        .snapshot_durable(snapshot_durable),
        .anchor_commit_request(anchor_commit_request),
        .anchor_commit_ack_accept(anchor_commit_ack_accept),
        .anchor_commit_ack_rejected(anchor_commit_ack_rejected),
        .checkpoint_commit_event(checkpoint_commit_event),
        .request_base_anchor_valid(request_base_anchor_valid),
        .request_base_anchor_ref(request_base_anchor_ref),
        .request_base_anchor_epoch(request_base_anchor_epoch),
        .request_base_anchor_state_tag(request_base_anchor_state_tag),
        .request_checkpoint_ref(request_checkpoint_ref),
        .request_checkpoint_epoch(request_checkpoint_epoch),
        .request_checkpoint_state_tag(request_checkpoint_state_tag)
    );

    reg prev_prepare_accept = 1'b0;
    reg prev_snapshot_persist_accept = 1'b0;
    reg prev_checkpoint_commit_event = 1'b0;
    reg prev_stale_base_detected = 1'b0;
    reg prev_abort = 1'b0;
    reg [REF_W-1:0] prev_candidate_ref = '0;
    reg [EPOCH_W-1:0] prev_candidate_epoch = '0;
    reg [STATE_W-1:0] prev_candidate_state_tag = '0;

    reg seen_initial_prepare = 1'b0;
    reg seen_initial_durable = 1'b0;
    reg seen_initial_commit = 1'b0;
    reg seen_wrong_persist_reject = 1'b0;
    reg seen_stale_base = 1'b0;
    reg seen_durable_abort = 1'b0;
    reg seen_anchored_commit = 1'b0;
    reg seen_epoch_exhausted_reject = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            prev_prepare_accept <= 1'b0;
            prev_snapshot_persist_accept <= 1'b0;
            prev_checkpoint_commit_event <= 1'b0;
            prev_stale_base_detected <= 1'b0;
            prev_abort <= 1'b0;
            prev_candidate_ref <= '0;
            prev_candidate_epoch <= '0;
            prev_candidate_state_tag <= '0;
            seen_initial_prepare <= 1'b0;
            seen_initial_durable <= 1'b0;
            seen_initial_commit <= 1'b0;
            seen_wrong_persist_reject <= 1'b0;
            seen_stale_base <= 1'b0;
            seen_durable_abort <= 1'b0;
            seen_anchored_commit <= 1'b0;
            seen_epoch_exhausted_reject <= 1'b0;
        end else begin
            if (prepare_accept) begin
                assert(checkpoint_prepare_valid);
                assert(!checkpoint_abort);
                assert(!candidate_pending);
                assert(!candidate_invalid);
                assert(candidate_checkpoint_ref != '0);
                assert(candidate_checkpoint_state_tag != '0);
                if (current_anchor_valid) begin
                    assert(current_anchor_ref != '0);
                    assert(current_anchor_epoch != '0);
                    assert(current_anchor_state_tag != '0);
                    assert(current_anchor_epoch != EPOCH_MAX);
                    assert(candidate_checkpoint_epoch == current_anchor_epoch + 1'b1);
                end else begin
                    assert(candidate_checkpoint_epoch == 1);
                end
            end

            if (checkpoint_prepare_valid && candidate_invalid)
                assert(!prepare_accept);

            if (epoch_exhausted && checkpoint_prepare_valid)
                assert(!prepare_accept);

            if (snapshot_persist_accept) begin
                assert(snapshot_persisted_valid);
                assert(candidate_pending);
                assert(!snapshot_durable);
                assert(!stale_base_detected);
                assert(persisted_checkpoint_ref == request_checkpoint_ref);
                assert(persisted_checkpoint_epoch == request_checkpoint_epoch);
                assert(persisted_checkpoint_state_tag == request_checkpoint_state_tag);
            end

            if (anchor_commit_request) begin
                assert(candidate_pending);
                assert(snapshot_durable);
                assert(!stale_base_detected);
                assert(!checkpoint_abort);
            end

            if (stale_base_detected) begin
                assert(candidate_pending);
                assert(!anchor_commit_request);
            end

            if (anchor_commit_ack_accept) begin
                assert(anchor_commit_ack_valid);
                assert(anchor_commit_request);
                assert(checkpoint_commit_event);
                assert(ack_base_anchor_valid == request_base_anchor_valid);
                if (request_base_anchor_valid) begin
                    assert(ack_base_anchor_ref == request_base_anchor_ref);
                    assert(ack_base_anchor_epoch == request_base_anchor_epoch);
                    assert(ack_base_anchor_state_tag == request_base_anchor_state_tag);
                end else begin
                    assert(ack_base_anchor_ref == '0);
                    assert(ack_base_anchor_epoch == '0);
                    assert(ack_base_anchor_state_tag == '0);
                end
                assert(ack_checkpoint_ref == request_checkpoint_ref);
                assert(ack_checkpoint_epoch == request_checkpoint_epoch);
                assert(ack_checkpoint_state_tag == request_checkpoint_state_tag);
            end

            assert(checkpoint_commit_event == anchor_commit_ack_accept);

            if (anchor_commit_ack_valid && !anchor_commit_request)
                assert(!checkpoint_commit_event);

            if (checkpoint_abort) begin
                assert(!anchor_commit_request);
                assert(!checkpoint_commit_event);
            end

            if (prev_prepare_accept) begin
                assert(candidate_pending);
                assert(!snapshot_durable);
                assert(request_checkpoint_ref == prev_candidate_ref);
                assert(request_checkpoint_epoch == prev_candidate_epoch);
                assert(request_checkpoint_state_tag == prev_candidate_state_tag);
            end

            if (prev_snapshot_persist_accept)
                assert(snapshot_durable || stale_base_detected || checkpoint_abort || checkpoint_commit_event);

            if (prev_checkpoint_commit_event)
                assert(!candidate_pending);

            if (prev_stale_base_detected)
                assert(!candidate_pending);

            if (prev_abort)
                assert(!candidate_pending && !snapshot_durable);

            if (prepare_accept && !current_anchor_valid)
                seen_initial_prepare <= 1'b1;
            if (seen_initial_prepare && snapshot_persist_accept)
                seen_initial_durable <= 1'b1;
            if (seen_initial_durable && checkpoint_commit_event)
                seen_initial_commit <= 1'b1;

            if (snapshot_persist_rejected && candidate_pending)
                seen_wrong_persist_reject <= 1'b1;

            if (stale_base_detected)
                seen_stale_base <= 1'b1;

            if (snapshot_durable && checkpoint_abort)
                seen_durable_abort <= 1'b1;

            if (checkpoint_commit_event && request_base_anchor_valid)
                seen_anchored_commit <= 1'b1;

            if (epoch_exhausted && checkpoint_prepare_valid && prepare_rejected)
                seen_epoch_exhausted_reject <= 1'b1;

            cover(seen_initial_prepare && seen_initial_durable && seen_initial_commit);
            cover(seen_wrong_persist_reject);
            cover(seen_stale_base);
            cover(seen_durable_abort);
            cover(seen_anchored_commit);
            cover(seen_epoch_exhausted_reject);

            prev_prepare_accept <= prepare_accept;
            prev_snapshot_persist_accept <= snapshot_persist_accept;
            prev_checkpoint_commit_event <= checkpoint_commit_event;
            prev_stale_base_detected <= stale_base_detected;
            prev_abort <= checkpoint_abort;
            if (prepare_accept) begin
                prev_candidate_ref <= candidate_checkpoint_ref;
                prev_candidate_epoch <= candidate_checkpoint_epoch;
                prev_candidate_state_tag <= candidate_checkpoint_state_tag;
            end
        end
    end
endmodule
