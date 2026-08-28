module astra_capu_authority_gate_a4_formal;
  localparam ID_WIDTH = 2;
  localparam SPENT_DEPTH = 2;

  (* gclk *) logic clk;
  (* anyseq *) logic rst_n;
  (* anyseq *) logic recovery_begin;

  (* anyseq *) logic authority_load_valid;
  (* anyseq *) logic authority_committed;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_queue_incarnation;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_queue_epoch;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_slot_id;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_command_id;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_attempt_id;
  (* anyseq *) logic [ID_WIDTH-1:0] authority_effect_id;

  (* anyseq *) logic command_valid;
  (* anyseq *) logic [ID_WIDTH-1:0] command_queue_incarnation;
  (* anyseq *) logic [ID_WIDTH-1:0] command_queue_epoch;
  (* anyseq *) logic [ID_WIDTH-1:0] command_slot_id;
  (* anyseq *) logic [ID_WIDTH-1:0] command_command_id;
  (* anyseq *) logic [ID_WIDTH-1:0] command_attempt_id;
  (* anyseq *) logic [ID_WIDTH-1:0] command_effect_id;

  logic authority_load_accept;
  logic authority_load_rejected;
  logic command_permit;
  logic command_rejected;
  logic downstream_command_valid;
  logic token_valid_o;
  logic token_committed_o;
  logic token_spent_o;
  logic [ID_WIDTH-1:0] token_queue_incarnation_o;
  logic [ID_WIDTH-1:0] token_queue_epoch_o;
  logic [ID_WIDTH-1:0] token_slot_id_o;
  logic [ID_WIDTH-1:0] token_command_id_o;
  logic [ID_WIDTH-1:0] token_attempt_id_o;
  logic [ID_WIDTH-1:0] token_effect_id_o;
  logic [SPENT_DEPTH-1:0] spent_valid_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_queue_incarnations_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_queue_epochs_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_slot_ids_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_command_ids_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_attempt_ids_o;
  logic [SPENT_DEPTH*ID_WIDTH-1:0] spent_effect_ids_o;

  integer i;
  logic command_matches_token;
  logic authority_matches_spent;
  logic command_matches_spent;
  logic f_past_valid = 1'b0;

  astra_capu_authority_gate_a4 #(
    .ID_WIDTH(ID_WIDTH),
    .SPENT_DEPTH(SPENT_DEPTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .recovery_begin(recovery_begin),
    .authority_load_valid(authority_load_valid),
    .authority_committed(authority_committed),
    .authority_queue_incarnation(authority_queue_incarnation),
    .authority_queue_epoch(authority_queue_epoch),
    .authority_slot_id(authority_slot_id),
    .authority_command_id(authority_command_id),
    .authority_attempt_id(authority_attempt_id),
    .authority_effect_id(authority_effect_id),
    .command_valid(command_valid),
    .command_queue_incarnation(command_queue_incarnation),
    .command_queue_epoch(command_queue_epoch),
    .command_slot_id(command_slot_id),
    .command_command_id(command_command_id),
    .command_attempt_id(command_attempt_id),
    .command_effect_id(command_effect_id),
    .authority_load_accept(authority_load_accept),
    .authority_load_rejected(authority_load_rejected),
    .command_permit(command_permit),
    .command_rejected(command_rejected),
    .downstream_command_valid(downstream_command_valid),
    .token_valid_o(token_valid_o),
    .token_committed_o(token_committed_o),
    .token_spent_o(token_spent_o),
    .token_queue_incarnation_o(token_queue_incarnation_o),
    .token_queue_epoch_o(token_queue_epoch_o),
    .token_slot_id_o(token_slot_id_o),
    .token_command_id_o(token_command_id_o),
    .token_attempt_id_o(token_attempt_id_o),
    .token_effect_id_o(token_effect_id_o),
    .spent_valid_o(spent_valid_o),
    .spent_queue_incarnations_o(spent_queue_incarnations_o),
    .spent_queue_epochs_o(spent_queue_epochs_o),
    .spent_slot_ids_o(spent_slot_ids_o),
    .spent_command_ids_o(spent_command_ids_o),
    .spent_attempt_ids_o(spent_attempt_ids_o),
    .spent_effect_ids_o(spent_effect_ids_o)
  );

  always_comb begin
    command_matches_token =
      command_queue_incarnation == token_queue_incarnation_o &&
      command_queue_epoch == token_queue_epoch_o &&
      command_slot_id == token_slot_id_o &&
      command_command_id == token_command_id_o &&
      command_attempt_id == token_attempt_id_o &&
      command_effect_id == token_effect_id_o;

    authority_matches_spent = 1'b0;
    command_matches_spent = 1'b0;
    for (i = 0; i < SPENT_DEPTH; i = i + 1) begin
      if (spent_valid_o[i] &&
          authority_queue_incarnation == spent_queue_incarnations_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_queue_epoch == spent_queue_epochs_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_slot_id == spent_slot_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_command_id == spent_command_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_attempt_id == spent_attempt_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          authority_effect_id == spent_effect_ids_o[i*ID_WIDTH +: ID_WIDTH])
        authority_matches_spent = 1'b1;

      if (spent_valid_o[i] &&
          command_queue_incarnation == spent_queue_incarnations_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_queue_epoch == spent_queue_epochs_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_slot_id == spent_slot_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_command_id == spent_command_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_attempt_id == spent_attempt_ids_o[i*ID_WIDTH +: ID_WIDTH] &&
          command_effect_id == spent_effect_ids_o[i*ID_WIDTH +: ID_WIDTH])
        command_matches_spent = 1'b1;
    end
  end

  always_ff @(posedge clk) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid)
      assume(!rst_n);
    else
      assume(rst_n);

    if (rst_n) begin
      assert(downstream_command_valid == command_permit);
      assert(command_rejected == (command_valid && !command_permit));
      assert(authority_load_rejected == (authority_load_valid && !authority_load_accept));
      assert(!(command_permit && command_rejected));
      assert(!(authority_load_accept && authority_load_rejected));

      if (command_permit) begin
        assert(command_valid);
        assert(!recovery_begin);
        assert(token_valid_o);
        assert(token_committed_o);
        assert(!token_spent_o);
        assert(command_matches_token);
        assert(!command_matches_spent);
      end

      if (recovery_begin)
        assert(!command_permit && !authority_load_accept);

      if (!token_valid_o || !token_committed_o || token_spent_o ||
          !command_matches_token || command_matches_spent)
        assert(!command_permit);

      if (command_valid && command_matches_spent)
        assert(command_rejected);

      if (authority_load_accept) begin
        assert(authority_load_valid);
        assert(!recovery_begin);
        assert(!authority_matches_spent);
      end

      if (authority_load_valid && (recovery_begin || authority_matches_spent))
        assert(authority_load_rejected);

      if (token_spent_o)
        assert(token_valid_o);
    end

    if (f_past_valid && $past(rst_n)) begin
      if ($past(command_permit)) begin
        assert(token_spent_o);
        assert(spent_valid_o[0]);
        assert(spent_queue_incarnations_o[0 +: ID_WIDTH] == $past(command_queue_incarnation));
        assert(spent_queue_epochs_o[0 +: ID_WIDTH] == $past(command_queue_epoch));
        assert(spent_slot_ids_o[0 +: ID_WIDTH] == $past(command_slot_id));
        assert(spent_command_ids_o[0 +: ID_WIDTH] == $past(command_command_id));
        assert(spent_attempt_ids_o[0 +: ID_WIDTH] == $past(command_attempt_id));
        assert(spent_effect_ids_o[0 +: ID_WIDTH] == $past(command_effect_id));
      end

      if ($past(authority_load_accept) && !$past(command_permit)) begin
        assert(token_valid_o);
        assert(token_committed_o == $past(authority_committed));
        assert(!token_spent_o);
        assert(token_queue_incarnation_o == $past(authority_queue_incarnation));
        assert(token_queue_epoch_o == $past(authority_queue_epoch));
        assert(token_slot_id_o == $past(authority_slot_id));
        assert(token_command_id_o == $past(authority_command_id));
        assert(token_attempt_id_o == $past(authority_attempt_id));
        assert(token_effect_id_o == $past(authority_effect_id));
      end

      if ($past(recovery_begin)) begin
        assert(token_valid_o == $past(token_valid_o));
        assert(token_committed_o == $past(token_committed_o));
        assert(token_spent_o == $past(token_spent_o));
        assert(token_queue_incarnation_o == $past(token_queue_incarnation_o));
        assert(token_queue_epoch_o == $past(token_queue_epoch_o));
        assert(token_slot_id_o == $past(token_slot_id_o));
        assert(token_command_id_o == $past(token_command_id_o));
        assert(token_attempt_id_o == $past(token_attempt_id_o));
        assert(token_effect_id_o == $past(token_effect_id_o));
        assert(spent_valid_o == $past(spent_valid_o));
        assert(spent_queue_incarnations_o == $past(spent_queue_incarnations_o));
        assert(spent_queue_epochs_o == $past(spent_queue_epochs_o));
        assert(spent_slot_ids_o == $past(spent_slot_ids_o));
        assert(spent_command_ids_o == $past(spent_command_ids_o));
        assert(spent_attempt_ids_o == $past(spent_attempt_ids_o));
        assert(spent_effect_ids_o == $past(spent_effect_ids_o));
      end
    end

    cover(authority_load_accept && authority_committed);
    cover(command_permit);
    cover(command_valid && !token_valid_o && command_rejected);
    cover(command_valid && token_valid_o && !token_committed_o && command_rejected);
    cover(command_valid && token_valid_o && !command_matches_token && command_rejected);
    cover(recovery_begin && command_valid && command_rejected);
    cover(authority_load_valid && authority_matches_spent && authority_load_rejected);
    cover(spent_valid_o == {SPENT_DEPTH{1'b1}});
  end
endmodule
