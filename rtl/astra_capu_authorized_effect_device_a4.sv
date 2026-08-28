module astra_capu_authorized_effect_device_a4 #(
  parameter integer TAG_WIDTH   = 8,
  parameter integer ID_WIDTH    = 4,
  parameter integer COUNT_WIDTH = 16
)(
  input  logic                   clk,
  input  logic                   rst_n,

  input  logic                   device_state_load_valid,
  input  logic [COUNT_WIDTH-1:0] device_state_load_count,

  input  logic                   authority_load_valid,
  input  logic                   authority_load_committed,
  input  logic [TAG_WIDTH-1:0]   authority_load_tag,
  input  logic [ID_WIDTH-1:0]    authority_load_incarnation,
  input  logic [ID_WIDTH-1:0]    authority_load_queue_epoch,
  input  logic [ID_WIDTH-1:0]    authority_load_slot_id,
  input  logic [ID_WIDTH-1:0]    authority_load_command_id,
  input  logic [ID_WIDTH-1:0]    authority_load_attempt_id,
  input  logic [ID_WIDTH-1:0]    authority_load_effect_id,

  input  logic                   authority_revoke_valid,
  input  logic [TAG_WIDTH-1:0]   authority_revoke_tag,
  input  logic [ID_WIDTH-1:0]    authority_revoke_incarnation,
  input  logic [ID_WIDTH-1:0]    authority_revoke_queue_epoch,
  input  logic [ID_WIDTH-1:0]    authority_revoke_slot_id,
  input  logic [ID_WIDTH-1:0]    authority_revoke_command_id,
  input  logic [ID_WIDTH-1:0]    authority_revoke_attempt_id,
  input  logic [ID_WIDTH-1:0]    authority_revoke_effect_id,

  input  logic                   command_valid,
  input  logic                   command_commit,
  input  logic [TAG_WIDTH-1:0]   command_authority_tag,
  input  logic [ID_WIDTH-1:0]    command_incarnation,
  input  logic [ID_WIDTH-1:0]    command_queue_epoch,
  input  logic [ID_WIDTH-1:0]    command_slot_id,
  input  logic [ID_WIDTH-1:0]    command_id,
  input  logic [ID_WIDTH-1:0]    command_attempt_id,
  input  logic [ID_WIDTH-1:0]    command_effect_id,

  output logic                   authority_load_accept,
  output logic                   authority_load_rejected,
  output logic                   authority_revoke_accept,
  output logic                   authority_revoke_rejected,
  output logic                   command_forward,
  output logic                   command_rejected,
  output logic [2:0]             command_reject_code,
  output logic                   device_command_accept,
  output logic                   device_completion_valid,
  output logic [COUNT_WIDTH-1:0] effect_count,

  output logic                   active_valid,
  output logic                   active_committed,
  output logic                   attempt_spent,
  output logic [TAG_WIDTH-1:0]   active_authority_tag,
  output logic [ID_WIDTH-1:0]    active_incarnation,
  output logic [ID_WIDTH-1:0]    active_queue_epoch,
  output logic [ID_WIDTH-1:0]    active_slot_id,
  output logic [ID_WIDTH-1:0]    active_command_id,
  output logic [ID_WIDTH-1:0]    active_attempt_id,
  output logic [ID_WIDTH-1:0]    active_effect_id
);

  astra_capu_authority_shim_a4 #(
    .TAG_WIDTH(TAG_WIDTH),
    .ID_WIDTH(ID_WIDTH)
  ) authority_shim (
    .*
  );

  astra_capu_effect_counter_a3 #(
    .COUNT_WIDTH(COUNT_WIDTH)
  ) effect_device (
    .clk(clk),
    .rst_n(rst_n),
    .load_valid(device_state_load_valid),
    .load_effect_count(device_state_load_count),
    .command_valid(command_forward),
    .command_commit(command_commit),
    .command_accept(device_command_accept),
    .completion_valid(device_completion_valid),
    .effect_count(effect_count)
  );

endmodule
