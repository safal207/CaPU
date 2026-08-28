module capu_multibeat_dma_recovery_v29 #(
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

    input logic beat_issue_valid,
    input logic [1:0] beat_issue_index,
    input logic [CMD_WIDTH-1:0] beat_issue_command_id,
    input logic [EXEC_EPOCH_WIDTH-1:0] beat_issue_execution_epoch,
    input logic [EFFECT_WIDTH-1:0] beat_issue_effect_id,

    input logic resolution_valid,
    input logic resolution_committed,
    input logic [1:0] resolution_beat_index,
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
    output logic [7:0] checkpoint_beat_states,

    output logic beat_issue_accept,
    output logic beat_issue_rejected,
    output logic resolution_accept,
    output logic resolution_rejected,
    output logic restore_accept,
    output logic restore_rejected,
    output logic retire_accept,
    output logic retire_rejected,

    output logic [7:0] beat_states,
    output logic [3:0] evidence_required_bitmap,
    output logic [3:0] beat_replay_authority,
    output logic [3:0] issue_receipt_bitmap,
    output logic [3:0] negative_receipt_bitmap,
    output logic [3:0] completion_receipt_bitmap,
    output logic [CMD_WIDTH-1:0] receipt_command_id,
    output logic [EXEC_EPOCH_WIDTH-1:0] receipt_execution_epoch,
    output logic [EFFECT_WIDTH-1:0] receipt_effect_id,
    output logic all_beats_committed,
    output logic speculation_kill
);
    localparam logic [1:0] UNISSUED      = 2'b00;
    localparam logic [1:0] UNKNOWN       = 2'b01;
    localparam logic [1:0] COMMITTED     = 2'b10;
    localparam logic [1:0] NOT_COMMITTED = 2'b11;

    logic exact_beat_issue, exact_resolution, exact_retire;
    logic receipt_identity_matches_live, receipt_identity_matches_checkpoint;
    logic receipt_any;

    function automatic logic [1:0] beat_state(input logic [7:0] states, input logic [1:0] idx);
        case(idx)
            2'd0: beat_state = states[1:0];
            2'd1: beat_state = states[3:2];
            2'd2: beat_state = states[5:4];
            default: beat_state = states[7:6];
        endcase
    endfunction

    assign receipt_any = |issue_receipt_bitmap || |negative_receipt_bitmap || |completion_receipt_bitmap;
    assign receipt_identity_matches_live = receipt_any && command_pending &&
        receipt_command_id == live_command_id &&
        receipt_execution_epoch == live_execution_epoch &&
        receipt_effect_id == live_effect_id;
    assign receipt_identity_matches_checkpoint = receipt_any && checkpoint_valid && checkpoint_command_pending &&
        receipt_command_id == checkpoint_command_id &&
        receipt_execution_epoch == checkpoint_execution_epoch &&
        receipt_effect_id == checkpoint_effect_id;

    assign evidence_required_bitmap[0] = beat_states[1:0] == UNKNOWN;
    assign evidence_required_bitmap[1] = beat_states[3:2] == UNKNOWN;
    assign evidence_required_bitmap[2] = beat_states[5:4] == UNKNOWN;
    assign evidence_required_bitmap[3] = beat_states[7:6] == UNKNOWN;

    assign all_beats_committed = beat_states[1:0] == COMMITTED &&
        beat_states[3:2] == COMMITTED && beat_states[5:4] == COMMITTED &&
        beat_states[7:6] == COMMITTED;

    assign submit_accept = submit_valid && runtime_ready && !command_pending &&
        !checkpoint_valid && !receipt_any && !recovery_begin && !restore_valid;
    assign submit_rejected = submit_valid && !submit_accept;

    assign checkpoint_capture_accept = checkpoint_capture_valid && runtime_ready && command_pending &&
        !recovery_begin && !restore_valid;

    assign beat_replay_authority[0] = runtime_ready && command_pending &&
        (beat_states[1:0] == UNISSUED || beat_states[1:0] == NOT_COMMITTED) &&
        !issue_receipt_bitmap[0] && !completion_receipt_bitmap[0] &&
        (!negative_receipt_bitmap[0] || beat_states[1:0] == NOT_COMMITTED) &&
        (!receipt_any || receipt_identity_matches_live) && !recovery_begin && !restore_valid;
    assign beat_replay_authority[1] = runtime_ready && command_pending && beat_states[1:0] == COMMITTED &&
        (beat_states[3:2] == UNISSUED || beat_states[3:2] == NOT_COMMITTED) &&
        !issue_receipt_bitmap[1] && !completion_receipt_bitmap[1] &&
        (!negative_receipt_bitmap[1] || beat_states[3:2] == NOT_COMMITTED) &&
        (!receipt_any || receipt_identity_matches_live) && !recovery_begin && !restore_valid;
    assign beat_replay_authority[2] = runtime_ready && command_pending &&
        beat_states[1:0] == COMMITTED && beat_states[3:2] == COMMITTED &&
        (beat_states[5:4] == UNISSUED || beat_states[5:4] == NOT_COMMITTED) &&
        !issue_receipt_bitmap[2] && !completion_receipt_bitmap[2] &&
        (!negative_receipt_bitmap[2] || beat_states[5:4] == NOT_COMMITTED) &&
        (!receipt_any || receipt_identity_matches_live) && !recovery_begin && !restore_valid;
    assign beat_replay_authority[3] = runtime_ready && command_pending &&
        beat_states[1:0] == COMMITTED && beat_states[3:2] == COMMITTED && beat_states[5:4] == COMMITTED &&
        (beat_states[7:6] == UNISSUED || beat_states[7:6] == NOT_COMMITTED) &&
        !issue_receipt_bitmap[3] && !completion_receipt_bitmap[3] &&
        (!negative_receipt_bitmap[3] || beat_states[7:6] == NOT_COMMITTED) &&
        (!receipt_any || receipt_identity_matches_live) && !recovery_begin && !restore_valid;

    assign exact_beat_issue = command_pending &&
        beat_issue_command_id == live_command_id &&
        beat_issue_execution_epoch == live_execution_epoch &&
        beat_issue_effect_id == live_effect_id;
    assign beat_issue_accept = beat_issue_valid && exact_beat_issue && beat_replay_authority[beat_issue_index];
    assign beat_issue_rejected = beat_issue_valid && !beat_issue_accept;

    assign exact_resolution = command_pending &&
        resolution_command_id == live_command_id &&
        resolution_execution_epoch == live_execution_epoch &&
        resolution_effect_id == live_effect_id &&
        receipt_identity_matches_live;
    assign resolution_accept = resolution_valid && runtime_ready && exact_resolution &&
        beat_state(beat_states,resolution_beat_index) == UNKNOWN &&
        issue_receipt_bitmap[resolution_beat_index] && !recovery_begin && !restore_valid;
    assign resolution_rejected = resolution_valid && !resolution_accept;

    assign restore_accept = restore_valid && !runtime_ready && checkpoint_valid &&
        checkpoint_command_pending && !recovery_begin;
    assign restore_rejected = restore_valid && !restore_accept;

    assign exact_retire = command_pending &&
        retire_command_id == live_command_id &&
        retire_execution_epoch == live_execution_epoch &&
        retire_effect_id == live_effect_id;
    assign retire_accept = retire_valid && runtime_ready && exact_retire &&
        all_beats_committed && completion_receipt_bitmap == 4'b1111 &&
        receipt_identity_matches_live && !recovery_begin && !restore_valid;
    assign retire_rejected = retire_valid && !retire_accept;

    assign speculation_kill = recovery_begin || restore_valid || (|evidence_required_bitmap) ||
        resolution_valid || beat_issue_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        integer i;
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
            checkpoint_beat_states <= {4{UNISSUED}};
            beat_states <= {4{UNISSUED}};
            issue_receipt_bitmap <= 4'b0000;
            negative_receipt_bitmap <= 4'b0000;
            completion_receipt_bitmap <= 4'b0000;
            receipt_command_id <= '0;
            receipt_execution_epoch <= '0;
            receipt_effect_id <= '0;
        end else if(recovery_begin) begin
            runtime_ready <= 1'b0;
            command_pending <= 1'b0;
            live_command_id <= '0;
            live_execution_epoch <= '0;
            live_effect_id <= '0;
            beat_states <= {4{UNISSUED}};
        end else if(restore_accept) begin
            runtime_ready <= 1'b1;
            command_pending <= checkpoint_command_pending;
            live_command_id <= checkpoint_command_id;
            live_execution_epoch <= checkpoint_execution_epoch;
            live_effect_id <= checkpoint_effect_id;
            for(i=0;i<4;i=i+1) begin
                if(receipt_identity_matches_checkpoint && completion_receipt_bitmap[i])
                    beat_states[i*2 +: 2] <= COMMITTED;
                else if(receipt_identity_matches_checkpoint && issue_receipt_bitmap[i])
                    beat_states[i*2 +: 2] <= UNKNOWN;
                else if(receipt_identity_matches_checkpoint && negative_receipt_bitmap[i])
                    beat_states[i*2 +: 2] <= NOT_COMMITTED;
                else
                    beat_states[i*2 +: 2] <= checkpoint_beat_states[i*2 +: 2];
            end
        end else begin
            if(submit_accept) begin
                command_pending <= 1'b1;
                live_command_id <= submit_command_id;
                live_execution_epoch <= submit_execution_epoch;
                live_effect_id <= submit_effect_id;
                beat_states <= {4{UNISSUED}};
            end

            if(checkpoint_capture_accept) begin
                checkpoint_valid <= 1'b1;
                checkpoint_command_pending <= command_pending;
                checkpoint_command_id <= live_command_id;
                checkpoint_execution_epoch <= live_execution_epoch;
                checkpoint_effect_id <= live_effect_id;
                checkpoint_beat_states <= beat_states;
            end

            if(beat_issue_accept) begin
                beat_states[beat_issue_index*2 +: 2] <= UNKNOWN;
                issue_receipt_bitmap[beat_issue_index] <= 1'b1;
                negative_receipt_bitmap[beat_issue_index] <= 1'b0;
                if(!receipt_any) begin
                    receipt_command_id <= live_command_id;
                    receipt_execution_epoch <= live_execution_epoch;
                    receipt_effect_id <= live_effect_id;
                end
            end

            if(resolution_accept) begin
                issue_receipt_bitmap[resolution_beat_index] <= 1'b0;
                if(resolution_committed) begin
                    beat_states[resolution_beat_index*2 +: 2] <= COMMITTED;
                    negative_receipt_bitmap[resolution_beat_index] <= 1'b0;
                    completion_receipt_bitmap[resolution_beat_index] <= 1'b1;
                end else begin
                    beat_states[resolution_beat_index*2 +: 2] <= NOT_COMMITTED;
                    negative_receipt_bitmap[resolution_beat_index] <= 1'b1;
                end
            end

            if(retire_accept)
                command_pending <= 1'b0;
        end
    end
endmodule
