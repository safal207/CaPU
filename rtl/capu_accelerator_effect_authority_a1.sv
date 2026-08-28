module capu_accelerator_effect_authority_a1 #(
  parameter integer TAG_WIDTH = 8
)(
  input  logic                 clk,
  input  logic                 rst_n,
  input  logic                 recovery_begin,
  input  logic                 restore_valid,

  input  logic                 request_valid,
  input  logic [TAG_WIDTH-1:0] request_tag,

  input  logic                 checkpoint_capture_valid,

  input  logic                 issue_valid,
  input  logic [TAG_WIDTH-1:0] issue_tag,

  input  logic                 evidence_valid,
  input  logic [TAG_WIDTH-1:0] evidence_tag,
  input  logic [1:0]           evidence_completion_state,

  input  logic                 retire_valid,
  input  logic [TAG_WIDTH-1:0] retire_tag,

  output logic                 runtime_ready,
  output logic                 request_accept,
  output logic                 request_rejected,
  output logic                 checkpoint_capture_accept,
  output logic                 issue_accept,
  output logic                 issue_rejected,
  output logic                 evidence_accept,
  output logic                 evidence_rejected,
  output logic                 restore_accept,
  output logic                 restore_rejected,
  output logic                 retire_accept,
  output logic                 retire_rejected,

  output logic                 request_active,
  output logic [TAG_WIDTH-1:0] current_request_tag,
  output logic                 execution_started,
  output logic [1:0]           completion_state,

  output logic                 issue_authority,
  output logic                 evidence_required,
  output logic                 successor_attempt_authority,
  output logic                 retire_authority,
  output logic                 proof_receipt_valid,
  output logic                 speculation_kill,

  output logic                 checkpoint_valid,
  output logic                 durable_request_valid_o,
  output logic [TAG_WIDTH-1:0] durable_request_tag_o,
  output logic                 durable_issue_witness_o,
  output logic                 durable_negative_receipt_o,
  output logic                 durable_completion_receipt_o,
  output logic                 durable_retired_o
);

  localparam logic [1:0] NOT_COMMITTED = 2'b00;
  localparam logic [1:0] UNKNOWN       = 2'b01;
  localparam logic [1:0] COMMITTED     = 2'b10;

  logic                 durable_request_valid;
  logic [TAG_WIDTH-1:0] durable_request_tag;
  logic                 durable_issue_witness;
  logic                 durable_negative_receipt;
  logic                 durable_completion_receipt;
  logic                 durable_retired;

  logic                 checkpoint_request_active;
  logic [TAG_WIDTH-1:0] checkpoint_request_tag;
  logic                 checkpoint_execution_started;
  logic [1:0]           checkpoint_completion_state;

  always_comb begin
    issue_authority = runtime_ready && request_active && !execution_started &&
      completion_state == NOT_COMMITTED && !durable_issue_witness &&
      !durable_negative_receipt && !durable_completion_receipt && !durable_retired;

    evidence_required = runtime_ready && request_active &&
      completion_state == UNKNOWN && durable_issue_witness && !durable_retired;

    successor_attempt_authority = runtime_ready && request_active &&
      completion_state == NOT_COMMITTED && durable_negative_receipt &&
      !durable_issue_witness && !durable_completion_receipt && !durable_retired;

    retire_authority = runtime_ready && request_active &&
      completion_state == COMMITTED && durable_completion_receipt && !durable_retired;

    proof_receipt_valid = durable_completion_receipt;

    request_accept = request_valid && runtime_ready && !recovery_begin && !restore_valid &&
      !request_active && !durable_request_valid;
    request_rejected = request_valid && !request_accept;

    checkpoint_capture_accept = checkpoint_capture_valid && runtime_ready && request_active &&
      !recovery_begin && !restore_valid;

    issue_accept = issue_valid && runtime_ready && !recovery_begin && !restore_valid &&
      issue_authority && issue_tag == current_request_tag;
    issue_rejected = issue_valid && !issue_accept;

    evidence_accept = evidence_valid && runtime_ready && !recovery_begin && !restore_valid &&
      evidence_required && evidence_tag == current_request_tag &&
      (evidence_completion_state == NOT_COMMITTED ||
       evidence_completion_state == COMMITTED);
    evidence_rejected = evidence_valid && !evidence_accept;

    restore_accept = restore_valid && !recovery_begin && !runtime_ready &&
      checkpoint_valid && durable_request_valid;
    restore_rejected = restore_valid && !restore_accept;

    retire_accept = retire_valid && runtime_ready && !recovery_begin && !restore_valid &&
      retire_authority && retire_tag == current_request_tag;
    retire_rejected = retire_valid && !retire_accept;

    speculation_kill = recovery_begin || restore_valid;

    durable_request_valid_o = durable_request_valid;
    durable_request_tag_o = durable_request_tag;
    durable_issue_witness_o = durable_issue_witness;
    durable_negative_receipt_o = durable_negative_receipt;
    durable_completion_receipt_o = durable_completion_receipt;
    durable_retired_o = durable_retired;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      runtime_ready <= 1'b1;
      request_active <= 1'b0;
      current_request_tag <= '0;
      execution_started <= 1'b0;
      completion_state <= NOT_COMMITTED;

      durable_request_valid <= 1'b0;
      durable_request_tag <= '0;
      durable_issue_witness <= 1'b0;
      durable_negative_receipt <= 1'b0;
      durable_completion_receipt <= 1'b0;
      durable_retired <= 1'b0;

      checkpoint_valid <= 1'b0;
      checkpoint_request_active <= 1'b0;
      checkpoint_request_tag <= '0;
      checkpoint_execution_started <= 1'b0;
      checkpoint_completion_state <= NOT_COMMITTED;
    end else if (recovery_begin) begin
      runtime_ready <= 1'b0;
      request_active <= 1'b0;
      current_request_tag <= '0;
      execution_started <= 1'b0;
      completion_state <= NOT_COMMITTED;
    end else if (restore_accept) begin
      runtime_ready <= 1'b1;
      request_active <= !durable_retired;
      current_request_tag <= durable_request_tag;

      if (durable_completion_receipt) begin
        execution_started <= 1'b0;
        completion_state <= COMMITTED;
      end else if (durable_issue_witness) begin
        execution_started <= 1'b1;
        completion_state <= UNKNOWN;
      end else if (durable_negative_receipt) begin
        execution_started <= 1'b0;
        completion_state <= NOT_COMMITTED;
      end else begin
        execution_started <= checkpoint_execution_started;
        completion_state <= checkpoint_completion_state;
      end
    end else begin
      if (request_accept) begin
        request_active <= 1'b1;
        current_request_tag <= request_tag;
        execution_started <= 1'b0;
        completion_state <= NOT_COMMITTED;

        durable_request_valid <= 1'b1;
        durable_request_tag <= request_tag;
        durable_issue_witness <= 1'b0;
        durable_negative_receipt <= 1'b0;
        durable_completion_receipt <= 1'b0;
        durable_retired <= 1'b0;
      end

      if (checkpoint_capture_accept) begin
        checkpoint_valid <= 1'b1;
        checkpoint_request_active <= request_active;
        checkpoint_request_tag <= current_request_tag;
        checkpoint_execution_started <= execution_started;
        checkpoint_completion_state <= completion_state;
      end

      if (issue_accept) begin
        execution_started <= 1'b1;
        completion_state <= UNKNOWN;
        durable_issue_witness <= 1'b1;
        durable_negative_receipt <= 1'b0;
      end

      if (evidence_accept) begin
        durable_issue_witness <= 1'b0;
        execution_started <= 1'b0;
        if (evidence_completion_state == COMMITTED) begin
          completion_state <= COMMITTED;
          durable_completion_receipt <= 1'b1;
          durable_negative_receipt <= 1'b0;
        end else begin
          completion_state <= NOT_COMMITTED;
          durable_negative_receipt <= 1'b1;
          durable_completion_receipt <= 1'b0;
        end
      end

      if (retire_accept) begin
        request_active <= 1'b0;
        durable_retired <= 1'b1;
      end
    end
  end
endmodule
