module capu_dma_completion_uncertainty_v27 #(
    parameter int CMD_WIDTH=4,
    parameter int EXEC_EPOCH_WIDTH=4,
    parameter int EFFECT_WIDTH=4
) (
    input logic clk,
    input logic rst_n,
    input logic recovery_begin,

    input logic submit_valid,
    input logic [CMD_WIDTH-1:0] submit_command_id,
    input logic [EXEC_EPOCH_WIDTH-1:0] submit_execution_epoch,
    input logic [EFFECT_WIDTH-1:0] submit_effect_id,

    input logic checkpoint_capture_valid,

    input logic dma_issue_valid,
    input logic [CMD_WIDTH-1:0] dma_issue_command_id,
    input logic [EXEC_EPOCH_WIDTH-1:0] dma_issue_execution_epoch,
    input logic [EFFECT_WIDTH-1:0] dma_issue_effect_id,

    input logic resolution_valid,
    input logic resolution_committed,
    input logic [CMD_WIDTH-1:0] resolution_command_id,
    input logic [EXEC_EPOCH_WIDTH-1:0] resolution_execution_epoch,
    input logic [EFFECT_WIDTH-1:0] resolution_effect_id,

    input logic restore_valid,

    input logic retire_valid,
    input logic [CMD_WIDTH-1:0] retire_command_id,
    input logic [EXEC_EPOCH_WIDTH-1:0] retire_execution_epoch,
    input logic [EFFECT_WIDTH-1:0] retire_effect_id,

    output logic runtime_ready,
    output logic submit_accept,
    output logic submit_rejected,
    output logic command_pending,
    output logic [CMD_WIDTH-1:0] live_command_id,
    output logic [EXEC_EPOCH_WIDTH-1:0] live_execution_epoch,
    output logic [EFFECT_WIDTH-1:0] live_effect_id,

    output logic checkpoint_capture_accept,
    output logic checkpoint_valid,
    output logic checkpoint_command_pending,
    output logic [CMD_WIDTH-1:0] checkpoint_command_id,
    output logic [EXEC_EPOCH_WIDTH-1:0] checkpoint_execution_epoch,
    output logic [EFFECT_WIDTH-1:0] checkpoint_effect_id,
    output logic checkpoint_dma_issued,
    output logic [1:0] checkpoint_completion_state,

    output logic dma_issue_accept,
    output logic dma_issue_rejected,
    output logic dma_issued,
    output logic [1:0] completion_state,
    output logic evidence_required,
    output logic effect_spent,

    output logic issue_receipt_valid,
    output logic [CMD_WIDTH-1:0] issue_receipt_command_id,
    output logic [EXEC_EPOCH_WIDTH-1:0] issue_receipt_execution_epoch,
    output logic [EFFECT_WIDTH-1:0] issue_receipt_effect_id,

    output logic completion_receipt_valid,
    output logic [CMD_WIDTH-1:0] completion_receipt_command_id,
    output logic [EXEC_EPOCH_WIDTH-1:0] completion_receipt_execution_epoch,
    output logic [EFFECT_WIDTH-1:0] completion_receipt_effect_id,

    output logic restore_accept,
    output logic restore_rejected,
    output logic resolution_accept,
    output logic resolution_rejected,
    output logic retire_accept,
    output logic retire_rejected,
    output logic dma_replay_authority,
    output logic speculation_kill
);
    localparam logic [1:0] NOT_COMMITTED = 2'b00;
    localparam logic [1:0] UNKNOWN       = 2'b01;
    localparam logic [1:0] COMMITTED     = 2'b10;

    logic exact_dma_issue, exact_resolution, exact_retire;
    logic matching_issue_receipt_live, matching_issue_receipt_checkpoint;
    logic matching_completion_receipt_live, matching_completion_receipt_checkpoint;

    assign effect_spent = completion_state == COMMITTED;

    assign matching_issue_receipt_live = issue_receipt_valid && command_pending &&
        issue_receipt_command_id == live_command_id &&
        issue_receipt_execution_epoch == live_execution_epoch &&
        issue_receipt_effect_id == live_effect_id;
    assign matching_issue_receipt_checkpoint = issue_receipt_valid && checkpoint_valid && checkpoint_command_pending &&
        issue_receipt_command_id == checkpoint_command_id &&
        issue_receipt_execution_epoch == checkpoint_execution_epoch &&
        issue_receipt_effect_id == checkpoint_effect_id;

    assign matching_completion_receipt_live = completion_receipt_valid && command_pending &&
        completion_receipt_command_id == live_command_id &&
        completion_receipt_execution_epoch == live_execution_epoch &&
        completion_receipt_effect_id == live_effect_id;
    assign matching_completion_receipt_checkpoint = completion_receipt_valid && checkpoint_valid && checkpoint_command_pending &&
        completion_receipt_command_id == checkpoint_command_id &&
        completion_receipt_execution_epoch == checkpoint_execution_epoch &&
        completion_receipt_effect_id == checkpoint_effect_id;

    assign submit_accept = submit_valid && runtime_ready && !command_pending &&
        !checkpoint_valid && !issue_receipt_valid && !completion_receipt_valid &&
        !recovery_begin && !restore_valid;
    assign submit_rejected = submit_valid && !submit_accept;

    assign checkpoint_capture_accept = checkpoint_capture_valid && runtime_ready && command_pending &&
        !recovery_begin && !restore_valid;

    assign exact_dma_issue = command_pending &&
        dma_issue_command_id == live_command_id &&
        dma_issue_execution_epoch == live_execution_epoch &&
        dma_issue_effect_id == live_effect_id;
    assign dma_replay_authority = runtime_ready && command_pending &&
        completion_state == NOT_COMMITTED && !dma_issued && !evidence_required &&
        !matching_issue_receipt_live && !matching_completion_receipt_live &&
        !recovery_begin && !restore_valid;
    assign dma_issue_accept = dma_issue_valid && exact_dma_issue && dma_replay_authority;
    assign dma_issue_rejected = dma_issue_valid && !dma_issue_accept;

    assign exact_resolution = command_pending &&
        resolution_command_id == live_command_id &&
        resolution_execution_epoch == live_execution_epoch &&
        resolution_effect_id == live_effect_id && matching_issue_receipt_live;
    assign resolution_accept = resolution_valid && runtime_ready && evidence_required &&
        completion_state == UNKNOWN && exact_resolution && !recovery_begin && !restore_valid;
    assign resolution_rejected = resolution_valid && !resolution_accept;

    assign restore_accept = restore_valid && !runtime_ready && checkpoint_valid &&
        checkpoint_command_pending && !recovery_begin;
    assign restore_rejected = restore_valid && !restore_accept;

    assign exact_retire = command_pending &&
        retire_command_id == live_command_id &&
        retire_execution_epoch == live_execution_epoch &&
        retire_effect_id == live_effect_id;
    assign retire_accept = retire_valid && runtime_ready && exact_retire &&
        completion_state == COMMITTED && matching_completion_receipt_live &&
        !evidence_required && !recovery_begin && !restore_valid;
    assign retire_rejected = retire_valid && !retire_accept;

    assign speculation_kill = recovery_begin || restore_valid || evidence_required ||
        resolution_valid || dma_issue_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            runtime_ready <= 1'b1;
            command_pending <= 1'b0;
            live_command_id <= '0;
            live_execution_epoch <= '0;
            live_effect_id <= '0;
            checkpoint_valid <= 1'b0;
            checkpoint_command_pending <= 1'b0;
            checkpoint_command_id <= '0;
            checkpoint_execution_epoch <= '0;
            checkpoint_effect_id <= '0;
            checkpoint_dma_issued <= 1'b0;
            checkpoint_completion_state <= NOT_COMMITTED;
            dma_issued <= 1'b0;
            completion_state <= NOT_COMMITTED;
            evidence_required <= 1'b0;
            issue_receipt_valid <= 1'b0;
            issue_receipt_command_id <= '0;
            issue_receipt_execution_epoch <= '0;
            issue_receipt_effect_id <= '0;
            completion_receipt_valid <= 1'b0;
            completion_receipt_command_id <= '0;
            completion_receipt_execution_epoch <= '0;
            completion_receipt_effect_id <= '0;
        end else if(recovery_begin) begin
            runtime_ready <= 1'b0;
            command_pending <= 1'b0;
            live_command_id <= '0;
            live_execution_epoch <= '0;
            live_effect_id <= '0;
            dma_issued <= 1'b0;
            completion_state <= NOT_COMMITTED;
            evidence_required <= 1'b0;
        end else if(restore_accept) begin
            runtime_ready <= 1'b1;
            command_pending <= checkpoint_command_pending;
            live_command_id <= checkpoint_command_id;
            live_execution_epoch <= checkpoint_execution_epoch;
            live_effect_id <= checkpoint_effect_id;
            if(matching_completion_receipt_checkpoint) begin
                dma_issued <= 1'b0;
                completion_state <= COMMITTED;
                evidence_required <= 1'b0;
            end else if(matching_issue_receipt_checkpoint || checkpoint_completion_state == UNKNOWN) begin
                dma_issued <= 1'b1;
                completion_state <= UNKNOWN;
                evidence_required <= 1'b1;
            end else begin
                dma_issued <= checkpoint_dma_issued;
                completion_state <= checkpoint_completion_state;
                evidence_required <= 1'b0;
            end
        end else begin
            if(submit_accept) begin
                command_pending <= 1'b1;
                live_command_id <= submit_command_id;
                live_execution_epoch <= submit_execution_epoch;
                live_effect_id <= submit_effect_id;
                dma_issued <= 1'b0;
                completion_state <= NOT_COMMITTED;
                evidence_required <= 1'b0;
            end

            if(checkpoint_capture_accept) begin
                checkpoint_valid <= 1'b1;
                checkpoint_command_pending <= command_pending;
                checkpoint_command_id <= live_command_id;
                checkpoint_execution_epoch <= live_execution_epoch;
                checkpoint_effect_id <= live_effect_id;
                checkpoint_dma_issued <= dma_issued;
                checkpoint_completion_state <= completion_state;
            end

            if(dma_issue_accept) begin
                dma_issued <= 1'b1;
                completion_state <= UNKNOWN;
                evidence_required <= 1'b1;
                issue_receipt_valid <= 1'b1;
                issue_receipt_command_id <= live_command_id;
                issue_receipt_execution_epoch <= live_execution_epoch;
                issue_receipt_effect_id <= live_effect_id;
            end

            if(resolution_accept) begin
                dma_issued <= 1'b0;
                evidence_required <= 1'b0;
                issue_receipt_valid <= 1'b0;
                if(resolution_committed) begin
                    completion_state <= COMMITTED;
                    completion_receipt_valid <= 1'b1;
                    completion_receipt_command_id <= live_command_id;
                    completion_receipt_execution_epoch <= live_execution_epoch;
                    completion_receipt_effect_id <= live_effect_id;
                end else begin
                    completion_state <= NOT_COMMITTED;
                end
            end

            if(retire_accept) begin
                command_pending <= 1'b0;
                dma_issued <= 1'b0;
                evidence_required <= 1'b0;
            end
        end
    end
endmodule
