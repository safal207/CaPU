module capu_overlapping_dma_fragment_recovery_v30 #(
  parameter ID_WIDTH = 4
)(
  input  logic clk,
  input  logic rst_n,
  input  logic recovery_begin,

  input  logic submit_valid,
  input  logic [ID_WIDTH-1:0] submit_command_id,
  input  logic [ID_WIDTH-1:0] submit_execution_epoch,
  input  logic [ID_WIDTH-1:0] submit_effect_id,

  input  logic checkpoint_capture_valid,

  input  logic fragment_issue_valid,
  input  logic [1:0] fragment_issue_index,
  input  logic [ID_WIDTH-1:0] fragment_issue_command_id,
  input  logic [ID_WIDTH-1:0] fragment_issue_execution_epoch,
  input  logic [ID_WIDTH-1:0] fragment_issue_effect_id,

  input  logic resolution_valid,
  input  logic resolution_committed,
  input  logic [1:0] resolution_fragment_index,
  input  logic [ID_WIDTH-1:0] resolution_command_id,
  input  logic [ID_WIDTH-1:0] resolution_execution_epoch,
  input  logic [ID_WIDTH-1:0] resolution_effect_id,

  input  logic restore_valid,

  input  logic retire_valid,
  input  logic [ID_WIDTH-1:0] retire_command_id,
  input  logic [ID_WIDTH-1:0] retire_execution_epoch,
  input  logic [ID_WIDTH-1:0] retire_effect_id,

  output logic runtime_ready,
  output logic submit_accept,
  output logic command_pending,
  output logic [ID_WIDTH-1:0] live_command_id,
  output logic [ID_WIDTH-1:0] live_execution_epoch,
  output logic [ID_WIDTH-1:0] live_effect_id,

  output logic checkpoint_capture_accept,
  output logic checkpoint_valid,
  output logic checkpoint_command_pending,
  output logic [ID_WIDTH-1:0] checkpoint_command_id,
  output logic [ID_WIDTH-1:0] checkpoint_execution_epoch,
  output logic [ID_WIDTH-1:0] checkpoint_effect_id,
  output logic [7:0] checkpoint_fragment_states,
  output logic [3:0] checkpoint_owner_valid,
  output logic [7:0] checkpoint_owner_map,

  output logic fragment_issue_accept,
  output logic fragment_issue_rejected,
  output logic resolution_accept,
  output logic resolution_rejected,
  output logic restore_accept,
  output logic restore_rejected,
  output logic retire_accept,
  output logic retire_rejected,

  output logic [7:0] fragment_states,
  output logic [3:0] replay_authority_bitmap,
  output logic [3:0] evidence_required_bitmap,

  output logic [3:0] issue_receipt_bitmap,
  output logic [3:0] negative_receipt_bitmap,
  output logic [3:0] completion_receipt_bitmap,
  output logic [ID_WIDTH-1:0] receipt_command_id,
  output logic [ID_WIDTH-1:0] receipt_execution_epoch,
  output logic [ID_WIDTH-1:0] receipt_effect_id,

  output logic [3:0] durable_owner_valid,
  output logic [7:0] durable_owner_map,
  output logic [3:0] visible_owner_valid,
  output logic [7:0] visible_owner_map,

  output logic all_fragments_committed,
  output logic speculation_kill
);

  localparam logic [1:0] FRAG_UNISSUED      = 2'b00;
  localparam logic [1:0] FRAG_UNKNOWN       = 2'b01;
  localparam logic [1:0] FRAG_COMMITTED     = 2'b10;
  localparam logic [1:0] FRAG_NOT_COMMITTED = 2'b11;

  integer i;
  logic receipt_identity_matches_live;
  logic receipt_identity_matches_checkpoint;

  function automatic logic [3:0] fragment_mask(input logic [1:0] idx);
    begin
      case (idx)
        2'd0: fragment_mask = 4'b0011;
        2'd1: fragment_mask = 4'b0110;
        2'd2: fragment_mask = 4'b1100;
        default: fragment_mask = 4'b1001;
      endcase
    end
  endfunction

  always_comb begin
    replay_authority_bitmap = 4'b0000;
    evidence_required_bitmap = 4'b0000;
    all_fragments_committed = 1'b1;
    for (i = 0; i < 4; i = i + 1) begin
      case (fragment_states[i*2 +: 2])
        FRAG_UNISSUED, FRAG_NOT_COMMITTED:
          replay_authority_bitmap[i] = runtime_ready && command_pending && !recovery_begin && !restore_valid;
        FRAG_UNKNOWN:
          evidence_required_bitmap[i] = runtime_ready && command_pending;
        default: begin end
      endcase
      if (fragment_states[i*2 +: 2] != FRAG_COMMITTED)
        all_fragments_committed = 1'b0;
    end

    receipt_identity_matches_live =
      (receipt_command_id == live_command_id) &&
      (receipt_execution_epoch == live_execution_epoch) &&
      (receipt_effect_id == live_effect_id);

    receipt_identity_matches_checkpoint =
      (receipt_command_id == checkpoint_command_id) &&
      (receipt_execution_epoch == checkpoint_execution_epoch) &&
      (receipt_effect_id == checkpoint_effect_id);

    submit_accept = submit_valid && runtime_ready && !command_pending && !recovery_begin && !restore_valid;

    fragment_issue_accept = fragment_issue_valid && runtime_ready && command_pending && !recovery_begin && !restore_valid &&
      fragment_issue_command_id == live_command_id &&
      fragment_issue_execution_epoch == live_execution_epoch &&
      fragment_issue_effect_id == live_effect_id &&
      ((fragment_states[fragment_issue_index*2 +: 2] == FRAG_UNISSUED) ||
       (fragment_states[fragment_issue_index*2 +: 2] == FRAG_NOT_COMMITTED));
    fragment_issue_rejected = fragment_issue_valid && !fragment_issue_accept;

    resolution_accept = resolution_valid && runtime_ready && command_pending && !recovery_begin && !restore_valid &&
      resolution_command_id == live_command_id &&
      resolution_execution_epoch == live_execution_epoch &&
      resolution_effect_id == live_effect_id &&
      fragment_states[resolution_fragment_index*2 +: 2] == FRAG_UNKNOWN &&
      issue_receipt_bitmap[resolution_fragment_index] && receipt_identity_matches_live;
    resolution_rejected = resolution_valid && !resolution_accept;

    checkpoint_capture_accept = checkpoint_capture_valid && runtime_ready && command_pending && !recovery_begin && !restore_valid;

    restore_accept = restore_valid && !recovery_begin && !runtime_ready && checkpoint_valid && checkpoint_command_pending;
    restore_rejected = restore_valid && !restore_accept;

    retire_accept = retire_valid && !recovery_begin && !restore_valid && runtime_ready && command_pending && all_fragments_committed &&
      completion_receipt_bitmap == 4'b1111 && receipt_identity_matches_live &&
      retire_command_id == live_command_id &&
      retire_execution_epoch == live_execution_epoch &&
      retire_effect_id == live_effect_id;
    retire_rejected = retire_valid && !retire_accept;

    speculation_kill = recovery_begin || restore_valid;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      runtime_ready <= 1'b1;
      command_pending <= 1'b0;
      live_command_id <= '0;
      live_execution_epoch <= '0;
      live_effect_id <= '0;
      fragment_states <= '0;

      checkpoint_valid <= 1'b0;
      checkpoint_command_pending <= 1'b0;
      checkpoint_command_id <= '0;
      checkpoint_execution_epoch <= '0;
      checkpoint_effect_id <= '0;
      checkpoint_fragment_states <= '0;
      checkpoint_owner_valid <= '0;
      checkpoint_owner_map <= '0;

      issue_receipt_bitmap <= '0;
      negative_receipt_bitmap <= '0;
      completion_receipt_bitmap <= '0;
      receipt_command_id <= '0;
      receipt_execution_epoch <= '0;
      receipt_effect_id <= '0;

      durable_owner_valid <= '0;
      durable_owner_map <= '0;
      visible_owner_valid <= '0;
      visible_owner_map <= '0;
    end else if (recovery_begin) begin
      runtime_ready <= 1'b0;
      command_pending <= 1'b0;
      fragment_states <= '0;
      visible_owner_valid <= '0;
      visible_owner_map <= '0;
    end else if (restore_accept) begin
      runtime_ready <= 1'b1;
      command_pending <= checkpoint_command_pending;
      live_command_id <= checkpoint_command_id;
      live_execution_epoch <= checkpoint_execution_epoch;
      live_effect_id <= checkpoint_effect_id;

      for (i = 0; i < 4; i = i + 1) begin
        if (receipt_identity_matches_checkpoint && completion_receipt_bitmap[i])
          fragment_states[i*2 +: 2] <= FRAG_COMMITTED;
        else if (receipt_identity_matches_checkpoint && issue_receipt_bitmap[i])
          fragment_states[i*2 +: 2] <= FRAG_UNKNOWN;
        else if (receipt_identity_matches_checkpoint && negative_receipt_bitmap[i])
          fragment_states[i*2 +: 2] <= FRAG_NOT_COMMITTED;
        else
          fragment_states[i*2 +: 2] <= checkpoint_fragment_states[i*2 +: 2];

        if (durable_owner_valid[i]) begin
          visible_owner_valid[i] <= 1'b1;
          visible_owner_map[i*2 +: 2] <= durable_owner_map[i*2 +: 2];
        end else begin
          visible_owner_valid[i] <= checkpoint_owner_valid[i];
          visible_owner_map[i*2 +: 2] <= checkpoint_owner_map[i*2 +: 2];
        end
      end
    end else begin
      if (submit_accept) begin
        command_pending <= 1'b1;
        live_command_id <= submit_command_id;
        live_execution_epoch <= submit_execution_epoch;
        live_effect_id <= submit_effect_id;
        fragment_states <= '0;
        issue_receipt_bitmap <= '0;
        negative_receipt_bitmap <= '0;
        completion_receipt_bitmap <= '0;
        receipt_command_id <= submit_command_id;
        receipt_execution_epoch <= submit_execution_epoch;
        receipt_effect_id <= submit_effect_id;
        durable_owner_valid <= '0;
        durable_owner_map <= '0;
        visible_owner_valid <= '0;
        visible_owner_map <= '0;
      end

      if (fragment_issue_accept) begin
        fragment_states[fragment_issue_index*2 +: 2] <= FRAG_UNKNOWN;
        issue_receipt_bitmap[fragment_issue_index] <= 1'b1;
        negative_receipt_bitmap[fragment_issue_index] <= 1'b0;
      end

      if (resolution_accept) begin
        issue_receipt_bitmap[resolution_fragment_index] <= 1'b0;
        if (resolution_committed) begin
          fragment_states[resolution_fragment_index*2 +: 2] <= FRAG_COMMITTED;
          completion_receipt_bitmap[resolution_fragment_index] <= 1'b1;
          negative_receipt_bitmap[resolution_fragment_index] <= 1'b0;
          for (i = 0; i < 4; i = i + 1) begin
            if ((fragment_mask(resolution_fragment_index) & (4'b0001 << i)) != 4'b0000) begin
              durable_owner_valid[i] <= 1'b1;
              durable_owner_map[i*2 +: 2] <= resolution_fragment_index;
              visible_owner_valid[i] <= 1'b1;
              visible_owner_map[i*2 +: 2] <= resolution_fragment_index;
            end
          end
        end else begin
          fragment_states[resolution_fragment_index*2 +: 2] <= FRAG_NOT_COMMITTED;
          negative_receipt_bitmap[resolution_fragment_index] <= 1'b1;
        end
      end

      if (checkpoint_capture_accept) begin
        checkpoint_valid <= 1'b1;
        checkpoint_command_pending <= command_pending;
        checkpoint_command_id <= live_command_id;
        checkpoint_execution_epoch <= live_execution_epoch;
        checkpoint_effect_id <= live_effect_id;
        checkpoint_fragment_states <= fragment_states;
        checkpoint_owner_valid <= visible_owner_valid;
        checkpoint_owner_map <= visible_owner_map;
      end

      if (retire_accept)
        command_pending <= 1'b0;
    end
  end
endmodule
