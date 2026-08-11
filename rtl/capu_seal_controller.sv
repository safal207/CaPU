module capu_seal_controller (
    input  logic clk,
    input  logic rst_n,

    // A committed STORE closes the current causal chain when its CTAG has
    // SEAL=1. This is continuation-control state, not cryptographic evidence.
    input  logic committed_event,
    input  logic committed_seal,

    // An explicitly admitted new cause/root starts a fresh chain after seal.
    input  logic explicit_new_cause_admitted,

    output logic sealed_chain,
    output logic automatic_continuation_allowed
);
    assign automatic_continuation_allowed = !sealed_chain;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sealed_chain <= 1'b0;
        end else if (committed_event && committed_seal) begin
            sealed_chain <= 1'b1;
        end else if (explicit_new_cause_admitted) begin
            sealed_chain <= 1'b0;
        end
    end
endmodule
