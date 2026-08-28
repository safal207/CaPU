module capu_accelerator_dma_recovery_v26 #(
    parameter int CMD_WIDTH=4,
    parameter int EXEC_EPOCH_WIDTH=4,
    parameter int EFFECT_WIDTH=4
) (
    input  logic clk,
    input  logic rst_n,
    input  logic recovery_begin,

    input  logic submit_valid,
    input  logic [CMD_WIDTH-1:0] submit_command_id,
    input  logic [EXEC_EPOCH_WIDTH-1:0] submit_execution_epoch,
    input  logic [EFFECT_WIDTH-1:0] submit_effect_id,

    input  logic checkpoint_capture_valid,

    input  logic dma_issue_valid,
    input  logic [CMD_WIDTH-1:0] dma_issue_command_id,
    input  logic [EXEC_EPOCH_WIDTH-1:0] dma_issue_execution_epoch,
    input  logic [EFFECT_WIDTH-1:0] dma_issue_effect_id,

    input  logic dma_commit_valid,
    input  logic [CMD_WIDTH-1:0] dma_commit_command_id,
    input  logic [EXEC_EPOCH_WIDTH-1:0] dma_commit_execution_epoch,
    input  logic [EFFECT_WIDTH-1:0] dma_commit_effect_id,

    input  logic restore_valid,

    input  logic reconcile_valid,
    input  logic [CMD_WIDTH-1:0] reconcile_command_id,
    input  logic [EXEC_EPOCH_WIDTH-1:0] reconcile_execution_epoch,
    input  logic [EFFECT_WIDTH-1:0] reconcile_effect_id,

    input  logic retire_valid,
    input  logic [CMD_WIDTH-1:0] retire_command_id,
    input  logic [EXEC_EPOCH_WIDTH-1:0] retire_execution_epoch,
    input  logic [EFFECT_WIDTH-1:0] retire_effect_id,

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
    output logic checkpoint_effect_spent,

    output logic dma_issue_accept,
    output logic dma_issue_rejected,
    output logic dma_issued,
    output logic dma_commit_accept,
    output logic dma_commit_rejected,
    output logic effect_spent,

    output logic receipt_valid,
    output logic [CMD_WIDTH-1:0] receipt_command_id,
    output logic [EXEC_EPOCH_WIDTH-1:0] receipt_execution_epoch,
    output logic [EFFECT_WIDTH-1:0] receipt_effect_id,

    output logic restore_accept,
    output logic restore_rejected,
    output logic reconcile_required,
    output logic reconcile_accept,
    output logic reconcile_rejected,
    output logic retire_accept,
    output logic retire_rejected,
    output logic dma_replay_authority,
    output logic speculation_kill
);
    logic exact_dma_issue;
    logic exact_dma_commit;
    logic exact_reconcile;
    logic exact_retire;
    logic matching_receipt_live;
    logic checkpoint_receipt_conflict;

    assign matching_receipt_live = receipt_valid && command_pending &&
        receipt_command_id == live_command_id &&
        receipt_execution_epoch == live_execution_epoch &&
        receipt_effect_id == live_effect_id;

    assign checkpoint_receipt_conflict = checkpoint_valid && checkpoint_command_pending &&
        receipt_valid && !checkpoint_effect_spent &&
        receipt_command_id == checkpoint_command_id &&
        receipt_execution_epoch == checkpoint_execution_epoch &&
        receipt_effect_id == checkpoint_effect_id;

    assign submit_accept = submit_valid && runtime_ready && !command_pending &&
        !checkpoint_valid && !receipt_valid && !recovery_begin && !restore_valid;
    assign submit_rejected = submit_valid && !submit_accept;

    assign checkpoint_capture_accept = checkpoint_capture_valid && runtime_ready &&
        command_pending && !recovery_begin && !restore_valid;

    assign exact_dma_issue = command_pending &&
        dma_issue_command_id == live_command_id &&
        dma_issue_execution_epoch == live_execution_epoch &&
        dma_issue_effect_id == live_effect_id;
    assign dma_replay_authority = runtime_ready && command_pending && !dma_issued &&
        !effect_spent && !matching_receipt_live && !reconcile_required &&
        !recovery_begin && !restore_valid;
    assign dma_issue_accept = dma_issue_valid && exact_dma_issue && dma_replay_authority;
    assign dma_issue_rejected = dma_issue_valid && !dma_issue_accept;

    assign exact_dma_commit = command_pending &&
        dma_commit_command_id == live_command_id &&
        dma_commit_execution_epoch == live_execution_epoch &&
        dma_commit_effect_id == live_effect_id;
    assign dma_commit_accept = dma_commit_valid && runtime_ready && exact_dma_commit &&
        dma_issued && !effect_spent && !receipt_valid && !reconcile_required &&
        !recovery_begin && !restore_valid;
    assign dma_commit_rejected = dma_commit_valid && !dma_commit_accept;

    assign restore_accept = restore_valid && !runtime_ready && checkpoint_valid &&
        checkpoint_command_pending && !recovery_begin;
    assign restore_rejected = restore_valid && !restore_accept;

    assign exact_reconcile = command_pending &&
        reconcile_command_id == live_command_id &&
        reconcile_execution_epoch == live_execution_epoch &&
        reconcile_effect_id == live_effect_id && matching_receipt_live;
    assign reconcile_accept = reconcile_valid && runtime_ready && reconcile_required &&
        exact_reconcile && !recovery_begin && !restore_valid;
    assign reconcile_rejected = reconcile_valid && !reconcile_accept;

    assign exact_retire = command_pending &&
        retire_command_id == live_command_id &&
        retire_execution_epoch == live_execution_epoch &&
        retire_effect_id == live_effect_id;
    assign retire_accept = retire_valid && runtime_ready && exact_retire && effect_spent &&
        !reconcile_required && !recovery_begin && !restore_valid;
    assign retire_rejected = retire_valid && !retire_accept;

    assign speculation_kill = recovery_begin || restore_valid || reconcile_required ||
        dma_commit_valid || reconcile_valid;

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
            checkpoint_effect_spent <= 1'b0;
            dma_issued <= 1'b0;
            effect_spent <= 1'b0;
            receipt_valid <= 1'b0;
            receipt_command_id <= '0;
            receipt_execution_epoch <= '0;
            receipt_effect_id <= '0;
            reconcile_required <= 1'b0;
        end else if(recovery_begin) begin
            runtime_ready <= 1'b0;
            command_pending <= 1'b0;
            live_command_id <= '0;
            live_execution_epoch <= '0;
            live_effect_id <= '0;
            dma_issued <= 1'b0;
            effect_spent <= 1'b0;
            reconcile_required <= 1'b0;
        end else if(restore_accept) begin
            runtime_ready <= 1'b1;
            command_pending <= checkpoint_command_pending;
            live_command_id <= checkpoint_command_id;
            live_execution_epoch <= checkpoint_execution_epoch;
            live_effect_id <= checkpoint_effect_id;
            dma_issued <= checkpoint_dma_issued;
            effect_spent <= checkpoint_effect_spent;
            reconcile_required <= checkpoint_receipt_conflict;
        end else begin
            if(submit_accept) begin
                command_pending <= 1'b1;
                live_command_id <= submit_command_id;
                live_execution_epoch <= submit_execution_epoch;
                live_effect_id <= submit_effect_id;
                dma_issued <= 1'b0;
                effect_spent <= 1'b0;
                reconcile_required <= 1'b0;
            end

            if(checkpoint_capture_accept) begin
                checkpoint_valid <= 1'b1;
                checkpoint_command_pending <= command_pending;
                checkpoint_command_id <= live_command_id;
                checkpoint_execution_epoch <= live_execution_epoch;
                checkpoint_effect_id <= live_effect_id;
                checkpoint_dma_issued <= dma_issued;
                checkpoint_effect_spent <= effect_spent;
            end

            if(dma_issue_accept)
                dma_issued <= 1'b1;

            if(dma_commit_accept) begin
                effect_spent <= 1'b1;
                receipt_valid <= 1'b1;
                receipt_command_id <= live_command_id;
                receipt_execution_epoch <= live_execution_epoch;
                receipt_effect_id <= live_effect_id;
            end

            if(reconcile_accept) begin
                effect_spent <= 1'b1;
                dma_issued <= 1'b0;
                reconcile_required <= 1'b0;
            end

            if(retire_accept) begin
                command_pending <= 1'b0;
                dma_issued <= 1'b0;
                reconcile_required <= 1'b0;
            end
        end
    end
endmodule
