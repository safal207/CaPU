module astra_capu_persistent_frontier_store_a5 #(
  parameter integer TAG_WIDTH = 8,
  parameter integer ID_WIDTH  = 4
)(
  input  logic                 clk,
  input  logic                 cold_rst_n,

  input  logic                 provision_valid,
  input  logic [TAG_WIDTH-1:0] provision_tag,
  input  logic [ID_WIDTH-1:0]  provision_incarnation,
  input  logic [ID_WIDTH-1:0]  provision_queue_epoch,
  input  logic [ID_WIDTH-1:0]  provision_slot_id,
  input  logic [ID_WIDTH-1:0]  provision_command_id,
  input  logic [ID_WIDTH-1:0]  provision_effect_id,
  input  logic [ID_WIDTH-1:0]  provision_next_attempt,

  input  logic                 advance_valid,
  input  logic [TAG_WIDTH-1:0] advance_tag,
  input  logic [ID_WIDTH-1:0]  advance_incarnation,
  input  logic [ID_WIDTH-1:0]  advance_queue_epoch,
  input  logic [ID_WIDTH-1:0]  advance_slot_id,
  input  logic [ID_WIDTH-1:0]  advance_command_id,
  input  logic [ID_WIDTH-1:0]  advance_effect_id,
  input  logic [ID_WIDTH-1:0]  advance_next_attempt,

  output logic                 provision_accept,
  output logic                 provision_rejected,
  output logic                 advance_accept,
  output logic                 advance_rejected,
  output logic                 frontier_exhausted,

  output logic                 persistent_valid,
  output logic [TAG_WIDTH-1:0] persistent_tag,
  output logic [ID_WIDTH-1:0]  persistent_incarnation,
  output logic [ID_WIDTH-1:0]  persistent_queue_epoch,
  output logic [ID_WIDTH-1:0]  persistent_slot_id,
  output logic [ID_WIDTH-1:0]  persistent_command_id,
  output logic [ID_WIDTH-1:0]  persistent_effect_id,
  output logic [ID_WIDTH-1:0]  persistent_next_attempt
);

  logic advance_lineage_matches;

  always_comb begin
    advance_lineage_matches =
      advance_tag == persistent_tag &&
      advance_incarnation == persistent_incarnation &&
      advance_queue_epoch == persistent_queue_epoch &&
      advance_slot_id == persistent_slot_id &&
      advance_command_id == persistent_command_id &&
      advance_effect_id == persistent_effect_id;

    frontier_exhausted = persistent_valid && (&persistent_next_attempt);

    provision_accept =
      cold_rst_n && provision_valid && !persistent_valid && !advance_valid;
    provision_rejected = provision_valid && !provision_accept;

    advance_accept =
      cold_rst_n && advance_valid && persistent_valid &&
      advance_lineage_matches && !frontier_exhausted &&
      advance_next_attempt == (persistent_next_attempt + {{(ID_WIDTH-1){1'b0}}, 1'b1}) &&
      !provision_valid;
    advance_rejected = advance_valid && !advance_accept;
  end

  always_ff @(posedge clk) begin
    if (!cold_rst_n) begin
      persistent_valid <= 1'b0;
      persistent_tag <= '0;
      persistent_incarnation <= '0;
      persistent_queue_epoch <= '0;
      persistent_slot_id <= '0;
      persistent_command_id <= '0;
      persistent_effect_id <= '0;
      persistent_next_attempt <= '0;
    end else if (provision_accept) begin
      persistent_valid <= 1'b1;
      persistent_tag <= provision_tag;
      persistent_incarnation <= provision_incarnation;
      persistent_queue_epoch <= provision_queue_epoch;
      persistent_slot_id <= provision_slot_id;
      persistent_command_id <= provision_command_id;
      persistent_effect_id <= provision_effect_id;
      persistent_next_attempt <= provision_next_attempt;
    end else if (advance_accept) begin
      persistent_next_attempt <= advance_next_attempt;
    end
  end

endmodule
