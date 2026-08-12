module capu_arch_checkpoint_binding_v17_formal;
    localparam int REF_W = 3;
    localparam int EPOCH_W = 3;
    localparam int COMMIT_W = 4;
    localparam int ARCH_EPOCH_W = 2;
    localparam int PC_W = 3;
    localparam int DATA_W = 3;
    localparam int TID_W = 3;
    localparam int AUTH_W = 3;
    localparam int SLOTS = 2;
    localparam int PAYLOAD_W = ARCH_EPOCH_W + PC_W + (4*DATA_W) + 8
        + 1 + TID_W + 4 + 1 + SLOTS + (SLOTS*AUTH_W);

    (* gclk *) reg clk;
    reg rst_n = 1'b0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg recovery_begin;
    (* anyseq *) reg restore_valid;
    (* anyseq *) reg [REF_W-1:0] snapshot_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] snapshot_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] snapshot_checkpoint_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] snapshot_checkpoint_payload;
    (* anyseq *) reg snapshot_commitment_verified;
    (* anyseq *) reg current_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] current_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] current_anchor_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] current_anchor_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] current_anchor_payload;
    (* anyseq *) reg checkpoint_prepare_valid;
    (* anyseq *) reg [REF_W-1:0] candidate_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] candidate_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] candidate_checkpoint_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] candidate_checkpoint_payload;
    (* anyseq *) reg candidate_commitment_verified;
    (* anyseq *) reg [PAYLOAD_W-1:0] committed_checkpoint_payload;
    (* anyseq *) reg checkpoint_abort;
    (* anyseq *) reg snapshot_persisted_valid;
    (* anyseq *) reg [REF_W-1:0] persisted_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] persisted_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] persisted_checkpoint_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] persisted_checkpoint_payload;
    (* anyseq *) reg anchor_commit_ack_valid;
    (* anyseq *) reg ack_base_anchor_valid;
    (* anyseq *) reg [REF_W-1:0] ack_base_anchor_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_base_anchor_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] ack_base_anchor_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] ack_base_anchor_payload;
    (* anyseq *) reg [REF_W-1:0] ack_checkpoint_ref;
    (* anyseq *) reg [EPOCH_W-1:0] ack_checkpoint_epoch;
    (* anyseq *) reg [COMMIT_W-1:0] ack_checkpoint_commitment;
    (* anyseq *) reg [PAYLOAD_W-1:0] ack_checkpoint_payload;

    wire checkpoint_prepare_accept;
    wire checkpoint_prepare_rejected;
    wire checkpoint_candidate_pending;
    wire candidate_payload_rejected;
    wire checkpoint_snapshot_persist_accept;
    wire checkpoint_snapshot_persist_rejected;
    wire checkpoint_snapshot_durable;
    wire checkpoint_anchor_commit_request;
    wire checkpoint_anchor_commit_ack_accept;
    wire checkpoint_anchor_commit_ack_rejected;
    wire checkpoint_commit_event;
    wire checkpoint_restore_accept;
    wire checkpoint_restore_rejected;
    wire checkpoint_restore_mismatch;
    wire recovered_checkpoint_ready;
    wire [PAYLOAD_W-1:0] recovered_checkpoint_payload;
    wire checkpoint_request_base_anchor_valid;
    wire [REF_W-1:0] checkpoint_request_base_anchor_ref;
    wire [EPOCH_W-1:0] checkpoint_request_base_anchor_epoch;
    wire [COMMIT_W-1:0] checkpoint_request_base_anchor_commitment;
    wire [PAYLOAD_W-1:0] checkpoint_request_base_anchor_payload;
    wire [REF_W-1:0] checkpoint_request_ref;
    wire [EPOCH_W-1:0] checkpoint_request_epoch;
    wire [COMMIT_W-1:0] checkpoint_request_commitment;
    wire [PAYLOAD_W-1:0] checkpoint_request_payload;

    capu_arch_checkpoint_binding_v17 #(
        .CHECKPOINT_REF_WIDTH(REF_W),
        .CHECKPOINT_EPOCH_WIDTH(EPOCH_W),
        .CHECKPOINT_COMMITMENT_WIDTH(COMMIT_W),
        .ARCH_EPOCH_WIDTH(ARCH_EPOCH_W),
        .PC_WIDTH(PC_W),
        .DATA_WIDTH(DATA_W),
        .TRANSITION_ID_WIDTH(TID_W),
        .AUTHORIZATION_REF_WIDTH(AUTH_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS),
        .CHECKPOINT_PAYLOAD_WIDTH(PAYLOAD_W)
    ) dut (.*);

    reg expect_restore = 1'b0;
    reg [PAYLOAD_W-1:0] expected_payload = '0;
    reg seen_prepare_payload_reject = 1'b0;
    reg seen_persist_payload_reject = 1'b0;
    reg seen_ack_payload_reject = 1'b0;
    reg seen_commit = 1'b0;
    reg seen_restore_mismatch = 1'b0;
    reg seen_restore_exact = 1'b0;
    reg seen_recovered_exact = 1'b0;
    reg expect_prepare_latched = 1'b0;
    reg [PAYLOAD_W-1:0] expected_prepared_payload = '0;
    reg expect_persist_durable = 1'b0;
    reg expect_commit_cleared = 1'b0;
    reg expect_boundary_cleared = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            expect_restore <= 1'b0;
            seen_prepare_payload_reject <= 1'b0;
            seen_persist_payload_reject <= 1'b0;
            seen_ack_payload_reject <= 1'b0;
            seen_commit <= 1'b0;
            seen_restore_mismatch <= 1'b0;
            seen_restore_exact <= 1'b0;
            seen_recovered_exact <= 1'b0;
            expect_prepare_latched <= 1'b0;
            expect_persist_durable <= 1'b0;
            expect_commit_cleared <= 1'b0;
            expect_boundary_cleared <= 1'b0;
        end else begin
            if (expect_prepare_latched) begin
                assert(checkpoint_candidate_pending);
                assert(checkpoint_request_payload == expected_prepared_payload);
                expect_prepare_latched <= 1'b0;
            end
            if (expect_persist_durable) begin
                assert(checkpoint_candidate_pending);
                assert(checkpoint_snapshot_durable);
                expect_persist_durable <= 1'b0;
            end
            if (expect_commit_cleared) begin
                assert(!checkpoint_candidate_pending);
                assert(!checkpoint_snapshot_durable);
                expect_commit_cleared <= 1'b0;
            end
            if (expect_boundary_cleared) begin
                assert(!checkpoint_candidate_pending);
                assert(!checkpoint_snapshot_durable);
                expect_boundary_cleared <= 1'b0;
            end

            if (expect_restore) begin
                assert(recovered_checkpoint_ready);
                assert(recovered_checkpoint_payload == expected_payload);
                seen_recovered_exact <= 1'b1;
                expect_restore <= 1'b0;
            end

            if (checkpoint_prepare_accept) begin
                assert(candidate_commitment_verified);
                assert(candidate_checkpoint_payload == committed_checkpoint_payload);
                assert(candidate_checkpoint_commitment != '0);
                assert(!checkpoint_abort);
                assert(!restore_valid);
                expect_prepare_latched <= 1'b1;
                expected_prepared_payload <= candidate_checkpoint_payload;
            end
            if (checkpoint_prepare_valid && candidate_payload_rejected) begin
                assert(checkpoint_prepare_rejected);
                assert(!checkpoint_prepare_accept);
                seen_prepare_payload_reject <= 1'b1;
            end

            if (checkpoint_snapshot_persist_accept) begin
                assert(persisted_checkpoint_payload == checkpoint_request_payload);
                assert(persisted_checkpoint_commitment == checkpoint_request_commitment);
                assert(!checkpoint_abort);
                assert(!checkpoint_commit_event);
                assert(!restore_valid);
                expect_persist_durable <= 1'b1;
            end
            if (snapshot_persisted_valid
                && persisted_checkpoint_payload != checkpoint_request_payload) begin
                assert(!checkpoint_snapshot_persist_accept);
                assert(checkpoint_snapshot_persist_rejected);
                seen_persist_payload_reject <= 1'b1;
            end

            if (checkpoint_commit_event) begin
                assert(checkpoint_anchor_commit_ack_accept);
                assert(ack_checkpoint_payload == checkpoint_request_payload);
                assert(ack_checkpoint_commitment == checkpoint_request_commitment);
                if (checkpoint_request_base_anchor_valid)
                    assert(ack_base_anchor_payload == checkpoint_request_base_anchor_payload);
                seen_commit <= 1'b1;
                expect_commit_cleared <= 1'b1;
            end
            if (anchor_commit_ack_valid && checkpoint_candidate_pending
                && ack_checkpoint_payload != checkpoint_request_payload) begin
                assert(!checkpoint_commit_event);
                assert(checkpoint_anchor_commit_ack_rejected);
                seen_ack_payload_reject <= 1'b1;
            end

            if (checkpoint_restore_accept) begin
                assert(restore_valid);
                assert(!recovery_begin);
                assert(current_anchor_valid);
                assert(snapshot_commitment_verified);
                assert(snapshot_checkpoint_ref == current_anchor_ref);
                assert(snapshot_checkpoint_epoch == current_anchor_epoch);
                assert(snapshot_checkpoint_commitment == current_anchor_commitment);
                assert(snapshot_checkpoint_payload == current_anchor_payload);
                expected_payload <= snapshot_checkpoint_payload;
                expect_restore <= 1'b1;
                seen_restore_exact <= 1'b1;
            end
            if (checkpoint_restore_mismatch) begin
                assert(!checkpoint_restore_accept);
                assert(checkpoint_restore_rejected);
                seen_restore_mismatch <= 1'b1;
            end
            if (recovery_begin) begin
                assert(!checkpoint_restore_accept);
                assert(!checkpoint_prepare_accept);
                assert(!checkpoint_snapshot_persist_accept);
                assert(!checkpoint_commit_event);
                expect_restore <= 1'b0;
                expect_prepare_latched <= 1'b0;
                expect_persist_durable <= 1'b0;
                expect_boundary_cleared <= 1'b1;
            end
            if (restore_valid) begin
                assert(!checkpoint_prepare_accept);
                assert(!checkpoint_snapshot_persist_accept);
                assert(!checkpoint_commit_event);
                expect_prepare_latched <= 1'b0;
                expect_persist_durable <= 1'b0;
                expect_boundary_cleared <= 1'b1;
            end
            if (checkpoint_abort) begin
                assert(!checkpoint_prepare_accept);
                assert(!checkpoint_snapshot_persist_accept);
                assert(!checkpoint_commit_event);
                expect_prepare_latched <= 1'b0;
                expect_persist_durable <= 1'b0;
            end

            cover(seen_prepare_payload_reject);
            cover(seen_persist_payload_reject);
            cover(seen_ack_payload_reject);
            cover(seen_commit);
            cover(seen_restore_mismatch);
            cover(seen_restore_exact);
            cover(seen_recovered_exact);
        end
    end
endmodule
