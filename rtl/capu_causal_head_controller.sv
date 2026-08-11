module capu_causal_head_controller #(
    parameter int TRANSITION_ID_WIDTH = 64
) (
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic                           committed_event,
    input  logic [TRANSITION_ID_WIDTH-1:0] committed_transition_id,
    output logic                           head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] causal_head_transition_id
);
    // v0.5 keeps only the last committed causal transition identity.
    // Speculative admission and flush never mutate this state; only commit does.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head_valid                <= 1'b0;
            causal_head_transition_id <= '0;
        end else if (committed_event) begin
            head_valid                <= 1'b1;
            causal_head_transition_id <= committed_transition_id;
        end
    end
endmodule
