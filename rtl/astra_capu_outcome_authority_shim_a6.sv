module astra_capu_outcome_authority_shim_a6 #(
  parameter integer TAG_WIDTH = 8,
  parameter integer ID_WIDTH  = 4
)(
  input  logic                 clk,
  input  logic                 logic_rst_n,

  input  logic                 authority_load_valid,
  input  logic                 authority_load_committed,
  input  logic [TAG_WIDTH-1:0] authority_load_tag,
  input  logic [ID_WIDTH-1:0]  authority_load_incarnation,
  input  logic [ID_WIDTH-1:0]  authority_load_queue_epoch,
  input  logic [ID_WIDTH-1:0]  authority_load_slot_id,
  input  logic [ID_WIDTH-1:0]  authority_load_command_id,
  input  logic [ID_WIDTH-1:0]  authority_load_attempt_id,
  input  logic [ID_WIDTH-1:0]  authority_load_effect_id,

  input  logic                 authority_revoke_valid,
  input  logic [TAG_WIDTH-1:0] authority_revoke_tag,
  input  logic [ID_WIDTH-1:0]  authority_revoke_incarnation,
  input  logic [ID_WIDTH-1:0]  authority_revoke_queue_epoch,
  input  logic [ID_WIDTH-1:0]  authority_revoke_slot_id,
  input  logic [ID_WIDTH-1:0]  authority_revoke_command_id,
  input  logic [ID_WIDTH-1:0]  authority_revoke_attempt_id,
  input  logic [ID_WIDTH-1:0]  authority_revoke_effect_id,

  input  logic                 command_valid,
  input  logic [TAG_WIDTH-1:0] command_authority_tag,
  input  logic [ID_WIDTH-1:0]  command_incarnation,
  input  logic [ID_WIDTH-1:0]  command_queue_epoch,
  input  logic [ID_WIDTH-1:0]  command_slot_id,
  input  logic [ID_WIDTH-1:0]  command_id,
  input  logic [ID_WIDTH-1:0]  command_attempt_id,
  input  logic [ID_WIDTH-1:0]  command_effect_id,

  input  logic                 persistent_valid,
  input  logic [TAG_WIDTH-1:0] persistent_tag,
  input  logic [ID_WIDTH-1:0]  persistent_incarnation,
  input  logic [ID_WIDTH-1:0]  persistent_queue_epoch,
  input  logic [ID_WIDTH-1:0]  persistent_slot_id,
  input  logic [ID_WIDTH-1:0]  persistent_command_id,
  input  logic [ID_WIDTH-1:0]  persistent_effect_id,
  input  logic [ID_WIDTH-1:0]  persistent_next_attempt,
  input  logic                 unresolved_valid,
  input  logic                 terminal_committed,
  input  logic                 terminal_conflict,
  input  logic                 frontier_exhausted,
  input  logic                 reserve_accept,

  output logic                 reserve_valid,
  output logic [TAG_WIDTH-1:0] reserve_tag,
  output logic [ID_WIDTH-1:0]  reserve_incarnation,
  output logic [ID_WIDTH-1:0]  reserve_queue_epoch,
  output logic [ID_WIDTH-1:0]  reserve_slot_id,
  output logic [ID_WIDTH-1:0]  reserve_command_id,
  output logic [ID_WIDTH-1:0]  reserve_attempt_id,
  output logic [ID_WIDTH-1:0]  reserve_effect_id,

  output logic                 authority_load_accept,
  output logic                 authority_load_rejected,
  output logic                 authority_revoke_accept,
  output logic                 authority_revoke_rejected,
  output logic                 command_forward,
  output logic                 command_rejected,
  output logic [3:0]           command_reject_code,

  output logic                 active_valid,
  output logic                 active_committed,
  output logic                 attempt_spent,
  output logic [TAG_WIDTH-1:0] active_authority_tag,
  output logic [ID_WIDTH-1:0]  active_incarnation,
  output logic [ID_WIDTH-1:0]  active_queue_epoch,
  output logic [ID_WIDTH-1:0]  active_slot_id,
  output logic [ID_WIDTH-1:0]  active_command_id,
  output logic [ID_WIDTH-1:0]  active_attempt_id,
  output logic [ID_WIDTH-1:0]  active_effect_id
);

  localparam logic [3:0] REJECT_NONE                = 4'd0;
  localparam logic [3:0] REJECT_NO_AUTHORITY        = 4'd1;
  localparam logic [3:0] REJECT_UNCOMMITTED         = 4'd2;
  localparam logic [3:0] REJECT_IDENTITY            = 4'd3;
  localparam logic [3:0] REJECT_ALREADY_ISSUED      = 4'd4;
  localparam logic [3:0] REJECT_REVOKE_PENDING      = 4'd5;
  localparam logic [3:0] REJECT_PERSISTENT_MISSING  = 4'd6;
  localparam logic [3:0] REJECT_PERSISTENT_LINEAGE  = 4'd7;
  localparam logic [3:0] REJECT_PERSISTENT_FRONTIER = 4'd8;
  localparam logic [3:0] REJECT_FRONTIER_EXHAUSTED  = 4'd9;
  localparam logic [3:0] REJECT_OUTCOME_UNKNOWN     = 4'd10;
  localparam logic [3:0] REJECT_TERMINAL_COMMITTED  = 4'd11;
  localparam logic [3:0] REJECT_TERMINAL_CONFLICT   = 4'd12;
  localparam logic [3:0] REJECT_RESERVATION_FAILED  = 4'd13;

  logic command_identity_matches;
  logic revoke_identity_matches;
  logic persistent_lineage_matches;
  logic command_preconditions;

  always_comb begin
    command_identity_matches =
      command_authority_tag == active_authority_tag &&
      command_incarnation == active_incarnation &&
      command_queue_epoch == active_queue_epoch &&
      command_slot_id == active_slot_id &&
      command_id == active_command_id &&
      command_attempt_id == active_attempt_id &&
      command_effect_id == active_effect_id;

    revoke_identity_matches =
      authority_revoke_tag == active_authority_tag &&
      authority_revoke_incarnation == active_incarnation &&
      authority_revoke_queue_epoch == active_queue_epoch &&
      authority_revoke_slot_id == active_slot_id &&
      authority_revoke_command_id == active_command_id &&
      authority_revoke_attempt_id == active_attempt_id &&
      authority_revoke_effect_id == active_effect_id;

    persistent_lineage_matches =
      active_authority_tag == persistent_tag &&
      active_incarnation == persistent_incarnation &&
      active_queue_epoch == persistent_queue_epoch &&
      active_slot_id == persistent_slot_id &&
      active_command_id == persistent_command_id &&
      active_effect_id == persistent_effect_id;

    authority_load_accept =
      logic_rst_n && authority_load_valid && !active_valid && !authority_revoke_valid;
    authority_load_rejected = authority_load_valid && !authority_load_accept;

    authority_revoke_accept =
      logic_rst_n && authority_revoke_valid && active_valid && revoke_identity_matches;
    authority_revoke_rejected = authority_revoke_valid && !authority_revoke_accept;

    command_preconditions =
      logic_rst_n && command_valid &&
      active_valid && active_committed &&
      command_identity_matches &&
      !attempt_spent && !authority_revoke_valid &&
      persistent_valid && persistent_lineage_matches &&
      !terminal_committed && !terminal_conflict &&
      !unresolved_valid && !frontier_exhausted &&
      active_attempt_id == persistent_next_attempt;

    reserve_valid = command_preconditions;
    reserve_tag = active_authority_tag;
    reserve_incarnation = active_incarnation;
    reserve_queue_epoch = active_queue_epoch;
    reserve_slot_id = active_slot_id;
    reserve_command_id = active_command_id;
    reserve_attempt_id = active_attempt_id;
    reserve_effect_id = active_effect_id;

    command_forward = reserve_valid && reserve_accept;
    command_rejected = command_valid && !command_forward;

    command_reject_code = REJECT_NONE;
    if (command_valid && !command_forward) begin
      if (authority_revoke_valid)
        command_reject_code = REJECT_REVOKE_PENDING;
      else if (!active_valid)
        command_reject_code = REJECT_NO_AUTHORITY;
      else if (!active_committed)
        command_reject_code = REJECT_UNCOMMITTED;
      else if (!command_identity_matches)
        command_reject_code = REJECT_IDENTITY;
      else if (attempt_spent)
        command_reject_code = REJECT_ALREADY_ISSUED;
      else if (!persistent_valid)
        command_reject_code = REJECT_PERSISTENT_MISSING;
      else if (!persistent_lineage_matches)
        command_reject_code = REJECT_PERSISTENT_LINEAGE;
      else if (terminal_committed)
        command_reject_code = REJECT_TERMINAL_COMMITTED;
      else if (terminal_conflict)
        command_reject_code = REJECT_TERMINAL_CONFLICT;
      else if (unresolved_valid)
        command_reject_code = REJECT_OUTCOME_UNKNOWN;
      else if (active_attempt_id != persistent_next_attempt)
        command_reject_code = REJECT_PERSISTENT_FRONTIER;
      else if (frontier_exhausted)
        command_reject_code = REJECT_FRONTIER_EXHAUSTED;
      else if (!reserve_accept)
        command_reject_code = REJECT_RESERVATION_FAILED;
      else
        command_reject_code = REJECT_NO_AUTHORITY;
    end
  end

  always_ff @(posedge clk) begin
    if (!logic_rst_n) begin
      active_valid <= 1'b0;
      active_committed <= 1'b0;
      attempt_spent <= 1'b0;
      active_authority_tag <= '0;
      active_incarnation <= '0;
      active_queue_epoch <= '0;
      active_slot_id <= '0;
      active_command_id <= '0;
      active_attempt_id <= '0;
      active_effect_id <= '0;
    end else if (authority_revoke_accept) begin
      active_valid <= 1'b0;
      active_committed <= 1'b0;
      attempt_spent <= 1'b0;
      active_authority_tag <= '0;
      active_incarnation <= '0;
      active_queue_epoch <= '0;
      active_slot_id <= '0;
      active_command_id <= '0;
      active_attempt_id <= '0;
      active_effect_id <= '0;
    end else if (authority_load_accept) begin
      active_valid <= 1'b1;
      active_committed <= authority_load_committed;
      attempt_spent <= 1'b0;
      active_authority_tag <= authority_load_tag;
      active_incarnation <= authority_load_incarnation;
      active_queue_epoch <= authority_load_queue_epoch;
      active_slot_id <= authority_load_slot_id;
      active_command_id <= authority_load_command_id;
      active_attempt_id <= authority_load_attempt_id;
      active_effect_id <= authority_load_effect_id;
    end else if (command_forward) begin
      attempt_spent <= 1'b1;
    end
  end

endmodule
