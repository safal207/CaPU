module astra_capu_authority_shim_a4 #(
  parameter integer TAG_WIDTH = 8,
  parameter integer ID_WIDTH  = 4
)(
  input  logic                 clk,
  input  logic                 rst_n,

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

  output logic                 authority_load_accept,
  output logic                 authority_load_rejected,
  output logic                 authority_revoke_accept,
  output logic                 authority_revoke_rejected,
  output logic                 command_forward,
  output logic                 command_rejected,
  output logic [2:0]           command_reject_code,

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

  localparam logic [2:0] REJECT_NONE            = 3'd0;
  localparam logic [2:0] REJECT_NO_AUTHORITY    = 3'd1;
  localparam logic [2:0] REJECT_UNCOMMITTED     = 3'd2;
  localparam logic [2:0] REJECT_IDENTITY        = 3'd3;
  localparam logic [2:0] REJECT_ALREADY_ISSUED  = 3'd4;
  localparam logic [2:0] REJECT_REVOKE_PENDING  = 3'd5;

  logic command_identity_matches;
  logic revoke_identity_matches;

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

    authority_load_accept =
      rst_n && authority_load_valid && !active_valid && !authority_revoke_valid;
    authority_load_rejected = authority_load_valid && !authority_load_accept;

    authority_revoke_accept =
      rst_n && authority_revoke_valid && active_valid && revoke_identity_matches;
    authority_revoke_rejected =
      authority_revoke_valid && !authority_revoke_accept;

    command_forward =
      rst_n && command_valid &&
      active_valid && active_committed &&
      command_identity_matches &&
      !attempt_spent &&
      !authority_revoke_valid;
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
      else
        command_reject_code = REJECT_NO_AUTHORITY;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
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
