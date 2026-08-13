module capu_concurrent_dma_queue_recovery_v31 #(
  parameter ID_WIDTH = 4
)(
  input  logic clk,
  input  logic rst_n,
  input  logic recovery_begin,

  input  logic submit_valid,
  input  logic submit_tx_index,
  input  logic [ID_WIDTH-1:0] submit_command_id,
  input  logic [ID_WIDTH-1:0] submit_execution_epoch,
  input  logic [ID_WIDTH-1:0] submit_effect_id,
  input  logic [ID_WIDTH-1:0] submit_queue_epoch,

  input  logic checkpoint_capture_valid,

  input  logic fragment_issue_valid,
  input  logic fragment_issue_tx_index,
  input  logic fragment_issue_index,
  input  logic [ID_WIDTH-1:0] fragment_issue_command_id,
  input  logic [ID_WIDTH-1:0] fragment_issue_execution_epoch,
  input  logic [ID_WIDTH-1:0] fragment_issue_effect_id,
  input  logic [ID_WIDTH-1:0] fragment_issue_queue_epoch,

  input  logic resolution_valid,
  input  logic resolution_committed,
  input  logic resolution_tx_index,
  input  logic resolution_fragment_index,
  input  logic [ID_WIDTH-1:0] resolution_command_id,
  input  logic [ID_WIDTH-1:0] resolution_execution_epoch,
  input  logic [ID_WIDTH-1:0] resolution_effect_id,
  input  logic [ID_WIDTH-1:0] resolution_queue_epoch,

  input  logic restore_valid,

  input  logic retire_valid,
  input  logic retire_tx_index,
  input  logic [ID_WIDTH-1:0] retire_command_id,
  input  logic [ID_WIDTH-1:0] retire_execution_epoch,
  input  logic [ID_WIDTH-1:0] retire_effect_id,
  input  logic [ID_WIDTH-1:0] retire_queue_epoch,

  output logic runtime_ready,
  output logic submit_accept,
  output logic [1:0] tx_pending,
  output logic [1:0] tx_retired,
  output logic [ID_WIDTH-1:0] live_queue_epoch,
  output logic [2*ID_WIDTH-1:0] live_command_ids,
  output logic [2*ID_WIDTH-1:0] live_execution_epochs,
  output logic [2*ID_WIDTH-1:0] live_effect_ids,

  output logic checkpoint_capture_accept,
  output logic checkpoint_valid,
  output logic [1:0] checkpoint_tx_pending,
  output logic [1:0] checkpoint_tx_retired,
  output logic [ID_WIDTH-1:0] checkpoint_queue_epoch,
  output logic [2*ID_WIDTH-1:0] checkpoint_command_ids,
  output logic [2*ID_WIDTH-1:0] checkpoint_execution_epochs,
  output logic [2*ID_WIDTH-1:0] checkpoint_effect_ids,
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
  output logic [3:0] queue_blocked_bitmap,

  output logic [3:0] issue_receipt_bitmap,
  output logic [3:0] negative_receipt_bitmap,
  output logic [3:0] completion_receipt_bitmap,

  output logic [3:0] durable_owner_valid,
  output logic [7:0] durable_owner_map,
  output logic [3:0] visible_owner_valid,
  output logic [7:0] visible_owner_map,

  output logic all_tx0_fragments_committed,
  output logic all_tx1_fragments_committed,
  output logic speculation_kill
);

  localparam logic [1:0] FRAG_UNISSUED      = 2'b00;
  localparam logic [1:0] FRAG_UNKNOWN       = 2'b01;
  localparam logic [1:0] FRAG_COMMITTED     = 2'b10;
  localparam logic [1:0] FRAG_NOT_COMMITTED = 2'b11;

  integer i;
  integer j;
  logic [1:0] issue_global_index;
  logic [1:0] resolution_global_index;
  logic [1:0] retire_base_index;
  logic issue_identity_matches;
  logic resolution_identity_matches;
  logic retire_identity_matches;
  logic older_overlap_clear;

  function automatic logic [3:0] fragment_mask(input logic [1:0] idx);
    begin
      case (idx)
        2'd0: fragment_mask = 4'b0011; // TX0.F0 -> lanes 0,1
        2'd1: fragment_mask = 4'b0100; // TX0.F1 -> lane 2
        2'd2: fragment_mask = 4'b1000; // TX1.F0 -> lane 3 (non-overlap)
        default: fragment_mask = 4'b0110; // TX1.F1 -> lanes 1,2
      endcase
    end
  endfunction

  function automatic logic [ID_WIDTH-1:0] slot_id(input logic [2*ID_WIDTH-1:0] vec,input logic tx);
    begin
      slot_id = vec[tx*ID_WIDTH +: ID_WIDTH];
    end
  endfunction

  always_comb begin
    issue_global_index = {fragment_issue_tx_index,fragment_issue_index};
    resolution_global_index = {resolution_tx_index,resolution_fragment_index};
    retire_base_index = retire_tx_index ? 2'd2 : 2'd0;

    all_tx0_fragments_committed =
      fragment_states[1:0] == FRAG_COMMITTED && fragment_states[3:2] == FRAG_COMMITTED;
    all_tx1_fragments_committed =
      fragment_states[5:4] == FRAG_COMMITTED && fragment_states[7:6] == FRAG_COMMITTED;

    replay_authority_bitmap = 4'b0000;
    evidence_required_bitmap = 4'b0000;
    queue_blocked_bitmap = 4'b0000;

    for (i = 0; i < 4; i = i + 1) begin
      if (fragment_states[i*2 +: 2] == FRAG_UNKNOWN)
        evidence_required_bitmap[i] = runtime_ready && tx_pending[i/2];

      older_overlap_clear = 1'b1;
      if (i >= 2 && !tx_retired[0]) begin
        for (j = 0; j < 2; j = j + 1) begin
          if (((fragment_mask(i[1:0]) & fragment_mask(j[1:0])) != 4'b0000) &&
              fragment_states[j*2 +: 2] != FRAG_COMMITTED)
            older_overlap_clear = 1'b0;
        end
      end

      if (i >= 2 && !older_overlap_clear)
        queue_blocked_bitmap[i] = 1'b1;

      if (runtime_ready && tx_pending[i/2] && !recovery_begin && !restore_valid &&
          (fragment_states[i*2 +: 2] == FRAG_UNISSUED || fragment_states[i*2 +: 2] == FRAG_NOT_COMMITTED) &&
          (i < 2 || older_overlap_clear))
        replay_authority_bitmap[i] = 1'b1;
    end

    submit_accept = submit_valid && runtime_ready && !recovery_begin && !restore_valid &&
      !tx_pending[submit_tx_index] && !tx_retired[submit_tx_index] &&
      ((!submit_tx_index && tx_pending == 2'b00 && tx_retired == 2'b00) ||
       (submit_tx_index && (tx_pending[0] || tx_retired[0]) && submit_queue_epoch == live_queue_epoch));

    issue_identity_matches =
      fragment_issue_queue_epoch == live_queue_epoch &&
      fragment_issue_command_id == slot_id(live_command_ids,fragment_issue_tx_index) &&
      fragment_issue_execution_epoch == slot_id(live_execution_epochs,fragment_issue_tx_index) &&
      fragment_issue_effect_id == slot_id(live_effect_ids,fragment_issue_tx_index);

    fragment_issue_accept = fragment_issue_valid && runtime_ready && !recovery_begin && !restore_valid &&
      tx_pending[fragment_issue_tx_index] && issue_identity_matches &&
      replay_authority_bitmap[issue_global_index];
    fragment_issue_rejected = fragment_issue_valid && !fragment_issue_accept;

    resolution_identity_matches =
      resolution_queue_epoch == live_queue_epoch &&
      resolution_command_id == slot_id(live_command_ids,resolution_tx_index) &&
      resolution_execution_epoch == slot_id(live_execution_epochs,resolution_tx_index) &&
      resolution_effect_id == slot_id(live_effect_ids,resolution_tx_index);

    resolution_accept = resolution_valid && runtime_ready && !recovery_begin && !restore_valid &&
      tx_pending[resolution_tx_index] && resolution_identity_matches &&
      fragment_states[resolution_global_index*2 +: 2] == FRAG_UNKNOWN &&
      issue_receipt_bitmap[resolution_global_index];
    resolution_rejected = resolution_valid && !resolution_accept;

    checkpoint_capture_accept = checkpoint_capture_valid && runtime_ready && (tx_pending != 2'b00) && !recovery_begin && !restore_valid;

    restore_accept = restore_valid && !recovery_begin && !runtime_ready && checkpoint_valid;
    restore_rejected = restore_valid && !restore_accept;

    retire_identity_matches =
      retire_queue_epoch == live_queue_epoch &&
      retire_command_id == slot_id(live_command_ids,retire_tx_index) &&
      retire_execution_epoch == slot_id(live_execution_epochs,retire_tx_index) &&
      retire_effect_id == slot_id(live_effect_ids,retire_tx_index);

    retire_accept = retire_valid && runtime_ready && !recovery_begin && !restore_valid &&
      tx_pending[retire_tx_index] && retire_identity_matches &&
      ((!retire_tx_index && all_tx0_fragments_committed && completion_receipt_bitmap[1:0] == 2'b11) ||
       (retire_tx_index && tx_retired[0] && all_tx1_fragments_committed && completion_receipt_bitmap[3:2] == 2'b11));
    retire_rejected = retire_valid && !retire_accept;

    speculation_kill = recovery_begin || restore_valid;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      runtime_ready <= 1'b1;
      tx_pending <= 2'b00;
      tx_retired <= 2'b00;
      live_queue_epoch <= '0;
      live_command_ids <= '0;
      live_execution_epochs <= '0;
      live_effect_ids <= '0;
      fragment_states <= '0;

      checkpoint_valid <= 1'b0;
      checkpoint_tx_pending <= 2'b00;
      checkpoint_tx_retired <= 2'b00;
      checkpoint_queue_epoch <= '0;
      checkpoint_command_ids <= '0;
      checkpoint_execution_epochs <= '0;
      checkpoint_effect_ids <= '0;
      checkpoint_fragment_states <= '0;
      checkpoint_owner_valid <= '0;
      checkpoint_owner_map <= '0;

      issue_receipt_bitmap <= '0;
      negative_receipt_bitmap <= '0;
      completion_receipt_bitmap <= '0;
      durable_owner_valid <= '0;
      durable_owner_map <= '0;
      visible_owner_valid <= '0;
      visible_owner_map <= '0;
    end else if (recovery_begin) begin
      runtime_ready <= 1'b0;
      tx_pending <= 2'b00;
      fragment_states <= '0;
      visible_owner_valid <= '0;
      visible_owner_map <= '0;
    end else if (restore_accept) begin
      runtime_ready <= 1'b1;
      live_queue_epoch <= checkpoint_queue_epoch;
      live_command_ids <= checkpoint_command_ids;
      live_execution_epochs <= checkpoint_execution_epochs;
      live_effect_ids <= checkpoint_effect_ids;
      tx_pending[0] <= tx_retired[0] ? 1'b0 : checkpoint_tx_pending[0];
      tx_pending[1] <= tx_retired[1] ? 1'b0 : checkpoint_tx_pending[1];

      for (i = 0; i < 4; i = i + 1) begin
        if (completion_receipt_bitmap[i])
          fragment_states[i*2 +: 2] <= FRAG_COMMITTED;
        else if (issue_receipt_bitmap[i])
          fragment_states[i*2 +: 2] <= FRAG_UNKNOWN;
        else if (negative_receipt_bitmap[i])
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
        tx_pending[submit_tx_index] <= 1'b1;
        live_command_ids[submit_tx_index*ID_WIDTH +: ID_WIDTH] <= submit_command_id;
        live_execution_epochs[submit_tx_index*ID_WIDTH +: ID_WIDTH] <= submit_execution_epoch;
        live_effect_ids[submit_tx_index*ID_WIDTH +: ID_WIDTH] <= submit_effect_id;
        if (!submit_tx_index)
          live_queue_epoch <= submit_queue_epoch;
        fragment_states[{submit_tx_index,1'b0}*2 +: 4] <= 4'b0000;
        issue_receipt_bitmap[{submit_tx_index,1'b0} +: 2] <= 2'b00;
        negative_receipt_bitmap[{submit_tx_index,1'b0} +: 2] <= 2'b00;
        completion_receipt_bitmap[{submit_tx_index,1'b0} +: 2] <= 2'b00;
      end

      if (fragment_issue_accept) begin
        fragment_states[issue_global_index*2 +: 2] <= FRAG_UNKNOWN;
        issue_receipt_bitmap[issue_global_index] <= 1'b1;
        negative_receipt_bitmap[issue_global_index] <= 1'b0;
      end

      if (resolution_accept) begin
        issue_receipt_bitmap[resolution_global_index] <= 1'b0;
        if (resolution_committed) begin
          fragment_states[resolution_global_index*2 +: 2] <= FRAG_COMMITTED;
          completion_receipt_bitmap[resolution_global_index] <= 1'b1;
          negative_receipt_bitmap[resolution_global_index] <= 1'b0;
          for (i = 0; i < 4; i = i + 1) begin
            if ((fragment_mask(resolution_global_index) & (4'b0001 << i)) != 4'b0000) begin
              durable_owner_valid[i] <= 1'b1;
              durable_owner_map[i*2 +: 2] <= resolution_global_index;
              visible_owner_valid[i] <= 1'b1;
              visible_owner_map[i*2 +: 2] <= resolution_global_index;
            end
          end
        end else begin
          fragment_states[resolution_global_index*2 +: 2] <= FRAG_NOT_COMMITTED;
          negative_receipt_bitmap[resolution_global_index] <= 1'b1;
        end
      end

      if (checkpoint_capture_accept) begin
        checkpoint_valid <= 1'b1;
        checkpoint_tx_pending <= tx_pending;
        checkpoint_tx_retired <= tx_retired;
        checkpoint_queue_epoch <= live_queue_epoch;
        checkpoint_command_ids <= live_command_ids;
        checkpoint_execution_epochs <= live_execution_epochs;
        checkpoint_effect_ids <= live_effect_ids;
        checkpoint_fragment_states <= fragment_states;
        checkpoint_owner_valid <= visible_owner_valid;
        checkpoint_owner_map <= visible_owner_map;
      end

      if (retire_accept) begin
        tx_pending[retire_tx_index] <= 1'b0;
        tx_retired[retire_tx_index] <= 1'b1;
      end
    end
  end
endmodule
