module capu_causal_head_controller #(
    parameter int TRANSITION_ID_WIDTH = 64
) (
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic                           committed_event,
    input  logic [TRANSITION_ID_WIDTH-1:0] committed_transition_id,
    input  logic [3:0]                     committed_gen,
    output logic                           head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] causal_head_transition_id,
    output logic [3:0]                     causal_head_gen
);
    // v0.6 keeps the last committed causal transition identity together with
    // its local 4-bit CTAG generation. Speculation and flush never mutate this
    // state; only successful retirement does.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head_valid                <= 1'b0;
            causal_head_transition_id <= '0;
            causal_head_gen           <= 4'h0;
        end else if (committed_event) begin
            head_valid                <= 1'b1;
            causal_head_transition_id <= committed_transition_id;
            causal_head_gen           <= committed_gen;
        end
    end
endmodule
