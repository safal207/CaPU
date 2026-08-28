module astra_capu_authority_gate_a4 #(
  parameter ID_WIDTH = 4,
  parameter SPENT_DEPTH = 2
)(
  input  logic clk,
  input  logic rst_n,
  input  logic recovery_begin,

  input  logic authority_load_valid,
  input  logic authority_committed,
  input  logic [ID_WIDTH-1:0] authority_queue_incarnation,
  input  logic [ID_WIDTH-1:0] authority_queue_epoch,
  input  logic [ID_WIDTH-1:0] authority_slot_id,
  input  logic [ID_WIDTH-1:0] authority_command_id,
  input  logic [ID_WIDTH-1:0] authority_attempt_id,
  input  logic [ID_WIDTH-1:0] authority_effect_id,

  input  logic command_valid,
  input  logic [ID_WIDTH-1:0] command_queue_incarnation,
  input  logic [ID_WIDTH-1:0] command_queue_epoch,
  input  logic [ID_WIDTH-1:0] command_slot_id,
  input  logic [ID_WIDTH-1:0] command_command_id,
  input  logic [ID_WIDTH-1:0] command_attempt_id,
  input  logic [ID_WIDTH-1:0] command_effect_id,

  output logic authority_load_accept,
  output logic authority_load_rejected,
  output logic command_permit,
  output logic command_rejected,
  output logic downstream_command_valid,

  output logic token_valid_o,
  output logic token_committed_o,
  output logic token_spent_o,
  output logic [ID_WIDTH-1:0] token_queue_incarnation_o,
  output logic [ID_WIDTH-1:0] token_queue_epoch_o,
  output logic [ID_WIDTH-1:0] token_slot_id_o,
  output logic [ID_WIDTH-1:0] token_command_id_o,
  output logic [ID_WIDTH-1:0] token_attempt_id_o,
  output logic [ID_WIDTH-1:0] token_effect_id_o,

  output logic [SPENT_DEPTH-1:0] spent_valid_o,
  output logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_queue_incarnations_o,
  output logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_queue_epochs_o,
  output logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_slot_ids_o,
  output logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_command_ids_o,
  output logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_attempt_ids_o,
  output logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_effect_ids_o
);

  integer i;
  logic command_identity_matches_token;
  logic authority_identity_matches_spent;
  logic command_identity_matches_spent;

  always_comb begin
    command_identity_matches_token =
      command_queue_incarnation == token_queue_incarnation_o &&
      command_queue_epoch == token_queue_epoch_o &&
      command_slot_id == token_slot_id_o &&
      command_command_id == token_command_id_o &&
      command_attempt_id == token_attempt_id_o &&
      command_effect_id == token_effect_id_o;

    authority_identity_matches_spent = 1'b0;
    command_identity_matches_spent = 1'b0;
    for (i = 0; i < SPENT_DEPTH; i = i + 1) begin
      if (spent_valid_o[i] &&
          authority_queue_incarnation == spent_queue_incarnations_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_queue_epoch == spent_queue_epochs_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_slot_id == spent_slot_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_command_id == spent_command_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_attempt_id == spent_attempt_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_effect_id == spent_effect_ids_o[i*ID_WIDTH +: ID_WIDTH])
        authority_identity_matches_spent = 1'b1;

      if (spent_valid_o[i] &&
          command_queue_incarnation == spent_queue_incarnations_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_queue_epoch == spent_queue_epochs_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_slot_id == spent_slot_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_command_id == spent_command_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_attempt_id == spent_attempt_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_effect_id == spent_effect_ids_o[i*ID_WIDTH +: ID_WIDTH])
        command_identity_matches_spent = 1'b1;
    end

    authority_load_accept = authority_load_valid && !recovery_begin &&
      !authority_identity_matches_spent;
    authority_load_rejected = authority_load_valid && !authority_load_accept;

    command_permit = command_valid && !recovery_begin &&
      token_valid_o && token_committed_o && !token_spent_o &&
      command_identity_matches_token && !command_identity_matches_spent;
    command_rejected = command_valid && !command_permit;
    downstream_command_valid = command_permit;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      token_valid_o <= 1'b0;
      token_committed_o <= 1'b0;
      token_spent_o <= 1'b0;
      token_queue_incarnation_o <= '0;
      token_queue_epoch_o <= '0;
      token_slot_id_o <= '0;
      token_command_id_o <= '0;
      token_attempt_id_o <= '0;
      token_effect_id_o <= '0;

      spent_valid_o <= '0;
      spent_queue_incarnations_o <= '0;
      spent_queue_epochs_o <= '0;
      spent_slot_ids_o <= '0;
      spent_command_ids_o <= '0;
      spent_attempt_ids_o <= '0;
      spent_effect_ids_o <= '0;
    end else begin
      if (authority_load_accept) begin
        token_valid_o <= 1'b1;
        token_committed_o <= authority_committed;
        token_spent_o <= 1'b0;
        token_queue_incarnation_o <= authority_queue_incarnation;
        token_queue_epoch_o <= authority_queue_epoch;
        token_slot_id_o <= authority_slot_id;
        token_command_id_o <= authority_command_id;
        token_attempt_id_o <= authority_attempt_id;
        token_effect_id_o <= authority_effect_id;
      end

      if (command_permit) begin
        token_spent_o <= 1'b1;
        for (i = SPENT_DEPTH-1; i > 0; i = i - 1) begin
          spent_valid_o[i] <= spent_valid_o[i-1];
          spent_queue_incarnations_o[i*ID_WIDTH +: ID_WIDTH] <=
            spent_queue_incarnations_o[(i-1)*ID_WIDTH +: ID_WIDTH];
          spent_queue_epochs_o[i*ID_WIDTH +: ID_WIDTH] <=
            spent_queue_epochs_o[(i-1)*ID_WIDTH +: ID_WIDTH];
          spent_slot_ids_o[i*ID_WIDTH +: ID_WIDTH] <=
            spent_slot_ids_o[(i-1)*ID_WIDTH +: ID_WIDTH];
          spent_command_ids_o[i*ID_WIDTH +: ID_WIDTH] <=
            spent_command_ids_o[(i-1)*ID_WIDTH +: ID_WIDTH];
          spent_attempt_ids_o[i*ID_WIDTH +: ID_WIDTH] <=
            spent_attempt_ids_o[(i-1)*ID_WIDTH +: ID_WIDTH];
          spent_effect_ids_o[i*ID_WIDTH +: ID_WIDTH] <=
            spent_effect_ids_o[(i-1)*ID_WIDTH +: ID_WIDTH];
        end
        spent_valid_o[0] <= 1'b1;
        spent_queue_incarnations_o[0 +: ID_WIDTH] <= command_queue_incarnation;
        spent_queue_epochs_o[0 +: ID_WIDTH] <= command_queue_epoch;
        spent_slot_ids_o[0 +: ID_WIDTH] <= command_slot_id;
        spent_command_ids_o[0 +: ID_WIDTH] <= command_command_id;
        spent_attempt_ids_o[0 +: ID_WIDTH] <= command_attempt_id;
        spent_effect_ids_o[0 +: ID_WIDTH] <= command_effect_id;
      end
    end
  end

endmodule
