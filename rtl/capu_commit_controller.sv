module capu_commit_controller #(
    parameter int WIDTH = 32
) (
    input  logic             clk,
    input  logic             rst_n,

    input  logic             candidate_valid,
    input  logic             gate_allow,
    input  logic             execute_ok,
    input  logic             causal_valid,
    input  logic             commit_request,
    input  logic [WIDTH-1:0] result_value,

    output logic [WIDTH-1:0] architectural_state,
    output logic             architectural_write_enable,
    output logic             rejected
);

    logic commit_allowed;

    assign commit_allowed = candidate_valid
                         && gate_allow
                         && execute_ok
                         && causal_valid
                         && commit_request;

    // There is exactly one architectural write path in v0.
    assign architectural_write_enable = commit_allowed;

    // A present candidate that cannot reach commit is observable as rejected.
    // This is diagnostic only; it does not itself mutate architectural state.
    assign rejected = candidate_valid && !commit_allowed;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            architectural_state <= '0;
        end else if (commit_allowed) begin
            architectural_state <= result_value;
        end
    end

`ifdef CAPU_ASSERTIONS
    // INV-CAPU-CORE-002: gate dominates commit.
    property p_gate_dominates_commit;
        @(posedge clk) disable iff (!rst_n)
            candidate_valid && !gate_allow |-> !architectural_write_enable;
    endproperty
    assert property (p_gate_dominates_commit);

    // INV-CAPU-CORE-003: causal validation dominates commit.
    property p_validation_dominates_commit;
        @(posedge clk) disable iff (!rst_n)
            candidate_valid && !causal_valid |-> !architectural_write_enable;
    endproperty
    assert property (p_validation_dominates_commit);

    // INV-CAPU-CORE-004: failed speculative execution is contained.
    property p_execute_failure_contained;
        @(posedge clk) disable iff (!rst_n)
            candidate_valid && !execute_ok |-> !architectural_write_enable;
    endproperty
    assert property (p_execute_failure_contained);
`endif

endmodule
