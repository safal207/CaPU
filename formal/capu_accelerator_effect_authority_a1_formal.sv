module capu_accelerator_effect_authority_a1_formal;
  localparam integer TAG_WIDTH = 3;
  localparam logic [1:0] NOT_COMMITTED = 2'b00;
  localparam logic [1:0] UNKNOWN = 2'b01;
  localparam logic [1:0] COMMITTED = 2'b10;

  (* gclk *) logic clk;
  (* anyseq *) logic rst_n;
  (* anyseq *) logic recovery_begin, restore_valid;
  (* anyseq *) logic request_valid; (* anyseq *) logic [TAG_WIDTH-1:0] request_tag;
  (* anyseq *) logic checkpoint_capture_valid;
  (* anyseq *) logic issue_valid; (* anyseq *) logic [TAG_WIDTH-1:0] issue_tag;
  (* anyseq *) logic evidence_valid; (* anyseq *) logic [TAG_WIDTH-1:0] evidence_tag;
  (* anyseq *) logic [1:0] evidence_completion_state;
  (* anyseq *) logic retire_valid; (* anyseq *) logic [TAG_WIDTH-1:0] retire_tag;

  logic runtime_ready, request_accept, request_rejected;
  logic checkpoint_capture_accept, issue_accept, issue_rejected;
  logic evidence_accept, evidence_rejected, restore_accept, restore_rejected;
  logic retire_accept, retire_rejected, request_active;
  logic [TAG_WIDTH-1:0] current_request_tag;
  logic execution_started; logic [1:0] completion_state;
  logic issue_authority, evidence_required, successor_attempt_authority;
  logic retire_authority, proof_receipt_valid, speculation_kill;
  logic checkpoint_valid, durable_request_valid_o;
  logic [TAG_WIDTH-1:0] durable_request_tag_o;
  logic durable_issue_witness_o, durable_negative_receipt_o;
  logic durable_completion_receipt_o, durable_retired_o;

  capu_accelerator_effect_authority_a1 #(.TAG_WIDTH(TAG_WIDTH)) dut (.*);

  logic f_past_valid;
  initial f_past_valid = 1'b0;

  always @(posedge clk) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid)
      assume(!rst_n);
    else
      assume(rst_n);

    assume(evidence_completion_state == NOT_COMMITTED ||
           evidence_completion_state == UNKNOWN ||
           evidence_completion_state == COMMITTED);
    assume($onehot0({recovery_begin, restore_valid, request_valid,
                     checkpoint_capture_valid, issue_valid, evidence_valid,
                     retire_valid}));

    if (rst_n) begin
      assert(!(durable_issue_witness_o && durable_negative_receipt_o));
      assert(!(durable_issue_witness_o && durable_completion_receipt_o));
      assert(!(durable_negative_receipt_o && durable_completion_receipt_o));

      if (request_active) begin
        assert(durable_request_valid_o);
        assert(current_request_tag == durable_request_tag_o);
        assert(!durable_retired_o);
      end

      if (completion_state == UNKNOWN && runtime_ready && request_active) begin
        assert(evidence_required);
        assert(durable_issue_witness_o);
        assert(!issue_authority);
        assert(!successor_attempt_authority);
        assert(!retire_authority);
      end

      if (completion_state == COMMITTED) begin
        assert(durable_completion_receipt_o);
        assert(proof_receipt_valid);
        assert(!issue_authority);
        assert(!successor_attempt_authority);
      end

      if (successor_attempt_authority) begin
        assert(completion_state == NOT_COMMITTED);
        assert(durable_negative_receipt_o);
        assert(!durable_issue_witness_o);
        assert(!durable_completion_receipt_o);
        assert(!issue_authority);
        assert(!retire_authority);
      end

      if (retire_authority) begin
        assert(completion_state == COMMITTED);
        assert(durable_completion_receipt_o);
        assert(proof_receipt_valid);
      end

      if (issue_accept) begin
        assert(issue_tag == current_request_tag);
        assert(issue_authority);
      end

      if (evidence_accept) begin
        assert(evidence_tag == current_request_tag);
        assert(evidence_required);
        assert(evidence_completion_state != UNKNOWN);
      end

      if (retire_accept) begin
        assert(retire_tag == current_request_tag);
        assert(retire_authority);
      end

      if (evidence_valid && evidence_required && evidence_tag != current_request_tag)
        assert(evidence_rejected);

      if (retire_valid && completion_state == UNKNOWN)
        assert(retire_rejected);
    end

    if (f_past_valid && $past(rst_n)) begin
      if ($past(recovery_begin)) begin
        assert(!runtime_ready);
        assert(!request_active);
      end

      if ($past(restore_accept && durable_issue_witness_o)) begin
        assert(runtime_ready);
        assert(request_active);
        assert(completion_state == UNKNOWN);
        assert(evidence_required);
      end

      if ($past(evidence_accept && evidence_completion_state == COMMITTED)) begin
        assert(completion_state == COMMITTED);
        assert(proof_receipt_valid);
        assert(retire_authority);
      end

      if ($past(evidence_accept && evidence_completion_state == NOT_COMMITTED)) begin
        assert(completion_state == NOT_COMMITTED);
        assert(successor_attempt_authority);
        assert(!issue_authority);
      end

      if ($past(retire_accept)) begin
        assert(durable_retired_o);
        assert(!request_active);
      end

      if ($past(evidence_valid && evidence_rejected && !recovery_begin && !restore_valid)) begin
        assert($stable(current_request_tag));
        assert($stable(completion_state));
        assert($stable(durable_issue_witness_o));
        assert($stable(durable_negative_receipt_o));
        assert($stable(durable_completion_receipt_o));
      end
    end

    cover(request_accept);
    cover(issue_accept && completion_state == NOT_COMMITTED);
    cover(restore_accept && durable_issue_witness_o);
    cover(evidence_valid && evidence_rejected && evidence_tag != current_request_tag);
    cover(evidence_accept && evidence_completion_state == NOT_COMMITTED);
    cover(evidence_accept && evidence_completion_state == COMMITTED);
    cover(retire_accept);
  end
endmodule
