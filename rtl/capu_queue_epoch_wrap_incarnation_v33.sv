module capu_queue_epoch_wrap_incarnation_v33 #(
  parameter ID_WIDTH = 4
)(
  input  logic clk,
  input  logic rst_n,
  input  logic recovery_begin,

  input  logic submit_valid,
  input  logic [ID_WIDTH-1:0] submit_incarnation,
  input  logic [ID_WIDTH-1:0] submit_queue_epoch,
  input  logic [ID_WIDTH-1:0] submit_command_id,
  input  logic [ID_WIDTH-1:0] submit_execution_epoch,
  input  logic [ID_WIDTH-1:0] submit_effect_id,

  input  logic checkpoint_capture_valid,

  input  logic issue_valid,
  input  logic [ID_WIDTH-1:0] issue_incarnation,
  input  logic [ID_WIDTH-1:0] issue_queue_epoch,
  input  logic [ID_WIDTH-1:0] issue_command_id,
  input  logic [ID_WIDTH-1:0] issue_execution_epoch,
  input  logic [ID_WIDTH-1:0] issue_effect_id,

  input  logic resolution_valid,
  input  logic resolution_committed,
  input  logic [ID_WIDTH-1:0] resolution_incarnation,
  input  logic [ID_WIDTH-1:0] resolution_queue_epoch,
  input  logic [ID_WIDTH-1:0] resolution_command_id,
  input  logic [ID_WIDTH-1:0] resolution_execution_epoch,
  input  logic [ID_WIDTH-1:0] resolution_effect_id,

  input  logic restore_valid,

  input  logic retire_valid,
  input  logic [ID_WIDTH-1:0] retire_incarnation,
  input  logic [ID_WIDTH-1:0] retire_queue_epoch,
  input  logic [ID_WIDTH-1:0] retire_command_id,
  input  logic [ID_WIDTH-1:0] retire_execution_epoch,
  input  logic [ID_WIDTH-1:0] retire_effect_id,

  output logic runtime_ready,
  output logic submit_accept,
  output logic slot_reuse_accept,
  output logic epoch_wrap_accept,
  output logic incarnation_exhausted,
  output logic slot_pending,

  output logic [ID_WIDTH-1:0] live_incarnation,
  output logic [ID_WIDTH-1:0] live_queue_epoch,
  output logic [ID_WIDTH-1:0] live_command_id,
  output logic [ID_WIDTH-1:0] live_execution_epoch,
  output logic [ID_WIDTH-1:0] live_effect_id,
  output logic [1:0] effect_state,

  output logic checkpoint_capture_accept,
  output logic checkpoint_valid,
  output logic checkpoint_pending,
  output logic [ID_WIDTH-1:0] checkpoint_incarnation,
  output logic [ID_WIDTH-1:0] checkpoint_queue_epoch,
  output logic [ID_WIDTH-1:0] checkpoint_command_id,
  output logic [ID_WIDTH-1:0] checkpoint_execution_epoch,
  output logic [ID_WIDTH-1:0] checkpoint_effect_id,
  output logic [1:0] checkpoint_effect_state,

  output logic issue_accept,
  output logic issue_rejected,
  output logic resolution_accept,
  output logic resolution_rejected,
  output logic restore_accept,
  output logic restore_rejected,
  output logic retire_accept,
  output logic retire_rejected,

  output logic replay_authority,
  output logic evidence_required,
  output logic issue_receipt,
  output logic negative_receipt,
  output logic completion_receipt,

  output logic durable_slot_valid,
  output logic [ID_WIDTH-1:0] durable_incarnation,
  output logic [ID_WIDTH-1:0] durable_queue_epoch,
  output logic [ID_WIDTH-1:0] durable_command_id,
  output logic [ID_WIDTH-1:0] durable_execution_epoch,
  output logic [ID_WIDTH-1:0] durable_effect_id,

  output logic last_retired_valid,
  output logic [ID_WIDTH-1:0] last_retired_incarnation,
  output logic [ID_WIDTH-1:0] last_retired_queue_epoch,
  output logic stale_evidence_quarantine_accept,
  output logic stale_evidence_quarantined,
  output logic speculation_kill
);

  localparam logic [1:0] EFFECT_UNISSUED      = 2'b00;
  localparam logic [1:0] EFFECT_UNKNOWN       = 2'b01;
  localparam logic [1:0] EFFECT_COMMITTED     = 2'b10;
  localparam logic [1:0] EFFECT_NOT_COMMITTED = 2'b11;

  logic submit_successor_ok;
  logic issue_identity_matches;
  logic resolution_identity_matches;
  logic retire_identity_matches;
  logic resolution_is_older_authority;

  always_comb begin
    if (!last_retired_valid) begin
      submit_successor_ok = 1'b1;
    end else if (last_retired_queue_epoch != {ID_WIDTH{1'b1}}) begin
      submit_successor_ok =
        (submit_incarnation == last_retired_incarnation) &&
        (submit_queue_epoch == last_retired_queue_epoch + 1'b1);
    end else if (last_retired_incarnation != {ID_WIDTH{1'b1}}) begin
      submit_successor_ok =
        (submit_incarnation == last_retired_incarnation + 1'b1) &&
        (submit_queue_epoch == {ID_WIDTH{1'b0}});
    end else begin
      submit_successor_ok = 1'b0;
    end

    submit_accept = submit_valid && runtime_ready && !recovery_begin && !restore_valid &&
      !durable_slot_valid && !slot_pending && submit_successor_ok;
    slot_reuse_accept = submit_accept && last_retired_valid;
    epoch_wrap_accept = submit_accept && last_retired_valid &&
      (last_retired_queue_epoch == {ID_WIDTH{1'b1}});
    incarnation_exhausted = submit_valid && runtime_ready && !recovery_begin && !restore_valid &&
      !durable_slot_valid && !slot_pending && last_retired_valid &&
      (last_retired_queue_epoch == {ID_WIDTH{1'b1}}) &&
      (last_retired_incarnation == {ID_WIDTH{1'b1}});

    replay_authority = runtime_ready && slot_pending && durable_slot_valid &&
      !recovery_begin && !restore_valid &&
      (effect_state == EFFECT_UNISSUED || effect_state == EFFECT_NOT_COMMITTED);

    evidence_required = runtime_ready && slot_pending && durable_slot_valid &&
      (effect_state == EFFECT_UNKNOWN);

    issue_identity_matches =
      issue_incarnation == durable_incarnation &&
      issue_queue_epoch == durable_queue_epoch &&
      issue_command_id == durable_command_id &&
      issue_execution_epoch == durable_execution_epoch &&
      issue_effect_id == durable_effect_id;

    issue_accept = issue_valid && replay_authority && issue_identity_matches;
    issue_rejected = issue_valid && !issue_accept;

    resolution_identity_matches =
      resolution_incarnation == durable_incarnation &&
      resolution_queue_epoch == durable_queue_epoch &&
      resolution_command_id == durable_command_id &&
      resolution_execution_epoch == durable_execution_epoch &&
      resolution_effect_id == durable_effect_id;

    resolution_accept = resolution_valid && runtime_ready && !recovery_begin && !restore_valid &&
      slot_pending && durable_slot_valid && resolution_identity_matches &&
      effect_state == EFFECT_UNKNOWN && issue_receipt;
    resolution_rejected = resolution_valid && !resolution_accept;

    checkpoint_capture_accept = checkpoint_capture_valid && runtime_ready && slot_pending &&
      !recovery_begin && !restore_valid;

    restore_accept = restore_valid && !recovery_begin && !runtime_ready &&
      (checkpoint_valid || durable_slot_valid || last_retired_valid);
    restore_rejected = restore_valid && !restore_accept;

    retire_identity_matches =
      retire_incarnation == durable_incarnation &&
      retire_queue_epoch == durable_queue_epoch &&
      retire_command_id == durable_command_id &&
      retire_execution_epoch == durable_execution_epoch &&
      retire_effect_id == durable_effect_id;

    retire_accept = retire_valid && runtime_ready && !recovery_begin && !restore_valid &&
      slot_pending && durable_slot_valid && retire_identity_matches &&
      effect_state == EFFECT_COMMITTED && completion_receipt;
    retire_rejected = retire_valid && !retire_accept;

    resolution_is_older_authority = resolution_valid && !resolution_accept && durable_slot_valid &&
      ((resolution_incarnation < durable_incarnation) ||
       ((resolution_incarnation == durable_incarnation) &&
        (resolution_queue_epoch < durable_queue_epoch)));
    stale_evidence_quarantine_accept = resolution_is_older_authority;

    speculation_kill = recovery_begin || restore_valid;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      runtime_ready <= 1'b1;
      slot_pending <= 1'b0;
      live_incarnation <= '0;
      live_queue_epoch <= '0;
      live_command_id <= '0;
      live_execution_epoch <= '0;
      live_effect_id <= '0;
      effect_state <= EFFECT_UNISSUED;

      checkpoint_valid <= 1'b0;
      checkpoint_pending <= 1'b0;
      checkpoint_incarnation <= '0;
      checkpoint_queue_epoch <= '0;
      checkpoint_command_id <= '0;
      checkpoint_execution_epoch <= '0;
      checkpoint_effect_id <= '0;
      checkpoint_effect_state <= EFFECT_UNISSUED;

      issue_receipt <= 1'b0;
      negative_receipt <= 1'b0;
      completion_receipt <= 1'b0;

      durable_slot_valid <= 1'b0;
      durable_incarnation <= '0;
      durable_queue_epoch <= '0;
      durable_command_id <= '0;
      durable_execution_epoch <= '0;
      durable_effect_id <= '0;

      last_retired_valid <= 1'b0;
      last_retired_incarnation <= '0;
      last_retired_queue_epoch <= '0;
      stale_evidence_quarantined <= 1'b0;
    end else if (recovery_begin) begin
      runtime_ready <= 1'b0;
      slot_pending <= 1'b0;
      effect_state <= EFFECT_UNISSUED;
    end else if (restore_accept) begin
      runtime_ready <= 1'b1;
      if (durable_slot_valid) begin
        slot_pending <= 1'b1;
        live_incarnation <= durable_incarnation;
        live_queue_epoch <= durable_queue_epoch;
        live_command_id <= durable_command_id;
        live_execution_epoch <= durable_execution_epoch;
        live_effect_id <= durable_effect_id;
        if (completion_receipt)
          effect_state <= EFFECT_COMMITTED;
        else if (issue_receipt)
          effect_state <= EFFECT_UNKNOWN;
        else if (negative_receipt)
          effect_state <= EFFECT_NOT_COMMITTED;
        else
          effect_state <= EFFECT_UNISSUED;
      end else begin
        slot_pending <= 1'b0;
        effect_state <= EFFECT_UNISSUED;
      end
    end else begin
      if (submit_accept) begin
        slot_pending <= 1'b1;
        live_incarnation <= submit_incarnation;
        live_queue_epoch <= submit_queue_epoch;
        live_command_id <= submit_command_id;
        live_execution_epoch <= submit_execution_epoch;
        live_effect_id <= submit_effect_id;
        effect_state <= EFFECT_UNISSUED;

        durable_slot_valid <= 1'b1;
        durable_incarnation <= submit_incarnation;
        durable_queue_epoch <= submit_queue_epoch;
        durable_command_id <= submit_command_id;
        durable_execution_epoch <= submit_execution_epoch;
        durable_effect_id <= submit_effect_id;

        issue_receipt <= 1'b0;
        negative_receipt <= 1'b0;
        completion_receipt <= 1'b0;
      end

      if (issue_accept) begin
        effect_state <= EFFECT_UNKNOWN;
        issue_receipt <= 1'b1;
        negative_receipt <= 1'b0;
      end

      if (resolution_accept) begin
        issue_receipt <= 1'b0;
        if (resolution_committed) begin
          effect_state <= EFFECT_COMMITTED;
          completion_receipt <= 1'b1;
          negative_receipt <= 1'b0;
        end else begin
          effect_state <= EFFECT_NOT_COMMITTED;
          negative_receipt <= 1'b1;
          completion_receipt <= 1'b0;
        end
      end

      if (stale_evidence_quarantine_accept)
        stale_evidence_quarantined <= 1'b1;

      if (checkpoint_capture_accept) begin
        checkpoint_valid <= 1'b1;
        checkpoint_pending <= slot_pending;
        checkpoint_incarnation <= live_incarnation;
        checkpoint_queue_epoch <= live_queue_epoch;
        checkpoint_command_id <= live_command_id;
        checkpoint_execution_epoch <= live_execution_epoch;
        checkpoint_effect_id <= live_effect_id;
        checkpoint_effect_state <= effect_state;
      end

      if (retire_accept) begin
        slot_pending <= 1'b0;
        last_retired_valid <= 1'b1;
        last_retired_incarnation <= durable_incarnation;
        last_retired_queue_epoch <= durable_queue_epoch;
        durable_slot_valid <= 1'b0;
        effect_state <= EFFECT_UNISSUED;
        issue_receipt <= 1'b0;
        negative_receipt <= 1'b0;
        completion_receipt <= 1'b0;
      end
    end
  end
endmodule
