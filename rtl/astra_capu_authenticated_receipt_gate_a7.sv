module astra_capu_authenticated_receipt_gate_a7 #(
  parameter integer DEVICE_WIDTH = 8,
  parameter integer TAG_WIDTH    = 8,
  parameter integer ID_WIDTH     = 4,
  parameter integer AUTH_WIDTH   = 16
)(
  input  logic                      clk,
  input  logic                      cold_rst_n,

  input  logic                      trust_provision_valid,
  input  logic [DEVICE_WIDTH-1:0]   trust_provision_device_id,
  input  logic [ID_WIDTH-1:0]       trust_provision_key_epoch,
  input  logic [AUTH_WIDTH-1:0]     trust_provision_secret,
  input  logic [ID_WIDTH-1:0]       trust_provision_next_receipt_seq,

  input  logic                      receipt_valid,
  input  logic [DEVICE_WIDTH-1:0]   receipt_device_id,
  input  logic [ID_WIDTH-1:0]       receipt_key_epoch,
  input  logic [ID_WIDTH-1:0]       receipt_seq,
  input  logic [TAG_WIDTH-1:0]      receipt_authority_tag,
  input  logic [ID_WIDTH-1:0]       receipt_incarnation,
  input  logic [ID_WIDTH-1:0]       receipt_queue_epoch,
  input  logic [ID_WIDTH-1:0]       receipt_slot_id,
  input  logic [ID_WIDTH-1:0]       receipt_command_id,
  input  logic [ID_WIDTH-1:0]       receipt_attempt_id,
  input  logic [ID_WIDTH-1:0]       receipt_effect_id,
  input  logic [2:0]                receipt_outcome,
  input  logic [AUTH_WIDTH-1:0]     receipt_auth_tag,

  output logic                      trust_provision_accept,
  output logic                      trust_provision_rejected,
  output logic                      receipt_auth_accept,
  output logic                      receipt_auth_rejected,
  output logic [2:0]                receipt_auth_reject_code,
  output logic [AUTH_WIDTH-1:0]     receipt_expected_auth_tag,

  output logic                      verified_reconcile_valid,
  output logic [TAG_WIDTH-1:0]      verified_reconcile_tag,
  output logic [ID_WIDTH-1:0]       verified_reconcile_incarnation,
  output logic [ID_WIDTH-1:0]       verified_reconcile_queue_epoch,
  output logic [ID_WIDTH-1:0]       verified_reconcile_slot_id,
  output logic [ID_WIDTH-1:0]       verified_reconcile_command_id,
  output logic [ID_WIDTH-1:0]       verified_reconcile_attempt_id,
  output logic [ID_WIDTH-1:0]       verified_reconcile_effect_id,
  output logic [2:0]                verified_reconcile_outcome,

  output logic                      trusted_valid,
  output logic [DEVICE_WIDTH-1:0]   trusted_device_id,
  output logic [ID_WIDTH-1:0]       trusted_key_epoch,
  output logic [AUTH_WIDTH-1:0]     trusted_secret,
  output logic [ID_WIDTH-1:0]       trusted_next_receipt_seq,
  output logic                      receipt_sequence_exhausted
);

  localparam logic [2:0] AUTH_NONE       = 3'd0;
  localparam logic [2:0] AUTH_NO_TRUST   = 3'd1;
  localparam logic [2:0] AUTH_DEVICE_ID  = 3'd2;
  localparam logic [2:0] AUTH_KEY_EPOCH  = 3'd3;
  localparam logic [2:0] AUTH_SEQUENCE   = 3'd4;
  localparam logic [2:0] AUTH_TAG        = 3'd5;
  localparam logic [2:0] AUTH_EXHAUSTED  = 3'd6;

  function automatic [AUTH_WIDTH-1:0] rotl1(
    input [AUTH_WIDTH-1:0] value
  );
    begin
      rotl1 = {value[AUTH_WIDTH-2:0], value[AUTH_WIDTH-1]};
    end
  endfunction

  function automatic [AUTH_WIDTH-1:0] receipt_tag_fn(
    input [AUTH_WIDTH-1:0]   secret_i,
    input [DEVICE_WIDTH-1:0] device_id_i,
    input [ID_WIDTH-1:0]     key_epoch_i,
    input [ID_WIDTH-1:0]     receipt_seq_i,
    input [TAG_WIDTH-1:0]    authority_tag_i,
    input [ID_WIDTH-1:0]     incarnation_i,
    input [ID_WIDTH-1:0]     queue_epoch_i,
    input [ID_WIDTH-1:0]     slot_id_i,
    input [ID_WIDTH-1:0]     command_id_i,
    input [ID_WIDTH-1:0]     attempt_id_i,
    input [ID_WIDTH-1:0]     effect_id_i,
    input [2:0]              outcome_i
  );
    logic [AUTH_WIDTH-1:0] acc;
    begin
      acc = secret_i;
      acc = rotl1(acc) ^ device_id_i;
      acc = rotl1(acc) ^ key_epoch_i;
      acc = rotl1(acc) ^ receipt_seq_i;
      acc = rotl1(acc) ^ authority_tag_i;
      acc = rotl1(acc) ^ incarnation_i;
      acc = rotl1(acc) ^ queue_epoch_i;
      acc = rotl1(acc) ^ slot_id_i;
      acc = rotl1(acc) ^ command_id_i;
      acc = rotl1(acc) ^ attempt_id_i;
      acc = rotl1(acc) ^ effect_id_i;
      acc = rotl1(acc) ^ outcome_i;
      receipt_tag_fn = acc;
    end
  endfunction

  always_comb begin
    receipt_expected_auth_tag = receipt_tag_fn(
      trusted_secret,
      receipt_device_id,
      receipt_key_epoch,
      receipt_seq,
      receipt_authority_tag,
      receipt_incarnation,
      receipt_queue_epoch,
      receipt_slot_id,
      receipt_command_id,
      receipt_attempt_id,
      receipt_effect_id,
      receipt_outcome
    );

    receipt_sequence_exhausted = trusted_valid && (&trusted_next_receipt_seq);

    trust_provision_accept =
      cold_rst_n && trust_provision_valid && !trusted_valid && !receipt_valid;
    trust_provision_rejected =
      trust_provision_valid && !trust_provision_accept;

    receipt_auth_accept =
      cold_rst_n && receipt_valid && trusted_valid &&
      receipt_device_id == trusted_device_id &&
      receipt_key_epoch == trusted_key_epoch &&
      receipt_seq == trusted_next_receipt_seq &&
      receipt_auth_tag == receipt_expected_auth_tag &&
      !receipt_sequence_exhausted &&
      !trust_provision_valid;
    receipt_auth_rejected = receipt_valid && !receipt_auth_accept;

    receipt_auth_reject_code = AUTH_NONE;
    if (receipt_valid && !receipt_auth_accept) begin
      if (!trusted_valid)
        receipt_auth_reject_code = AUTH_NO_TRUST;
      else if (receipt_device_id != trusted_device_id)
        receipt_auth_reject_code = AUTH_DEVICE_ID;
      else if (receipt_key_epoch != trusted_key_epoch)
        receipt_auth_reject_code = AUTH_KEY_EPOCH;
      else if (receipt_seq != trusted_next_receipt_seq)
        receipt_auth_reject_code = AUTH_SEQUENCE;
      else if (receipt_auth_tag != receipt_expected_auth_tag)
        receipt_auth_reject_code = AUTH_TAG;
      else if (receipt_sequence_exhausted)
        receipt_auth_reject_code = AUTH_EXHAUSTED;
      else
        receipt_auth_reject_code = AUTH_TAG;
    end

    verified_reconcile_valid = receipt_auth_accept;
    verified_reconcile_tag = receipt_authority_tag;
    verified_reconcile_incarnation = receipt_incarnation;
    verified_reconcile_queue_epoch = receipt_queue_epoch;
    verified_reconcile_slot_id = receipt_slot_id;
    verified_reconcile_command_id = receipt_command_id;
    verified_reconcile_attempt_id = receipt_attempt_id;
    verified_reconcile_effect_id = receipt_effect_id;
    verified_reconcile_outcome = receipt_outcome;
  end

  always_ff @(posedge clk) begin
    if (!cold_rst_n) begin
      trusted_valid <= 1'b0;
      trusted_device_id <= '0;
      trusted_key_epoch <= '0;
      trusted_secret <= '0;
      trusted_next_receipt_seq <= '0;
    end else if (trust_provision_accept) begin
      trusted_valid <= 1'b1;
      trusted_device_id <= trust_provision_device_id;
      trusted_key_epoch <= trust_provision_key_epoch;
      trusted_secret <= trust_provision_secret;
      trusted_next_receipt_seq <= trust_provision_next_receipt_seq;
    end else if (receipt_auth_accept) begin
      trusted_next_receipt_seq <=
        trusted_next_receipt_seq + {{(ID_WIDTH-1){1'b0}}, 1'b1};
    end
  end

endmodule
