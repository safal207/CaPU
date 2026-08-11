module capu_seal_controller (
    input  logic clk,
    input  logic rst_n,

    input  logic committed_event,
    input  logic committed_seal,
    input  logic committed_explicit_new_cause,

    output logic sealed_chain,
    output logic automatic_continuation_allowed
);
    assign automatic_continuation_allowed = !sealed_chain;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sealed_chain <= 1'b0;
        end else if (committed_event) begin
            // A committed explicit new cause/root starts a fresh chain. Its own
            // SEAL bit decides whether the fresh chain is immediately closed.
            if (committed_explicit_new_cause)
                sealed_chain <= committed_seal;
            // Normal continuation may close an open chain but can never clear
            // an already sealed chain.
            else if (committed_seal)
                sealed_chain <= 1'b1;
        end
    end
endmodule
