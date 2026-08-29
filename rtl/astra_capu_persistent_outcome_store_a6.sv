module astra_capu_persistent_outcome_store_a6 #(
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

  input  logic                 reserve_valid,
  input  logic [TAG_WIDTH-1:0] reserve_tag,
  input  logic [ID_WIDTH-1:0]  reserve_incarnation,
  input  logic [ID_WIDTH-1:0]  reserve_queue_epoch,
  input  logic [ID_WIDTH-1:0]  reserve_slot_id,
  input  logic [ID_WIDTH-1:0]  reserve_command_id,
  input  logic [ID_WIDTH-1:0]  reserve_attempt_id,
  input  logic [ID_WIDTH-1:0]  reserve_effect_id,

  input  logic                 reconcile_valid,
  input  logic [TAG_WIDTH-1:0] reconcile_tag,
  input  logic [ID_WIDTH-1:0]  reconcile_incarnation,
  input  logic [ID_WIDTH-1:0]  reconcile_queue_epoch,
  input  logic [ID_WIDTH-1:0]  reconcile_slot_id,
  input  logic [ID_WIDTH-1:0]  reconcile_command_id,
  input  logic [ID_WIDTH-1:0]  reconcile_attempt_id,
  input  logic [ID_WIDTH-1:0]  reconcile_effect_id,
  input  logic [2:0]           reconcile_outcome,

  output logic                 provision_accept,
  output logic                 provision_rejected,
  output logic                 reserve_accept,
  output logic                 reserve_rejected,
  output logic                 reconcile_accept,
  output logic                 reconcile_rejected,
  output logic [2:0]           reconcile_reject_code,
  output logic                 frontier_exhausted,

  output logic                 persistent_valid,
  output logic [TAG_WIDTH-1:0] persistent_tag,
  output logic [ID_WIDTH-1:0]  persistent_incarnation,
  output logic [ID_WIDTH-1:0]  persistent_queue_epoch,
  output logic [ID_WIDTH-1:0]  persistent_slot_id,
  output logic [ID_WIDTH-1:0]  persistent_command_id,
  output logic [ID_WIDTH-1:0]  persistent_effect_id,
  output logic [ID_WIDTH-1:0]  persistent_next_attempt,
  output logic                 unresolved_valid,
  output logic [ID_WIDTH-1:0]  unresolved_attempt,
  output logic [2:0]           last_outcome,
  output logic [ID_WIDTH-1:0]  last_resolved_attempt,
  output logic                 terminal_committed,
  output logic                 terminal_conflict
);

  localparam logic [2:0] OUTCOME_NONE          = 3'd0;
  localparam logic [2:0] OUTCOME_UNKNOWN       = 3'd1;
  localparam logic [2:0] OUTCOME_NOT_COMMITTED = 3'd2;
  localparam logic [2:0] OUTCOME_COMMITTED     = 3'd3;
  localparam logic [2:0] OUTCOME_CONFLICT      = 3'd4;

  localparam logic [2:0] RECONCILE_NONE          = 3'd0;
  localparam logic [2:0] RECONCILE_NO_STORE      = 3'd1;
  localparam logic [2:0] RECONCILE_LINEAGE       = 3'd2;
  localparam logic [2:0] RECONCILE_NO_UNRESOLVED = 3'd3;
  localparam logic [2:0] RECONCILE_ATTEMPT       = 3'd4;
  localparam logic [2:0] RECONCILE_OUTCOME       = 3'd5;
  localparam logic [2:0] RECONCILE_TERMINAL      = 3'd6;

  logic reserve_lineage_matches;
  logic reconcile_lineage_matches;
  logic reconcile_outcome_valid;

  always_comb begin
    reserve_lineage_matches =
      reserve_tag == persistent_tag &&
      reserve_incarnation == persistent_incarnation &&
      reserve_queue_epoch == persistent_queue_epoch &&
      reserve_slot_id == persistent_slot_id &&
      reserve_command_id == persistent_command_id &&
      reserve_effect_id == persistent_effect_id;

    reconcile_lineage_matches =
      reconcile_tag == persistent_tag &&
      reconcile_incarnation == persistent_incarnation &&
      reconcile_queue_epoch == persistent_queue_epoch &&
      reconcile_slot_id == persistent_slot_id &&
      reconcile_command_id == persistent_command_id &&
      reconcile_effect_id == persistent_effect_id;

    reconcile_outcome_valid =
      reconcile_outcome == OUTCOME_NOT_COMMITTED ||
      reconcile_outcome == OUTCOME_COMMITTED ||
      reconcile_outcome == OUTCOME_CONFLICT;

    frontier_exhausted = persistent_valid && (&persistent_next_attempt);

    provision_accept =
      cold_rst_n && provision_valid && !persistent_valid &&
      !reserve_valid && !reconcile_valid;
    provision_rejected = provision_valid && !provision_accept;

    reserve_accept =
      cold_rst_n && reserve_valid && persistent_valid &&
      reserve_lineage_matches && !unresolved_valid &&
      !terminal_committed && !terminal_conflict &&
      !frontier_exhausted &&
      reserve_attempt_id == persistent_next_attempt &&
      !provision_valid && !reconcile_valid;
    reserve_rejected = reserve_valid && !reserve_accept;

    reconcile_accept =
      cold_rst_n && reconcile_valid && persistent_valid &&
      reconcile_lineage_matches && unresolved_valid &&
      reconcile_attempt_id == unresolved_attempt &&
      reconcile_outcome_valid &&
      !terminal_committed && !terminal_conflict &&
      !provision_valid && !reserve_valid;
    reconcile_rejected = reconcile_valid && !reconcile_accept;

    reconcile_reject_code = RECONCILE_NONE;
    if (reconcile_valid && !reconcile_accept) begin
      if (!persistent_valid)
        reconcile_reject_code = RECONCILE_NO_STORE;
      else if (!reconcile_lineage_matches)
        reconcile_reject_code = RECONCILE_LINEAGE;
      else if (terminal_committed || terminal_conflict)
        reconcile_reject_code = RECONCILE_TERMINAL;
      else if (!unresolved_valid)
        reconcile_reject_code = RECONCILE_NO_UNRESOLVED;
      else if (reconcile_attempt_id != unresolved_attempt)
        reconcile_reject_code = RECONCILE_ATTEMPT;
      else if (!reconcile_outcome_valid)
        reconcile_reject_code = RECONCILE_OUTCOME;
      else
        reconcile_reject_code = RECONCILE_OUTCOME;
    end
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
      unresolved_valid <= 1'b0;
      unresolved_attempt <= '0;
      last_outcome <= OUTCOME_NONE;
      last_resolved_attempt <= '0;
      terminal_committed <= 1'b0;
      terminal_conflict <= 1'b0;
    end else if (provision_accept) begin
      persistent_valid <= 1'b1;
      persistent_tag <= provision_tag;
      persistent_incarnation <= provision_incarnation;
      persistent_queue_epoch <= provision_queue_epoch;
      persistent_slot_id <= provision_slot_id;
      persistent_command_id <= provision_command_id;
      persistent_effect_id <= provision_effect_id;
      persistent_next_attempt <= provision_next_attempt;
      unresolved_valid <= 1'b0;
      unresolved_attempt <= '0;
      last_outcome <= OUTCOME_NONE;
      last_resolved_attempt <= '0;
      terminal_committed <= 1'b0;
      terminal_conflict <= 1'b0;
    end else if (reserve_accept) begin
      persistent_next_attempt <=
        reserve_attempt_id + {{(ID_WIDTH-1){1'b0}}, 1'b1};
      unresolved_valid <= 1'b1;
      unresolved_attempt <= reserve_attempt_id;
      last_outcome <= OUTCOME_UNKNOWN;
    end else if (reconcile_accept) begin
      unresolved_valid <= 1'b0;
      last_outcome <= reconcile_outcome;
      last_resolved_attempt <= reconcile_attempt_id;
      if (reconcile_outcome == OUTCOME_COMMITTED)
        terminal_committed <= 1'b1;
      else if (reconcile_outcome == OUTCOME_CONFLICT)
        terminal_conflict <= 1'b1;
    end
  end

endmodule
