module capu_seal_controller #(
    parameter bit ENABLE_RESTORE = 1'b0
) (
    input  logic clk,
    input  logic rst_n,

    input  logic committed_event,
    input  logic committed_seal,
    input  logic committed_explicit_new_cause,

    // v0.15 optional recovery path. Older instances keep ENABLE_RESTORE=0.
    input  logic restore_valid,
    input  logic restore_sealed_chain,

    output logic sealed_chain,
    output logic automatic_continuation_allowed
);
    logic restore_active;

    assign restore_active = ENABLE_RESTORE && (restore_valid === 1'b1);
    assign automatic_continuation_allowed = !sealed_chain;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sealed_chain <= 1'b0;
        end else if (restore_active) begin
            // Accepted recovery re-establishes the exact committed chain state.
            sealed_chain <= restore_sealed_chain;
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
